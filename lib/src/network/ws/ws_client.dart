import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../flutter_spine.dart';

/// 工厂签名：根据 [config] 创建一个底层 [WebSocketChannel]。
///
/// 默认实现走 `WebSocketChannel.connect`；测试中可以替换为 fake channel
/// 来不依赖真实网络验证状态机 / 重连逻辑。
typedef WsChannelFactory = WebSocketChannel Function(WsClientConfig config);

/// WebSocket 客户端抽象。
///
/// ## 责任
/// * 管理"连接 → 已连 → 断开 → 重连"的状态机；
/// * 暴露 [connectionState] 流给 UI 显示指示器；
/// * 暴露 [messages] broadcast 流给业务消费；
/// * 提供 [send] 发消息（支持 String / List<int> / Map / List 自动 JSON 编码）；
/// * 周期性发心跳保活；
/// * 失败时按指数退避自动重连；
/// * 支持 [WsClientConfig.onAuthExpired] token 过期后自动刷新并重连
///   （基于 close code 检测 + 单飞 token 刷新）；
/// * 可选：按 topic 路由消息（[subscribe] / [unsubscribe]），
///   配合 [WsClientConfig.topicRouter] 使用，**不**配置则禁用、保留 raw [messages] 流。
///
/// ## 不做
/// * **不**做消息持久化 / 离线队列；
/// * **不**做端到端加密；
/// * **不**假设具体的订阅协议——业务用 [WsTopicRouter] 描述自家协议（topic 抽取 +
///   subscribe/unsubscribe 帧构造）。
///
/// ## 用法
///
/// ```dart
/// // 1) 拿 client（首次 watch 不会 connect，懒加载）
/// final ws = ref.watch(wsClientProvider(Uri.parse('wss://api/x/feed')));
///
/// // 2a) 直接订阅 topic（推荐）——第一次订阅时自动 connect
/// final sub = ws.subscribe<OrderEvent>(
///   'order_update',
///   decoder: (raw) => OrderEvent.fromJson(jsonDecode(raw as String) as Map<String, dynamic>),
/// ).listen(_onEvent);
///
/// // 2b) 或者直接监听全量 raw 流（不需要 topic 路由时）
/// await ws.connect();
/// ws.messages.listen((raw) => ...);
///
/// // 3) 发送
/// ws.send({'op': 'order_create', 'symbol': 'BTC'});
///
/// // 4) 状态指示
/// ws.connectionState.listen((s) => debugPrint('ws state: $s'));
///
/// // 5) 退出
/// await sub.cancel();
/// await ws.unsubscribe('order_update');
/// await ws.disconnect();
/// ```
abstract class WsClient {
  /// 当前快照状态。
  WsConnectionState get currentState;

  /// 状态变化流（broadcast）——UI 显示连接指示器。
  Stream<WsConnectionState> get connectionState;

  /// 服务端推送消息流（broadcast，全量）。元素类型：
  /// * 文本帧 → [String]
  /// * 二进制帧 → `List<int>`
  ///
  /// 是否做 JSON 解码由业务自定（通常 `jsonDecode(msg as String)`）。
  ///
  /// **不**会被 [WsClientConfig.topicRouter] 过滤——topic 路由仅影响 [subscribe]
  /// 返回的子流；本流始终广播完整消息，方便调试和"不分 topic"的全量消费场景。
  Stream<dynamic> get messages;

  /// 启动连接。多次调用幂等：已连/连接中时 no-op。
  Future<void> connect();

  /// 主动断开。state → [WsDisconnected]，**不**触发自动重连。
  Future<void> disconnect({int? code, String? reason});

  /// 发送一条消息。
  ///
  /// * `String` / `List<int>` 直接发；
  /// * `Map` / `List` 自动 `jsonEncode` 后作为文本帧发；
  /// * 其他类型 → `toString()`。
  ///
  /// 若当前未连接，行为由实现决定（[DefaultWsClient] 会丢弃并打 warn）。
  void send(Object data);

  /// 释放所有资源（关 channel、停心跳、关 controller）。`Notifier.onDispose` 里调。
  Future<void> dispose();

