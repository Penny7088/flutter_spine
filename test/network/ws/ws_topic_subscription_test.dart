import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 跟 default_ws_client_test.dart 同款的 fake channel——
/// 复制一份避免跨文件耦合（测试文件互相 import 容易失稳）。
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

class _ChannelSource {
  final List<_FakeWsChannel> channels = [];

  WsChannelFactory get factory => (config) {
        final c = _FakeWsChannel();
        channels.add(c);
        return c;
      };

  _FakeWsChannel get last => channels.last;
}

/// 标准 pub/sub 协议：消息形如 `{"channel": "...", "data": ...}`，
/// subscribe 帧 `{"op":"subscribe","channel":"..."}`。
WsTopicRouter _stdRouter() => WsTopicRouter(
      topicExtractor: (raw) {
        if (raw is! String) return null;
        final m = jsonDecode(raw) as Map<String, dynamic>;
        return m['channel'] as String?;
      },
      subscribeFrameBuilder: (t) => {'op': 'subscribe', 'channel': t},
      unsubscribeFrameBuilder: (t) => {'op': 'unsubscribe', 'channel': t},
    );

WsClientConfig _config({
  WsTopicRouter? router,
  Duration heartbeat = Duration.zero,
  Duration baseReconnect = const Duration(milliseconds: 100),
  int maxAttempts = -1,
}) =>
    WsClientConfig(
      url: Uri.parse('wss://test.invalid/x'),
      heartbeatInterval: heartbeat,
      baseReconnectDelay: baseReconnect,
      connectTimeout: const Duration(seconds: 1),
      reconnectJitterRatio: 0,
      maxReconnectAttempts: maxAttempts,
      topicRouter: router,
    );

