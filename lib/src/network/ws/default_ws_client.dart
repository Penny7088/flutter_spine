import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../error/app_exception.dart';
import '../../logging/app_logger.dart';
import 'ws_client.dart';
import 'ws_connection_state.dart';

/// `WsClient` 默认实现。基于 `package:web_socket_channel` 提供：
/// * 状态机（idle → connecting → connected ⇄ reconnecting → disconnected/failed）
/// * 心跳保活
/// * 指数退避 + 抖动 自动重连
/// * token 过期自动刷新 + 重连（需配置 [WsClientConfig.onAuthExpired]）
/// * 正常关闭码（1000/1001）不触发重连
/// * topic 订阅 / 引用计数 / 重连后自动重订阅（需 [WsClientConfig.topicRouter]）
/// * 业务可注入 [WsChannelFactory] 来替换底层 channel（测试用 fake channel）
///
/// 详见 [WsClient] 接口文档。
class DefaultWsClient implements WsClient {
  DefaultWsClient(
    this._config, {
    AppLogger? logger,
    WsChannelFactory? channelFactory,
    Random? random,
  })  : _logger = logger,
        _channelFactory = channelFactory ?? _defaultFactory,
        _rand = random ?? Random();

  final WsClientConfig _config;
  final AppLogger? _logger;
  final WsChannelFactory _channelFactory;
  final Random _rand;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  int _reconnectAttempt = 0;
  bool _userClosed = false;
  bool _disposed = false;

  WsConnectionState _state = const WsIdle();
  final _stateController = StreamController<WsConnectionState>.broadcast();
  final _messageController = StreamController<dynamic>.broadcast();

  /// topic → 共享 broadcast controller + 引用计数
  final Map<String, _TopicEntry> _topics = {};

  /// 单飞 auth 刷新 future。多个并发 auth close 共用此 future。
  Future<String?>? _inflightAuthRefresh;

  // ── public ────────────────────────────────────────────────────────────────

  @override
  WsConnectionState get currentState => _state;

  @override
  Stream<WsConnectionState> get connectionState => _stateController.stream;

  @override
  Stream<dynamic> get messages => _messageController.stream;

  @override
  Future<void> connect() async {
    if (_disposed) {
      throw StateError('WsClient already disposed');
    }
    if (_state is WsConnecting || _state is WsConnected) return;
    _userClosed = false;
    _reconnectAttempt = 0;
    await _doConnect();
  }

  @override
  Future<void> disconnect({int? code, String? reason}) async {
    _userClosed = true;
    _cancelTimers();
    await _channelSub?.cancel();
    _channelSub = null;
    try {
      // sink.close 在某些 channel 实现下不会 resolve；fire-and-forget。
      unawaited(_channel?.sink.close(code, reason));
    } catch (_) {
      // 忽略关闭异常
    }
    _channel = null;
    _emitState(WsDisconnected(code: code, reason: reason));
  }

