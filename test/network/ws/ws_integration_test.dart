import 'dart:async';
import 'dart:convert';

import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// _FakeWsChannel — copies the pattern from default_ws_client_test.dart
/// to avoid cross-file coupling.
class _FakeWsChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeWsChannel();

  final _incoming = StreamController<dynamic>.broadcast();
  final _outgoing = StreamController<dynamic>();
  final _ready = Completer<void>();
  bool _closed = false;
  int? _closeCode;
  String? _closeReason;

  void completeReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void failReady(Object error) {
    if (!_ready.isCompleted) _ready.completeError(error);
  }

  void receiveMessage(dynamic msg) => _incoming.add(msg);

  void simulateRemoteClose({int? code, String? reason}) {
    _closeCode = code;
    _closeReason = reason;
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
  int? get closeCode => _closeCode;
  @override
  String? get closeReason => _closeReason;
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

/// A minimal PriceUpdate model for composite topic testing.
class _PriceUpdate {
  final String symbol;
  final double price;
  const _PriceUpdate({required this.symbol, required this.price});

  static _PriceUpdate fromRaw(dynamic raw) {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    return _PriceUpdate(
      symbol: m['symbol'] as String? ?? '',
      price: (m['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

WsClientConfig _config({WsTopicRouter? router}) => WsClientConfig(
      url: Uri.parse('wss://test.invalid/x'),
      topicRouter: router,
      heartbeatInterval: Duration.zero,
    );

Future<void> _connectOk(DefaultWsClient client, _FakeWsChannel ch) async {
  final f = client.connect();
  while (!ch._ready.isCompleted) {
    await Future<void>.delayed(Duration.zero);
  }
  ch.completeReady();
  await f;
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('WsClient integration — complete flow', () {
    test('connect → subscribe → receive → unsubscribe → cleanup', () async {
      final channel = _FakeWsChannel();
      channel.completeReady();

      final client = DefaultWsClient(
        _config(
          router: WsTopicRouter(
            topicExtractor: (raw) {
              final m = jsonDecode(raw as String) as Map<String, dynamic>;
              final channel = m['channel'] as String?;
              final chain = m['chainCaip2'] as String?;
              final addr = m['tokenContractAddress'] as String?;
              if (channel == null || chain == null || addr == null) return null;
              return '$channel|$chain|$addr';
            },
            subscribeFrameBuilder: (t) {
              final parts = t.split('|');
              return {
                'op': 'subscribe',
                'channel': parts[0],
                'chainCaip2': parts[1],
                'tokenContractAddress': parts[2],
              };
            },
            unsubscribeFrameBuilder: (t) => {
              'op': 'unsubscribe',
              'channel': t.split('|')[0],
            },
          ),
        ),
        channelFactory: (_) => channel,
      );

      // 1. connect
      await _connectOk(client, channel);
      expect(client.currentState, isA<WsConnected>());

      // 2. subscribe to price
      final topic = 'price-info|eip155:1|native';
      final received = <_PriceUpdate>[];
      final sub = client
          .subscribe<_PriceUpdate>(topic, decoder: _PriceUpdate.fromRaw)
          .listen(received.add);

      // 3. verify subscribe frame sent
      final sent = <dynamic>[];
      channel.sentMessages.listen(sent.add);
      await Future<void>.delayed(Duration.zero);
      expect(sent, isNotEmpty);
      final subFrame = jsonDecode(sent.last as String) as Map<String, dynamic>;
      expect(subFrame['op'], 'subscribe');
      expect(subFrame['channel'], 'price-info');

      // 4. simulate server push
      channel.receiveMessage(jsonEncode({
        'channel': 'price-info',
        'chainCaip2': 'eip155:1',
        'tokenContractAddress': 'native',
        'symbol': 'BTC/USD',
        'price': 50250.5,
      }));
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received.first.symbol, 'BTC/USD');
      expect(received.first.price, 50250.5);

      // 5. another push
      channel.receiveMessage(jsonEncode({
        'channel': 'price-info',
        'chainCaip2': 'eip155:1',
        'tokenContractAddress': 'native',
        'symbol': 'BTC/USD',
        'price': 50300.0,
      }));
      await Future<void>.delayed(Duration.zero);
      expect(received.length, 2);

      // 6. message for a different topic — should NOT arrive
      channel.receiveMessage(jsonEncode({
        'channel': 'candle4H',
        'chainCaip2': 'eip155:1',
        'tokenContractAddress': 'native',
      }));
      await Future<void>.delayed(Duration.zero);
      expect(received.length, 2);

      // 7. unsubscribe and verify cleanup
      expect(client.isSubscribed(topic), true);
      await client.unsubscribe(topic);
      expect(client.isSubscribed(topic), false);
      expect(client.subscribedTopics, isEmpty);

      // 8. cleanup
      await sub.cancel();
      await client.dispose();
    });

    test('subscribe/unsubscribe in sent frames', () async {
      final channel = _FakeWsChannel();
      channel.completeReady();

      final client = DefaultWsClient(
        _config(
          router: WsTopicRouter(
            topicExtractor: (raw) => null, // not needed for this test
            subscribeFrameBuilder:
                (t) => {'op': 'subscribe', 'channel': t},
            unsubscribeFrameBuilder:
                (t) => {'op': 'unsubscribe', 'channel': t},
          ),
        ),
        channelFactory: (_) => channel,
      );

      await _connectOk(client, channel);
      final sent = <dynamic>[];
      channel.sentMessages.listen(sent.add);

      // subscribe
      client.subscribe('order_update');
      await Future<void>.delayed(Duration.zero);
      expect(
        jsonDecode(sent.last as String),
        {'op': 'subscribe', 'channel': 'order_update'},
      );

      // unsubscribe
      await client.unsubscribe('order_update');
      await Future<void>.delayed(Duration.zero);
      expect(
        jsonDecode(sent.last as String),
        {'op': 'unsubscribe', 'channel': 'order_update'},
      );

      await client.dispose();
    });

    test('auto-connect on subscribe', () async {
      final channel = _FakeWsChannel();
      // NOT calling completeReady() — let subscribe trigger auto-connect

      final client = DefaultWsClient(
        _config(
          router: WsTopicRouter(
            topicExtractor: (raw) => null,
          ),
        ),
        channelFactory: (_) => channel,
      );

      expect(client.currentState, isA<WsIdle>());

      // subscribe triggers auto-connect
      client.subscribe('topic');
      // channel ready needs to complete for connect to succeed
      channel.completeReady();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(client.currentState, isA<WsConnected>());
      expect(client.isSubscribed('topic'), true);

      await client.unsubscribe('topic');
      await client.dispose();
    });

    test('headersProvider declared in config', () {
      int callCount = 0;
      final config = WsClientConfig(
        url: Uri.parse('wss://test.invalid/x'),
        heartbeatInterval: Duration.zero,
        headersProvider: () {
          callCount++;
          return {'Authorization': 'Bearer test'};
        },
      );

      // headersProvider is called inside _defaultFactory on each connect/reconnect
      final headers = config.headersProvider?.call();
      expect(headers, isNotNull);
      expect(headers!['Authorization'], 'Bearer test');
      expect(callCount, 1);
    });

    test('WsTopicRouter.simple factory', () async {
      final channel = _FakeWsChannel();
      channel.completeReady();

      final router = WsTopicRouter.simple();
      final client = DefaultWsClient(
        _config(router: router),
        channelFactory: (_) => channel,
      );

      await _connectOk(client, channel);
      final sent = <dynamic>[];
      channel.sentMessages.listen(sent.add);

      client.subscribe('market_data');
      await Future<void>.delayed(Duration.zero);

      final frame = jsonDecode(sent.last as String) as Map<String, dynamic>;
      expect(frame['op'], 'subscribe');
      expect(frame['channel'], 'market_data');

      // verify topic extractor works
      final received = <String>[];
      client.subscribe<String>('market_data').listen(received.add);

      channel.receiveMessage(jsonEncode({'channel': 'market_data', 'msg': 1}));
      await Future<void>.delayed(Duration.zero);
      expect(received.length, 1);

      // message for different channel — not received
      channel.receiveMessage(jsonEncode({'channel': 'other', 'msg': 2}));
      await Future<void>.delayed(Duration.zero);
      expect(received.length, 1);

      await client.dispose();
    });

    test('connect auth error → refresh token → reconnect', () async {
      int refreshCallCount = 0;

      final failChannel = _FakeWsChannel();
      failChannel.failReady(
        WebSocketChannelException('HTTP status code: 401'),
      );

      final succeedChannel = _FakeWsChannel();
      succeedChannel.completeReady();

      final channels = <_FakeWsChannel>[failChannel, succeedChannel];
      int factoryIdx = 0;

      final client = DefaultWsClient(
        WsClientConfig(
          url: Uri.parse('wss://test.invalid/x'),
          heartbeatInterval: Duration.zero,
          baseReconnectDelay: Duration.zero,
          reconnectJitterRatio: 0,
          isConnectAuthError: (error) {
            return error.toString().contains('401');
          },
          onAuthExpired: () async {
            refreshCallCount++;
            return 'new-token';
          },
        ),
        channelFactory: (_) => channels[factoryIdx++],
      );

      await client.connect();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(refreshCallCount, 1);
      expect(client.currentState, isA<WsConnected>());
      await client.dispose();
    });

    test('connect non-auth error → no refresh', () async {
      int refreshCallCount = 0;

      final failChannel = _FakeWsChannel();
      failChannel.failReady(
        WebSocketChannelException('HTTP status code: 404'),
      );

      final client = DefaultWsClient(
        WsClientConfig(
          url: Uri.parse('wss://test.invalid/x'),
          heartbeatInterval: Duration.zero,
          isConnectAuthError: (error) {
            return error.toString().contains('401');
          },
          onAuthExpired: () async {
            refreshCallCount++;
            return 'new-token';
          },
        ),
        channelFactory: (_) => failChannel,
      );

      await client.connect();
      await Future<void>.delayed(Duration.zero);

      expect(refreshCallCount, 0);
      // cancel pending reconnect timer before dispose
      await client.disconnect();
      await client.dispose();
    });
  });
}
