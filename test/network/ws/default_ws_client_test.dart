import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 最小化的 fake WebSocket channel：
/// * 测试用 [completeReady] / [failReady] 控制握手；
/// * 用 [receiveMessage] / [simulateRemoteClose] 模拟对端；
/// * 用 [sentMessages] 拿到发出的内容。
class _FakeWsChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeWsChannel();

  final _incoming = StreamController<dynamic>.broadcast();
  final _outgoing = StreamController<dynamic>();
  final _ready = Completer<void>();
  bool _closed = false;

  void completeReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void failReady(Object error) {
    if (!_ready.isCompleted) _ready.completeError(error);
  }

  void receiveMessage(dynamic msg) => _incoming.add(msg);

  void simulateRemoteClose() {
    if (!_incoming.isClosed) _incoming.close();
  }

  Stream<dynamic> get sentMessages => _outgoing.stream;

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _FakeSink(this);

  @override
  String? get protocol => null;
  @override
  int? get closeCode => _closed ? 1000 : null;
  @override
  String? get closeReason => null;
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this._parent);
  final _FakeWsChannel _parent;

  @override
  void add(dynamic data) {
    if (!_parent._outgoing.isClosed) _parent._outgoing.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final v in stream) {
      add(v);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    _parent._closed = true;
    if (!_parent._incoming.isClosed) await _parent._incoming.close();
    if (!_parent._outgoing.isClosed) await _parent._outgoing.close();
  }

  @override
  Future<void> get done => _parent._outgoing.done;
}

/// 工厂：维护一个外部可访问的 channel 列表，方便依次取出。
class _ChannelSource {
  final List<_FakeWsChannel> channels = [];

  WsChannelFactory get factory => (config) {
        final c = _FakeWsChannel();
        channels.add(c);
        return c;
      };

  _FakeWsChannel get last => channels.last;
}

WsClientConfig _config({
  Duration heartbeat = Duration.zero,
  Duration baseReconnect = const Duration(milliseconds: 100),
  Duration maxReconnect = const Duration(seconds: 5),
  Duration connectTimeout = const Duration(seconds: 1),
  int maxAttempts = -1,
}) =>
    WsClientConfig(
      url: Uri.parse('wss://test.invalid/x'),
      heartbeatInterval: heartbeat,
      baseReconnectDelay: baseReconnect,
      maxReconnectDelay: maxReconnect,
      connectTimeout: connectTimeout,
      maxReconnectAttempts: maxAttempts,
      reconnectJitterRatio: 0, // 测试关掉 jitter，方便对时间断言
    );