  // ── topic 订阅 ────────────────────────────────────────────────────────────

  /// 订阅指定 [topic]，返回该 topic 的消息流（已按
  /// [WsClientConfig.topicRouter].topicExtractor 过滤）。
  ///
  /// 行为：
  /// * **共享 stream**：同一 topic 多次订阅返回同一个 broadcast stream，引用计数；
  /// * **懒连接**：[autoConnect]=true（默认）且当前 [WsIdle] 时，自动 [connect]；
  /// * **协议帧**：引用从 0→1 时若 [WsTopicRouter.subscribeFrameBuilder] 非空，
  ///   且当前已连接，发送 subscribe 帧；
  /// * **重连重订阅**：自动重连成功后会重放所有活跃 topic 的 subscribe 帧——
  ///   业务代码不需要在重连后重新 [subscribe]；
  /// * **decoder**：[decoder] 把 raw 帧（通常是 JSON 字符串）映射成 [T]。
  ///
  /// 前置条件：[WsClientConfig.topicRouter] 必须已配置；否则抛 [StateError]。
  Stream<T> subscribe<T>(
    String topic, {
    T Function(dynamic raw)? decoder,
    bool autoConnect = true,
  });

  /// 取消对 [topic] 的订阅（引用计数 -1）。
  ///
  /// 计数归零时：
  /// * 关闭对应的本地 broadcast controller；
  /// * 若 [WsTopicRouter.unsubscribeFrameBuilder] 非空且当前已连接，发送 unsubscribe 帧。
  ///
  /// 不在订阅列表中时静默 no-op，不抛异常。
  Future<void> unsubscribe(String topic);

  /// 当前是否已订阅 [topic]（引用计数 > 0）。
  bool isSubscribed(String topic);

  /// 当前已订阅的 topic 集合（只读快照）。
  Set<String> get subscribedTopics;
}

/// 描述 WebSocket 服务端的"订阅协议"——核心包不假设具体协议，由业务定义。
///
/// ## 三个职责
///
/// 1. **从 raw 消息抽出 topic 名**：决定 [WsClient.subscribe] 返回的子流接收哪些消息；
/// 2. **构造 subscribe 帧**：第一次订阅某 topic 时往后端发什么；
/// 3. **构造 unsubscribe 帧**：最后一个订阅取消时往后端发什么。
///
/// ## 三种部署
///
/// * **纯客户端 filter**（不通知后端）：
///   ```dart
///   WsTopicRouter(
///     topicExtractor: (raw) =>
///         (jsonDecode(raw as String) as Map)['type'] as String?,
///   )
///   ```
///
/// * **协议级订阅**（典型 pub/sub 后端）：
///   ```dart
///   WsTopicRouter(
///     topicExtractor: (raw) =>
///         (jsonDecode(raw as String) as Map)['channel'] as String?,
///     subscribeFrameBuilder: (t) => {'op': 'subscribe', 'channel': t},
///     unsubscribeFrameBuilder: (t) => {'op': 'unsubscribe', 'channel': t},
///   )
///   ```
///
/// * **多字段 topic**（业务自定义命名规则）：
///   ```dart
///   topicExtractor: (raw) {
///     final m = jsonDecode(raw as String) as Map;
///     return '${m['type']}:${m['symbol']}';   // e.g. 'kline:BTCUSDT'
///   }
///   ```
class WsTopicRouter {
  const WsTopicRouter({
    required this.topicExtractor,
    this.subscribeFrameBuilder,
    this.unsubscribeFrameBuilder,
  });

  /// 从 raw message 抽出 topic 名。
  ///
  /// 返回 `null` 表示该消息**不属于任何 topic**——只会出现在 [WsClient.messages] 全量流，
  /// 不会被任何 [WsClient.subscribe] 子流接收。
  ///
  /// 抛异常时该消息被静默丢弃（实现层 catch 住，避免单条坏消息导致整个 listener 崩）。
  final String? Function(dynamic raw) topicExtractor;

  /// 订阅协议帧构造器。`null` = 纯客户端 filter，不通知后端。
  ///
  /// 返回值会经 [WsClient.send] 编码（`Map`/`List` 自动 jsonEncode）。
  final Object? Function(String topic)? subscribeFrameBuilder;