Future<void> _connectOk(DefaultWsClient client, _ChannelSource source) async {
  final f = client.connect();
  while (source.channels.isEmpty) {
    await Future<void>.delayed(Duration.zero);
  }
  source.last.completeReady();
  await f;
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('subscribe — 路由', () {
    test('subscribe 仅收到匹配 topic 的消息；其他 topic 不串流', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(router: _stdRouter()),
        channelFactory: source.factory,
      );
      await _connectOk(client, source);

      final orderEvents = <String>[];
      final tradeEvents = <String>[];
      final orderSub = client
          .subscribe<String>('orders', autoConnect: false)
          .listen(orderEvents.add);
      final tradeSub = client
          .subscribe<String>('trades', autoConnect: false)
          .listen(tradeEvents.add);

      source.last
          .receiveMessage('{"channel":"orders","data":{"id":1}}');
      source.last
          .receiveMessage('{"channel":"trades","data":{"id":2}}');
      source.last
          .receiveMessage('{"channel":"orders","data":{"id":3}}');
      source.last.receiveMessage('{"channel":"unknown","data":1}');
      await Future<void>.delayed(Duration.zero);

      expect(orderEvents.length, 2);
      expect(tradeEvents.length, 1);
      expect(orderEvents.every((e) => e.contains('"channel":"orders"')), isTrue);
      expect(tradeEvents.first.contains('"channel":"trades"'), isTrue);

      await orderSub.cancel();
      await tradeSub.cancel();
      await client.dispose();
    });

    test('messages 全量流不被 topic 过滤（包括 null-topic 消息）', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(router: _stdRouter()),
        channelFactory: source.factory,
      );
      await _connectOk(client, source);

      final all = <dynamic>[];
      client.messages.listen(all.add);
      // 订阅 orders 但 messages 应仍收 trades
      final sub =
          client.subscribe<dynamic>('orders', autoConnect: false).listen((_) {});

      source.last.receiveMessage('{"channel":"orders","data":1}');
      source.last.receiveMessage('{"channel":"trades","data":2}');
      source.last.receiveMessage('{"no_channel":"x"}'); // extractor → null
      await Future<void>.delayed(Duration.zero);

      expect(all.length, 3);

      await sub.cancel();
      await client.dispose();
    });

    test('decoder：raw → 业务对象', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(router: _stdRouter()),
        channelFactory: source.factory,
      );
      await _connectOk(client, source);

      final ids = <int>[];
      final sub = client.subscribe<int>(
        'orders',
        autoConnect: false,
        decoder: (raw) => (jsonDecode(raw as String) as Map)['data']['id'] as int,
      ).listen(ids.add);

      source.last.receiveMessage('{"channel":"orders","data":{"id":42}}');
      source.last.receiveMessage('{"channel":"orders","data":{"id":7}}');
      await Future<void>.delayed(Duration.zero);

      expect(ids, [42, 7]);
      await sub.cancel();
      await client.dispose();
    });

    test('topicExtractor 抛异常 → 该消息丢弃，不影响后续', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(
          router: WsTopicRouter(
            topicExtractor: (raw) {
              final s = raw as String;
              if (s == 'BAD') throw const FormatException('boom');
              return s;
            },
          ),
        ),
        channelFactory: source.factory,
      );
      await _connectOk(client, source);

      final got = <dynamic>[];
      final sub = client
          .subscribe<dynamic>('orders', autoConnect: false)
          .listen(got.add);

      source.last.receiveMessage('orders');
      source.last.receiveMessage('BAD');
      source.last.receiveMessage('orders');
      await Future<void>.delayed(Duration.zero);

      expect(got, ['orders', 'orders']);
      await sub.cancel();
      await client.dispose();
    });
  });

  group('subscribe — 引用计数', () {
    test('同 topic 双订阅者：一方 unsubscribe，另一方仍收消息', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(router: _stdRouter()),
        channelFactory: source.factory,
      );
      await _connectOk(client, source);

      final aMsgs = <dynamic>[];
      final bMsgs = <dynamic>[];
      final aSub = client
          .subscribe<dynamic>('orders', autoConnect: false)
          .listen(aMsgs.add);
      final bSub = client
          .subscribe<dynamic>('orders', autoConnect: false)
          .listen(bMsgs.add);

      source.last.receiveMessage('{"channel":"orders","data":1}');
      await Future<void>.delayed(Duration.zero);
      expect(aMsgs.length, 1);
      expect(bMsgs.length, 1);

      // A 退订：refCount 仍 > 0，B 应继续收
      await client.unsubscribe('orders');
      expect(client.isSubscribed('orders'), isTrue);

      source.last.receiveMessage('{"channel":"orders","data":2}');
      await Future<void>.delayed(Duration.zero);
      // A 还监听着同一个 stream，所以也会收到——这是 broadcast 的语义。
      // 关键是 client 端引用未归零，没发 unsubscribe 帧 / 没关 controller。
      expect(bMsgs.length, 2);

      await aSub.cancel();
      await bSub.cancel();
      await client.dispose();
    });

    test('refCount 归零 → 发 unsubscribe 帧 + 状态更新', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(router: _stdRouter()),
        channelFactory: source.factory,
      );
      await _connectOk(client, source);

      final sent = <dynamic>[];
      source.last.sentMessages.listen(sent.add);

      // 第一次订阅 → 发 subscribe 帧
      final sub = client
          .subscribe<dynamic>('orders', autoConnect: false)
          .listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(sent, ['{"op":"subscribe","channel":"orders"}']);
      expect(client.isSubscribed('orders'), isTrue);
      expect(client.subscribedTopics, {'orders'});

      // 第二次订阅同 topic：不重复发
      final sub2 = client
          .subscribe<dynamic>('orders', autoConnect: false)
          .listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(sent.length, 1, reason: '同 topic 第二次订阅不应重复发 frame');

      // 退一次：refCount 1，仍订阅；不发 unsubscribe
      await client.unsubscribe('orders');
      expect(client.isSubscribed('orders'), isTrue);
      expect(sent.length, 1);

      // 退第二次：refCount 0，发 unsubscribe，状态清掉
      await client.unsubscribe('orders');
      await Future<void>.delayed(Duration.zero);
      expect(client.isSubscribed('orders'), isFalse);
      expect(client.subscribedTopics, isEmpty);
      expect(sent, [
        '{"op":"subscribe","channel":"orders"}',
        '{"op":"unsubscribe","channel":"orders"}',
      ]);

      await sub.cancel();
      await sub2.cancel();
      await client.dispose();
    });

    test('unsubscribe 未订阅的 topic → no-op', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(router: _stdRouter()),
        channelFactory: source.factory,
      );
      await _connectOk(client, source);

      // 不抛
      await client.unsubscribe('never_subscribed');
      expect(client.subscribedTopics, isEmpty);

      await client.dispose();
    });
  });

  group('subscribe — autoConnect / 懒连接', () {
    test('idle 状态 subscribe(autoConnect: true) → 自动 connect', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(router: _stdRouter()),
        channelFactory: source.factory,
      );

      expect(client.currentState, isA<WsIdle>());
      final stream = client.subscribe<dynamic>('orders');
      final sub = stream.listen((_) {});

      // 等 connect 流程触发 channel 创建
      while (source.channels.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      source.last.completeReady();
      await Future<void>.delayed(Duration.zero);

      expect(client.currentState, isA<WsConnected>());
      // 连上后应当下发 subscribe 帧（replay 阶段）
      final sent = <dynamic>[];
      source.last.sentMessages.listen(sent.add);
      // 上面 replay 在 _connectOk 完成的同一 microtask 里已经 send 完了，
      // 监听是事后的，所以这里再补一条来确认 channel 工作正常即可。
      // 真正断言「订阅帧已发」放到下一个 test。
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      await client.dispose();
    });

    test(
        'idle 时 subscribe → 自动连接成功后由 replay 发 subscribe 帧（不需要业务再调）',
        () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(router: _stdRouter()),
        channelFactory: source.factory,
      );

      // 提前订阅
      final sub =
          client.subscribe<dynamic>('orders').listen((_) {});

      while (source.channels.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      // 在 ready 完成之前先挂上 sentMessages 监听器，免得错过 replay
      final sent = <dynamic>[];
      source.last.sentMessages.listen(sent.add);

      source.last.completeReady();
      // 等 replay 执行
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(sent, contains('{"op":"subscribe","channel":"orders"}'));

      await sub.cancel();
      await client.dispose();
    });

    test('subscribe(autoConnect: false) 不会自动连', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(router: _stdRouter()),
        channelFactory: source.factory,
      );

      final sub = client
          .subscribe<dynamic>('orders', autoConnect: false)
          .listen((_) {});
      // 给 microtask 一些时间
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(client.currentState, isA<WsIdle>());
      expect(source.channels, isEmpty);

      await sub.cancel();
      await client.dispose();
    });

    test('connecting 状态下再 subscribe 不会重复触发 connect', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(router: _stdRouter()),
        channelFactory: source.factory,
      );

      // 先发起 connect 但不 completeReady → 卡在 connecting
      final connectFuture = client.connect();
      while (source.channels.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(client.currentState, isA<WsConnecting>());
      expect(source.channels.length, 1);

      // 在 connecting 状态下 subscribe(autoConnect: true)
      final sub = client.subscribe<dynamic>('orders').listen((_) {});
      await Future<void>.delayed(Duration.zero);

      // 不应再开第二条 channel
      expect(source.channels.length, 1);

      // 收尾：completeReady → connect 完成 → cleanup
      source.last.completeReady();
      await connectFuture;
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await client.dispose();
    });
  });

  group('subscribe — 重连 replay', () {
    test('对端断开 + 自动重连成功 → 重新发所有活跃 subscribe 帧', () {
      fakeAsync((async) {
        final source = _ChannelSource();
        final client = DefaultWsClient(
          _config(
            router: _stdRouter(),
            baseReconnect: const Duration(milliseconds: 100),
          ),
          channelFactory: source.factory,
          random: Random(0),
        );

        // 连上
        client.connect();
        async.flushMicrotasks();
        source.last.completeReady();
        async.flushMicrotasks();

        // 先订阅两个 topic
        client.subscribe<dynamic>('orders', autoConnect: false).listen((_) {});
        client.subscribe<dynamic>('trades', autoConnect: false).listen((_) {});
        async.flushMicrotasks();

        // 收集第二条 channel 的发送内容
        // 模拟对端断开，等重连
        source.last.simulateRemoteClose();
        async.flushMicrotasks();
        expect(client.currentState, isA<WsReconnecting>());

        // 推进到重连
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
        // 此时应有 channels[1]
        expect(source.channels.length, 2);

        final replayed = <dynamic>[];
        source.channels[1].sentMessages.listen(replayed.add);

        source.channels[1].completeReady();
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();

        expect(client.currentState, isA<WsConnected>());
        expect(replayed, containsAll([
          '{"op":"subscribe","channel":"orders"}',
          '{"op":"subscribe","channel":"trades"}',
        ]));

        client.dispose();
      });
    });
  });

  group('subscribe — 配置缺失 / dispose 后', () {
    test('未配 topicRouter → subscribe 抛 StateError', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(router: null),
        channelFactory: source.factory,
      );
      expect(
        () => client.subscribe<dynamic>('orders'),
        throwsA(isA<StateError>()),
      );
      await client.dispose();
    });

    test('dispose 后 subscribe 抛 StateError', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(router: _stdRouter()),
        channelFactory: source.factory,
      );
      await client.dispose();
      expect(
        () => client.subscribe<dynamic>('orders'),
        throwsA(isA<StateError>()),
      );
    });

    test('subscribeFrameBuilder = null → 纯客户端 filter，不发任何协议帧', () async {
      final source = _ChannelSource();
      final client = DefaultWsClient(
        _config(
          router: WsTopicRouter(
            topicExtractor: (raw) =>
                (jsonDecode(raw as String) as Map)['type'] as String?,
            // subscribeFrameBuilder / unsubscribeFrameBuilder 都 null
          ),
        ),
        channelFactory: source.factory,
      );
      await _connectOk(client, source);

      final sent = <dynamic>[];
      source.last.sentMessages.listen(sent.add);

      final got = <dynamic>[];
      final sub = client
          .subscribe<dynamic>('A', autoConnect: false)
          .listen(got.add);

      source.last.receiveMessage('{"type":"A","v":1}');
      source.last.receiveMessage('{"type":"B","v":2}');
      await Future<void>.delayed(Duration.zero);

      expect(got, ['{"type":"A","v":1}']);
      expect(sent, isEmpty, reason: 'router 没给 frame builder，不应发任何帧');

      await client.unsubscribe('A');
      await Future<void>.delayed(Duration.zero);
      expect(sent, isEmpty);

      await sub.cancel();
      await client.dispose();
    });
  });
}