void main() {
  group('DefaultWsClient — 状态机', () {
    test('connect 成功 → idle → connecting → connected', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(_config(), channelFactory: source.factory);

      final states = <WsConnectionState>[client.currentState];
      final sub = client.connectionState.listen(states.add);

      await _connectOk(client, source);

      expect(client.currentState, isA<WsConnected>());
      expect(states.first, isA<WsIdle>());
      expect(states[1], isA<WsConnecting>());
      expect(states.last, isA<WsConnected>());

      await sub.cancel();
      await client.dispose();
    });

    test('多次 connect 幂等', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(_config(), channelFactory: source.factory);

      await _connectOk(client, source);
      expect(source.channels.length, 1);

      // 已 connected，再 connect 不该建第二条
      await client.connect();
      expect(source.channels.length, 1);

      await client.dispose();
    });

    test('disconnect → state=Disconnected，不再重连', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(_config(), channelFactory: source.factory);

      await _connectOk(client, source);
      await client.disconnect(code: 1000, reason: 'bye');

      expect(client.currentState, isA<WsDisconnected>());
      final s = client.currentState as WsDisconnected;
      expect(s.code, 1000);
      expect(s.reason, 'bye');

      // 等够重连时间窗，确认不会再开新 channel
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(source.channels.length, 1);

      await client.dispose();
    });
  });

  group('DefaultWsClient — 消息收发', () {
    test('messages 流接收对端文本帧', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(_config(), channelFactory: source.factory);
      await _connectOk(client, source);

      final received = <dynamic>[];
      client.messages.listen(received.add);

      source.last.receiveMessage('hello');
      source.last.receiveMessage('world');
      await Future<void>.delayed(Duration.zero);

      expect(received, ['hello', 'world']);
      await client.dispose();
    });

    test('send Map → 自动 jsonEncode', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(_config(), channelFactory: source.factory);
      await _connectOk(client, source);

      final sent = <dynamic>[];
      source.last.sentMessages.listen(sent.add);

      client.send({'op': 'sub', 'topic': 'orders'});
      await Future<void>.delayed(Duration.zero);

      expect(sent, ['{"op":"sub","topic":"orders"}']);
      await client.dispose();
    });

    test('send 在未连接时丢弃，不抛异常', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(_config(), channelFactory: source.factory);

      // 没 connect，直接 send 应该是 no-op
      expect(() => client.send('x'), returnsNormally);
      await client.dispose();
    });
  });

  group('DefaultWsClient — 重连', () {
    test('对端关闭 → WsReconnecting → 自动重连成功', () {
      fakeAsync((async) {
        final source = _ChannelSource();
        final client = DefaultWsClient(
          _config(baseReconnect: const Duration(milliseconds: 100)),
          channelFactory: source.factory,
          random: Random(0),
        );

        final states = <WsConnectionState>[];
        client.connectionState.listen(states.add);

        client.connect();
        async.flushMicrotasks();
        source.last.completeReady();
        async.flushMicrotasks();
        expect(client.currentState, isA<WsConnected>());

        // 模拟对端断开
        source.last.simulateRemoteClose();
        async.flushMicrotasks();
        expect(client.currentState, isA<WsReconnecting>());
        final reconState = client.currentState as WsReconnecting;
        expect(reconState.attempt, 1);
        expect(reconState.nextDelay, const Duration(milliseconds: 100));

        // 推进到重连触发，本次仍假设成功
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
        source.last.completeReady();
        async.flushMicrotasks();

        expect(client.currentState, isA<WsConnected>());
        expect(source.channels.length, 2);

        client.dispose();
      });
    });

    test('达到 maxReconnectAttempts → WsFailed', () {
      fakeAsync((async) {
        final source = _ChannelSource();
        final client = DefaultWsClient(
          _config(
            baseReconnect: const Duration(milliseconds: 50),
            connectTimeout: const Duration(seconds: 1),
            maxAttempts: 2,
          ),
          channelFactory: source.factory,
          random: Random(0),
        );

        client.connect();
        async.flushMicrotasks();

        // attempt 1: 1s 超时 + 50ms 延迟
        async.elapse(const Duration(milliseconds: 1050));
        async.flushMicrotasks();
        // attempt 2: 1s 超时 + 100ms 延迟
        async.elapse(const Duration(milliseconds: 1100));
        async.flushMicrotasks();
        // 第 3 次连接失败 —— attempt=3 超过 maxAttempts=2 → Failed
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(client.currentState, isA<WsFailed>());
        client.dispose();
      });
    });

    test('指数退避：attempt 越大，等待越长（封顶 max）', () {
      fakeAsync((async) {
        final source = _ChannelSource();
        final client = DefaultWsClient(
          _config(
            baseReconnect: const Duration(milliseconds: 100),
            maxReconnect: const Duration(milliseconds: 800),
            connectTimeout: const Duration(seconds: 1),
          ),
          channelFactory: source.factory,
          random: Random(0),
        );

        final delays = <Duration>[];
        client.connectionState.listen((s) {
          if (s is WsReconnecting) delays.add(s.nextDelay);
        });

        client.connect();
        async.flushMicrotasks();

        // 推进 5 个完整周期：每个周期 = 1s 超时 + 当前退避延迟。
        // 期望 nextDelay 序列：100, 200, 400, 800, 800（第 4 次起被 max 封顶）。
        const expected = [100, 200, 400, 800, 800];
        var prevDelayMs = 0;
        for (final ms in expected) {
          // 等 connect timeout（1s）+ 上一次的 reconnect 延迟（首轮 0）。
          async.elapse(const Duration(seconds: 1) + Duration(milliseconds: prevDelayMs));
          async.flushMicrotasks();
          prevDelayMs = ms;
        }

        expect(
          delays.map((d) => d.inMilliseconds).toList(),
          expected,
        );

        client.dispose();
      });
    });
  });

  group('DefaultWsClient — 心跳', () {
    test('connected 后周期性发心跳；disconnect 后停', () {
      fakeAsync((async) {
        final source = _ChannelSource();
        final client = DefaultWsClient(
          _config(heartbeat: const Duration(seconds: 1)),
          channelFactory: source.factory,
        );

        client.connect();
        async.flushMicrotasks();
        source.last.completeReady();
        async.flushMicrotasks();

        final sent = <dynamic>[];
        source.last.sentMessages.listen(sent.add);

        // 推进 3.5 秒，应该发 3 次心跳
        async.elapse(const Duration(milliseconds: 3500));
        async.flushMicrotasks();
        expect(sent.length, 3);
        expect(sent.first, '{"op":"ping"}');

        // disconnect → 心跳停
        client.disconnect();
        async.flushMicrotasks();
        sent.clear();
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(sent, isEmpty);

        client.dispose();
      });
    });
  });

  group('DefaultWsClient — dispose', () {
    test('dispose 后 connect 抛 StateError', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(_config(), channelFactory: source.factory);
      await client.dispose();
      await expectLater(client.connect(), throwsA(isA<StateError>()));
    });
  });
}

/// 助手：连接并完成握手。
Future<void> _connectOk(DefaultWsClient client, _ChannelSource source) async {
  final f = client.connect();
  // 等到 factory 真正被调用——Dart async 函数何时执行 body 是个细节，靠 poll 最稳。
  while (source.channels.isEmpty) {
    await Future<void>.delayed(Duration.zero);
  }
  source.last.completeReady();
  await f;
  // 等 broadcast stream 把 Connected 派发给所有 listener。
  await Future<void>.delayed(Duration.zero);
}