  /// 退订协议帧构造器。`null` = 不通知后端。
  final Object? Function(String topic)? unsubscribeFrameBuilder;
}

/// [WsClient] 配置。
class WsClientConfig {
  const WsClientConfig({
    required this.url,
    this.protocols,
    this.headersProvider,
    this.queryParamsProvider,
    this.connectTimeout = const Duration(seconds: 10),
    this.heartbeatInterval = const Duration(seconds: 25),
    this.heartbeatPayload = '{"op":"ping"}',
    this.baseReconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 30),
    this.maxReconnectAttempts = -1,
    this.reconnectJitterRatio = 0.2,
    this.topicRouter,
    this.onAuthExpired,
    this.isAuthCloseCode,
  });

  /// 完整 ws/wss URL。
  final Uri url;

  /// WebSocket 子协议（Sec-WebSocket-Protocol）。
  final Iterable<String>? protocols;

  /// HTTP 升级握手时附带的动态 headers 提供者。
  ///
  /// 每次 [WsClient.connect] / 自动重连时调用此回调取最新 headers，
  /// 实现 token 过期后重连自动携带新 token，无需重建 [WsClientConfig]。
  ///
  /// `null` = 不带附加 headers（默认）。
  final Map<String, dynamic> Function()? headersProvider;

  /// 每次 connect / 重连时动态拼接到 URL query string 的参数提供者。
  ///
  /// 适用于 token 通过 query 参数传递（非 header）的场景：
  ///
  /// ```dart
  /// queryParamsProvider: () => {'token': session.accessToken},
  /// ```
  ///
  /// 实际连接 URL 为 `$url?$baseQuery&$dynamicParams`，动态参数会覆盖 base URL
  /// 中的同名参数（后者优先）。`null` = 不拼接额外 query 参数（默认）。
  final Map<String, String> Function()? queryParamsProvider;

  /// 握手超时。超时视为连接失败，进入重连流程。
  final Duration connectTimeout;

  /// 心跳间隔。设为 [Duration.zero] 关闭心跳。
  final Duration heartbeatInterval;

  /// 心跳 payload。`null` 时改发 `''`。可传 `Map`，会被 `jsonEncode`。
  final Object? heartbeatPayload;

  /// 第一次重连等待时间。后续按 `pow(2, attempt-1) * base` 增长，封顶
  /// [maxReconnectDelay]。
  final Duration baseReconnectDelay;
  final Duration maxReconnectDelay;

  /// `-1` = 无限重连。否则达到次数后状态进入 [WsFailed]。
  final int maxReconnectAttempts;

  /// 重连延迟随机抖动比例（0~1）。0.2 表示 ±20% 抖动，避免雪崩。
  final double reconnectJitterRatio;

  /// topic 路由配置。`null` = 禁用 topic 订阅（[WsClient.subscribe] 抛 [StateError]），
  /// 业务直接消费 [WsClient.messages] 全量流。
  final WsTopicRouter? topicRouter;

  /// auth 过期时的 token 刷新回调。
  ///
  /// 当服务端关闭连接且 close code 被 [isAuthCloseCode] 判定为 auth 过期时，
  /// [DefaultWsClient] 会调用此回调获取新 token，成功后自动重连。
  /// 支持**单飞**保证：多个并发的 auth close 事件只触发一次刷新。
  ///
  /// * 返回 `null` / 空字符串：视为刷新失败，状态进入 [WsFailed]，停止重连；
  /// * 抛异常：同上，异常信息记日志后进入 [WsFailed]。
  ///
  /// 未配置时 auth 过期会走普通重连逻辑（可能无限重连失败）。
  final Future<String?> Function()? onAuthExpired;

  /// 判断 close code 是否为 auth 过期（如 4001、1008 等自定义码）。
  ///
  /// `null` = 不做 auth 检测，所有远端关闭统一走普通重连。
  /// `closeCode` 为 `null` 时表示无法获取 close code（平台不支持或未完成关闭帧交换），
  /// 此时谓词通常应返回 `false`。
  final bool Function(int? closeCode)? isAuthCloseCode;
}