  @override
  void send(Object data) {
    if (_state is! WsConnected) {
      _logger?.warn('[ws] send called while state=$_state — dropped');
      return;
    }
    final encoded = _encode(data);
    try {
      _channel?.sink.add(encoded);
    } catch (e, st) {
      _logger?.warn('[ws] send failed: $e\n$st');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelTimers();
    await _channelSub?.cancel();
    _channelSub = null;
    // 注意：sink.close 的 Future 在某些 channel 实现下（例如 broadcast 流 / 仍有
    // pending event 时）不会 resolve。这里用 fire-and-forget——业务侧不应该依赖
    // dispose 完成意味着对端真的收到了 close 帧。
    try {
      unawaited(_channel?.sink.close());
    } catch (_) {}
    _channel = null;
    // 关闭所有 topic 子 controller
    for (final entry in _topics.values) {
      unawaited(entry.controller.close());
    }
    _topics.clear();
    // 同理：broadcast stream controller 在仍有活跃 listener 时 close() 的 Future
    // 不会 resolve。listener 由 ProviderScope dispose / 测试 tearDown 善后。
    unawaited(_stateController.close());
    unawaited(_messageController.close());
  }

  // ── topic subscription ───────────────────────────────────────────────────

  @override
  Stream<T> subscribe<T>(
    String topic, {
    T Function(dynamic raw)? decoder,
    bool autoConnect = true,
  }) {
    if (_disposed) {
      throw StateError('WsClient already disposed');
    }
    final router = _config.topicRouter;
    if (router == null) {
      throw StateError(
        'WsClient.subscribe requires WsClientConfig.topicRouter to be configured',
      );
    }

    var entry = _topics[topic];
    final isFirstRef = entry == null;
    if (isFirstRef) {
      entry = _TopicEntry();
      _topics[topic] = entry;
    }
    entry.refCount += 1;

    // 已连状态下首次订阅 → 立即发 subscribe 帧；
    // 未连 / 重连中 → 等 _doConnect 成功后由 _replaySubscriptions 统一发。
    if (isFirstRef && _state is WsConnected) {
      _sendSubscribeFrame(topic);
    }

    // 懒连接：用户表达了"要数据"的意图，触发 connect。
    // 仅在"非进行中"状态下触发，避免打断 connecting / reconnecting / connected。
    if (autoConnect &&
        (_state is WsIdle ||
            _state is WsDisconnected ||
            _state is WsFailed)) {
      unawaited(connect());
    }

    if (decoder == null) {
      return entry.controller.stream.cast<T>();
    }
    return entry.controller.stream.map<T>(decoder);
  }

  @override
  Future<void> unsubscribe(String topic) async {
    final entry = _topics[topic];
    if (entry == null) return;
    entry.refCount -= 1;
    if (entry.refCount > 0) return;
    _topics.remove(topic);
    if (_state is WsConnected) {
      _sendUnsubscribeFrame(topic);
    }
    unawaited(entry.controller.close());
  }

  @override
  bool isSubscribed(String topic) {
    final e = _topics[topic];
    return e != null && e.refCount > 0;
  }

  @override
  Set<String> get subscribedTopics =>
      _topics.entries.where((e) => e.value.refCount > 0).map((e) => e.key).toSet();

  // ── internal ──────────────────────────────────────────────────────────────

  Future<void> _doConnect() async {
    _emitState(const WsConnecting());

    try {
      final channel = _channelFactory(_config);
      // ready 在 WebSocketChannel 上是 Future——等握手完成；超时按 connectTimeout。
      await channel.ready.timeout(_config.connectTimeout);
      _channel = channel;

      _channelSub = channel.stream.listen(
        _onMessage,
        onError: _onChannelError,
        onDone: _onChannelDone,
        cancelOnError: false,
      );

      _reconnectAttempt = 0;
      _emitState(const WsConnected());
      _startHeartbeat();
      _replaySubscriptions();
      _logger?.info('[ws] connected ${_config.url}');
    } on TimeoutException catch (e, st) {
      _logger?.warn('[ws] connect timeout: $e');
      _scheduleReconnect(
        TimeoutAppException(
          message: 'WS connect timeout',
          raw: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      _logger?.warn('[ws] connect failed: $e');
      // 连接级 auth 错误检测——HTTP 401 / 403 拒绝 WebSocket 升级握手
      if (_config.isConnectAuthError != null &&
          _config.isConnectAuthError!(e) &&
          _config.onAuthExpired != null) {
        _logger?.info('[ws] connect auth error detected, refreshing...');
        final newToken = await _safeRefreshToken();
        if (newToken != null && newToken.isNotEmpty) {
          // 不重置 _reconnectAttempt——连接路径的 token 刷新可能仍失败，
          // 让 maxReconnectAttempts 正常累积，避免无限 auth-refresh 循环。
          _doScheduleReconnect(const NetworkException(
            message: 'Reconnecting after connect auth refresh',
          ));
          return;
        }
      }
      _scheduleReconnect(
        NetworkException(message: e.toString(), raw: e, stackTrace: st),
      );
    }
  }

  void _onMessage(dynamic msg) {
    _messageController.add(msg);
    if (_topics.isEmpty) return;
    final router = _config.topicRouter;
    if (router == null) return;
    String? topic;
    try {
      topic = router.topicExtractor(msg);
    } catch (e, st) {
      _logger?.warn('[ws] topicExtractor threw: $e\n$st — message dropped');
      return;
    }
    if (topic == null) return;
    final entry = _topics[topic];
    if (entry == null) return;
    if (!entry.controller.isClosed) {
      entry.controller.add(msg);
    }
  }

  void _onChannelError(Object error, StackTrace st) {
    _logger?.warn('[ws] channel error: $error');
    _scheduleReconnect(
      NetworkException(message: error.toString(), raw: error, stackTrace: st),
    );
  }

  void _onChannelDone() {
    if (_userClosed || _disposed) return;
    // 在清理前捕获 channel，用于读取 close code / reason
    final closedChannel = _channel;
    _stopHeartbeat();
    _channelSub?.cancel();
    _channelSub = null;
    _channel = null;
    unawaited(_handleRemoteClose(closedChannel));
  }

  Future<void> _handleRemoteClose(WebSocketChannel? closedChannel) async {
    final closeCode = closedChannel?.closeCode;
    final closeReason = closedChannel?.closeReason;

    _logger?.info('[ws] channel closed by remote, code=$closeCode');

    if (_userClosed || _disposed) return;

    // 正常关闭码（1000 normal, 1001 going away）——不重连
    if (closeCode == 1000 || closeCode == 1001) {
      _emitState(WsDisconnected(code: closeCode, reason: closeReason));
      return;
    }

    // auth 过期 close code → 刷新 token 后重连
    final isAuth = _config.isAuthCloseCode;
    if (isAuth != null &&
        isAuth(closeCode) &&
        _config.onAuthExpired != null) {
      await _doAuthRefreshAndReconnect();
      return;
    }

    // 其余情况：标准重连
    _doScheduleReconnect(
      const NetworkException(message: 'Connection closed by remote'),
    );
  }

  Future<void> _doAuthRefreshAndReconnect() async {
    _logger?.info('[ws] auth close code detected, refreshing token...');

    final newToken = await _safeRefreshToken();
    if (newToken == null) {
      _logger?.info('[ws] onAuthExpired returned null — entering WsFailed');
      _emitState(
        const WsFailed(
          NetworkException(
            message: 'Auth refresh returned null, re-login required',
          ),
        ),
      );
      return;
    }

    if (newToken.isEmpty) {
      _logger?.info('[ws] onAuthExpired returned empty — entering WsFailed');
      _emitState(
        const WsFailed(
          NetworkException(
            message: 'Auth refresh returned empty, re-login required',
          ),
        ),
      );
      return;
    }

    _logger?.info('[ws] token refreshed, reconnecting...');
    // 重置重连计数——token 问题不是网络问题
    _reconnectAttempt = 0;
    _doScheduleReconnect(
      const NetworkException(message: 'Reconnecting after auth refresh'),
    );
  }

  /// 安全的单飞 token 刷新——复用 [_inflightAuthRefresh]，
  /// 同时用于 close-code 路径和 connect 失败路径。
  Future<String?> _safeRefreshToken() async {
    try {
      return await (_inflightAuthRefresh ??= _config.onAuthExpired!()
          .whenComplete(() => _inflightAuthRefresh = null));
    } catch (e, st) {
      _logger?.warn('[ws] onAuthExpired threw: $e\n$st');
      return null;
    }
  }

  void _scheduleReconnect(AppException reason) {
    _stopHeartbeat();
    _channelSub?.cancel();
    _channelSub = null;
    _channel = null;
    _doScheduleReconnect(reason);
  }

  void _doScheduleReconnect(AppException reason) {
    if (_userClosed || _disposed) return;

    final maxAttempts = _config.maxReconnectAttempts;
    if (maxAttempts >= 0 && _reconnectAttempt >= maxAttempts) {
      _emitState(WsFailed(reason));
      return;
    }

    _reconnectAttempt += 1;
    final delay = _computeBackoff(_reconnectAttempt);
    _emitState(
      WsReconnecting(attempt: _reconnectAttempt, nextDelay: delay),
    );
    _reconnectTimer = Timer(delay, () {
      if (_userClosed || _disposed) return;
      _doConnect();
    });
  }

  Duration _computeBackoff(int attempt) {
    final base = _config.baseReconnectDelay.inMilliseconds;
    final cap = _config.maxReconnectDelay.inMilliseconds;
    // exp = base * 2^(attempt-1), 上限 cap
    final exp = min(base * pow(2, attempt - 1).toInt(), cap);
    final jitterRatio = _config.reconnectJitterRatio.clamp(0.0, 1.0);
    if (jitterRatio == 0) return Duration(milliseconds: exp);
    final jitter = (exp * jitterRatio * (_rand.nextDouble() * 2 - 1)).toInt();
    final result = max(0, exp + jitter);
    return Duration(milliseconds: result);
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    final interval = _config.heartbeatInterval;
    if (interval <= Duration.zero) return;
    final payload = _config.heartbeatPayload ?? '';
    _heartbeatTimer = Timer.periodic(interval, (_) {
      try {
        _channel?.sink.add(_encode(payload));
      } catch (e) {
        _logger?.warn('[ws] heartbeat send failed: $e');
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _cancelTimers() {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _emitState(WsConnectionState s) {
    if (_disposed) return;
    if (s == _state) return;
    _state = s;
    if (!_stateController.isClosed) {
      _stateController.add(s);
    }
  }

  Object _encode(Object data) {
    if (data is String || data is List<int>) return data;
    if (data is Map || data is List) return jsonEncode(data);
    return data.toString();
  }

  // ── topic helpers ─────────────────────────────────────────────────────────

  void _sendSubscribeFrame(String topic) {
    final builder = _config.topicRouter?.subscribeFrameBuilder;
    if (builder == null) return;
    final frame = builder(topic);
    if (frame == null) return;
    send(frame);
  }

  void _sendUnsubscribeFrame(String topic) {
    final builder = _config.topicRouter?.unsubscribeFrameBuilder;
    if (builder == null) return;
    final frame = builder(topic);
    if (frame == null) return;
    send(frame);
  }

  /// 重连成功后，把所有活跃 topic 的 subscribe 帧重新发一遍。
  /// 业务无感知——首次连接也会经过这里（此时 _topics 大概率为空，no-op）。
  void _replaySubscriptions() {
    if (_topics.isEmpty) return;
    final builder = _config.topicRouter?.subscribeFrameBuilder;
    if (builder == null) return;
    for (final topic in _topics.keys) {
      final frame = builder(topic);
      if (frame == null) continue;
      send(frame);
    }
  }
}

/// 单个 topic 的订阅状态：广播 controller + 引用计数。
class _TopicEntry {
  _TopicEntry() : controller = StreamController<dynamic>.broadcast();
  final StreamController<dynamic> controller;
  int refCount = 0;
}

/// 默认 channel 工厂：将 [WsClientConfig] 转换为 [WebSocketChannel]。
///
/// 所有 URL 转换使用纯字符串操作，不依赖 `Uri.replace()`——
/// 避免 Dart SDK 在 `replace(queryParameters:)` 时引入 `:0` port 的 bug。
WebSocketChannel _defaultFactory(WsClientConfig config) {
  final headers = config.headersProvider?.call();
  final queryParams = config.queryParamsProvider?.call();

  final rawUrl = config.url.toString();
  String url = rawUrl;

  debugPrint('[WS] ── _defaultFactory ──');
  debugPrint('[WS]   raw: $rawUrl');

  // ── 1. query params ────────────────────────────────────────────────────
  if (queryParams != null && queryParams.isNotEmpty) {
    final sep = config.url.hasQuery ? '&' : '?';
    final queryStr = queryParams.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    url = '$url$sep$queryStr';
    debugPrint('[WS]   +query: $queryStr');
  }

  // ── 2. scheme 容错 ─────────────────────────────────────────────────────
  if (url.startsWith('https://')) {
    url = url.replaceFirst('https://', 'wss://');
    debugPrint('[WS]   scheme: https → wss');
  } else if (url.startsWith('http://')) {
    url = url.replaceFirst('http://', 'ws://');
    debugPrint('[WS]   scheme: http → ws');
  }

  // ── 3. port :0 兜底 ────────────────────────────────────────────────────
  if (url.contains('/:0/')) {
    url = url.replaceFirst('/:0/', '/');
    debugPrint('[WS]   port: removed :0');
  }

  debugPrint('[WS]   final: $url');
  debugPrint('[WS]   headers: ${headers != null ? '${headers.length} pairs' : 'none'}');
  debugPrint('[WS] ──────────────────');

  return IOWebSocketChannel.connect(
    url,
    protocols: config.protocols,
    headers: headers,
  );
}

