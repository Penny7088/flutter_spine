import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'market_topic.dart';
import 'market_topic_router.dart';
import 'market_ws_gateway.dart';

class DemoMarketWsPage extends ConsumerStatefulWidget {
  const DemoMarketWsPage({super.key});

  @override
  ConsumerState<DemoMarketWsPage> createState() => _DemoMarketWsPageState();
}

class _DemoMarketWsPageState extends ConsumerState<DemoMarketWsPage> {
  MarketWsGateway? _gw;
  DefaultWsClient? _client;
  _FakeWsChannel? _channel;
  StreamSubscription<WsConnectionState>? _stateSub;
  Timer? _simTimer;

  final _log = <_LogEntry>[];
  WsConnectionState _connState = const WsIdle();
  final _random = Random();

  final _chainCtrl = TextEditingController(text: 'eip155:1');
  final _addrCtrl = TextEditingController(text: 'native');

  bool _priceOn = false;
  bool _candleOn = false;
  bool _tradesOn = false;
  String _candleInterval = '4H';
  String _currentToken = 'demo-token-12345';

  @override
  void dispose() {
    _simTimer?.cancel();
    _stateSub?.cancel();
    _client?.dispose();
    _chainCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  String get _chain => _chainCtrl.text.trim();
  String get _addr => _addrCtrl.text.trim();

  // ── connection ─────────────────────────────────────────────────────────────

  void _connect() {
    final config = WsClientConfig(
      url: Uri.parse('wss://market-api.example/feed'),
      topicRouter: marketTopicRouter,
      heartbeatPayload: {'op': 'ping'},
      headersProvider: () =>
          {'Authorization': 'Bearer $_currentToken'},
      isAuthCloseCode: (code) => code == 4001,
      onAuthExpired: () async {
        _logMsg('system', 'onAuthExpired triggered — refreshing token...');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        _currentToken = 'new-token-${_random.nextInt(99999).toString().padLeft(5, '0')}';
        _logMsg('system', 'token refreshed: $_currentToken');
        return _currentToken;
      },
    );

    _channel = _FakeWsChannel();
    _channel!.completeReady();
    _client = DefaultWsClient(
      config,
      logger: ref.read(appLoggerProvider),
      channelFactory: (_) => _channel!,
    );
    _gw = MarketWsGateway(_client!);

    _stateSub = _client!.connectionState.listen((s) {
      setState(() => _connState = s);
    });

    _client!.connect();
    setState(() {});
  }

  void _disconnect() {
    _simTimer?.cancel();
    _simTimer = null;
    _stateSub?.cancel();
    _stateSub = null;

    // 先退订所有
    if (_priceOn) _unsubPrice();
    if (_candleOn) _unsubCandle();
    if (_tradesOn) _unsubTrades();

    _client?.disconnect();
    _gw = null;
    _client = null;
    _channel = null;
    setState(() {});
  }

  // ── subscription ──────────────────────────────────────────────────────────

  void _togglePrice() {
    if (_priceOn) {
      _unsubPrice();
    } else {
      _gw!.subscribePrice(_chain, _addr).listen((msg) {
        _logMsg('price', msg.toString());
        if (mounted) setState(() {});
      });
      _logMsg('system', 'Subscribed: ${MarketTopic('price-info', _chain, _addr).encode()}');
    }
    setState(() => _priceOn = !_priceOn);
    _restartSim();
  }

  void _unsubPrice() {
    _gw?.unsubscribePrice(_chain, _addr);
    _logMsg('system', 'Unsubscribed: ${MarketTopic('price-info', _chain, _addr).encode()}');
  }

  void _toggleCandle() {
    if (_candleOn) {
      _unsubCandle();
    } else {
      _gw!.subscribeCandle(_chain, _addr, _candleInterval).listen((msg) {
        _logMsg('candle', msg.toString());
        if (mounted) setState(() {});
      });
      _logMsg('system',
          'Subscribed: ${MarketTopic('candle$_candleInterval', _chain, _addr).encode()}');
    }
    setState(() => _candleOn = !_candleOn);
    _restartSim();
  }

  void _unsubCandle() {
    _gw?.unsubscribeCandle(_chain, _addr, _candleInterval);
    _logMsg('system',
        'Unsubscribed: ${MarketTopic('candle$_candleInterval', _chain, _addr).encode()}');
  }

  void _toggleTrades() {
    if (_tradesOn) {
      _unsubTrades();
    } else {
      _gw!.subscribeTrades(_chain, _addr).listen((msg) {
        _logMsg('trades', msg.toString());
        if (mounted) setState(() {});
      });
      _logMsg('system', 'Subscribed: ${MarketTopic('trades', _chain, _addr).encode()}');
    }
    setState(() => _tradesOn = !_tradesOn);
    _restartSim();
  }

  void _unsubTrades() {
    _gw?.unsubscribeTrades(_chain, _addr);
    _logMsg('system', 'Unsubscribed: ${MarketTopic('trades', _chain, _addr).encode()}');
  }

  void _restartSim() {
    _simTimer?.cancel();
    _simTimer = null;
    if (!_priceOn && !_candleOn && !_tradesOn) return;

    _simTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_priceOn) {
        _simulateMsg('price-info', {
          'symbol': 'BTC/USD',
          'price': 50000 + _random.nextDouble() * 1000,
          'change24h': _random.nextDouble() * 10 - 5,
        });
      }
      if (_candleOn) {
        _simulateMsg('candle$_candleInterval', {
          'symbol': 'BTC/USD',
          'interval': _candleInterval,
          'open': 50000.0,
          'high': 51000.0,
          'low': 49000.0,
          'close': 50500.0,
        });
      }
      if (_tradesOn) {
        _simulateMsg('trades', {
          'symbol': 'BTC/USD',
          'price': 50250 + _random.nextDouble() * 100,
          'amount': _random.nextDouble() * 2,
          'side': _random.nextBool() ? 'buy' : 'sell',
        });
      }
    });
  }

  void _simulateMsg(String channel, Map<String, dynamic> data) {
    final base = {
      'channel': channel,
      'chainCaip2': _chain,
      'tokenContractAddress': _addr,
      ...data,
    };
    _channel?.receiveMessage(jsonEncode(base));
  }

  void _logMsg(String topic, String content) {
    _log.insert(0, _LogEntry(topic, content));
  }

  // ── simulate events ────────────────────────────────────────────────────────

  void _simulateAuthExpiry() {
    _logMsg('system', 'Simulating auth expiry (close code 4001)...');
    _channel?.simulateRemoteClose(code: 4001);
    setState(() {});
  }

  void _simulateNormalClose() {
    _logMsg('system', 'Simulating normal close (close code 1000)...');
    _channel?.simulateRemoteClose(code: 1000);
    setState(() {});
  }

  void _simulateNetworkDisconnect() {
    _logMsg('system', 'Simulating network disconnect (close code 1006)...');
    _channel?.simulateRemoteClose(code: 1006);
    setState(() {});
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market WebSocket Gateway'),
        actions: [
          Icon(_connStateIcon, color: _connStateColor(cs), size: 20),
          const SizedBox(width: 8),
          Text(
            _connStateLabel,
            style: TextStyle(fontSize: 12, color: _connStateColor(cs)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── connection ──────────────────────
          _buildConnectionCard(cs),
          const SizedBox(height: 12),

          // ── subscription ────────────────────
          _buildSubscriptionCard(cs),
          const SizedBox(height: 12),

          // ── simulate events ─────────────────
          _buildSimulateCard(cs),
          const SizedBox(height: 12),

          // ── message log ─────────────────────
          _buildLogCard(cs),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(ColorScheme cs) {
    final connected = _client != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connection', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: connected ? null : _connect,
                    icon: const Icon(Icons.wifi, size: 18),
                    label: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: connected ? _disconnect : null,
                    icon: const Icon(Icons.wifi_off, size: 18),
                    label: const Text('Disconnect'),
                    style: ElevatedButton.styleFrom(backgroundColor: cs.errorContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'State: $_connStateLabel',
              style: TextStyle(color: _connStateColor(cs), fontWeight: FontWeight.w600),
            ),
            if (_connState is WsReconnecting) ...[
              const SizedBox(height: 4),
              Text(
                'Retry #${(_connState as WsReconnecting).attempt}, '
                'next in ${(_connState as WsReconnecting).nextDelay.inMilliseconds}ms',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
            if (connected) ...[
              const SizedBox(height: 4),
              Text(
                'Token: $_currentToken',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontFamily: 'monospace'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(ColorScheme cs) {
    final connected = _client != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subscription', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _chainCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Chain (Caip2)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _addrCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Token Address',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // K 线间隔选择
                if (_candleOn)
                  DropdownButton<String>(
                    value: _candleInterval,
                    items: ['1H', '4H', '1D']
                        .map((v) => DropdownMenuItem(value: v, child: Text('K$v')))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      _unsubCandle();
                      setState(() => _candleInterval = v);
                      // 重新订阅新间隔
                      _gw!.subscribeCandle(_chain, _addr, v).listen((msg) {
                        _logMsg('candle', msg.toString());
                        if (mounted) setState(() {});
                      });
                      setState(() => _candleOn = true);
                      _restartSim();
                    },
                    style: TextStyle(color: cs.onSurface, fontSize: 13),
                    underline: const SizedBox(),
                  ),
                const Spacer(),
                _SubToggle(
                  label: 'Price',
                  active: _priceOn,
                  enabled: connected,
                  onTap: _togglePrice,
                ),
                const SizedBox(width: 8),
                _SubToggle(
                  label: 'K-line',
                  active: _candleOn,
                  enabled: connected,
                  onTap: _toggleCandle,
                ),
                const SizedBox(width: 8),
                _SubToggle(
                  label: 'Trades',
                  active: _tradesOn,
                  enabled: connected,
                  onTap: _toggleTrades,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulateCard(ColorScheme cs) {
    final connected = _client != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Simulate Events', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.key_off, size: 16),
                  label: const Text('Auth Expiry (4001)'),
                  onPressed: connected ? _simulateAuthExpiry : null,
                ),
                ActionChip(
                  avatar: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Normal Close (1000)'),
                  onPressed: connected ? _simulateNormalClose : null,
                ),
                ActionChip(
                  avatar: const Icon(Icons.cloud_off, size: 16),
                  label: const Text('Disconnect (1006)'),
                  onPressed: connected ? _simulateNetworkDisconnect : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Message Log', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => setState(() => _log.clear()),
                  tooltip: 'Clear',
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 280,
              child: _log.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _log.length,
                      itemBuilder: (_, i) {
                        final e = _log[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: e.topic == 'system'
                                      ? cs.primaryContainer
                                      : cs.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  e.topic,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                    color: e.topic == 'system'
                                        ? cs.onPrimaryContainer
                                        : cs.onTertiaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.content,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Color _connStateColor(ColorScheme cs) => switch (_connState) {
        WsIdle() => cs.onSurfaceVariant,
        WsConnecting() => Colors.orange,
        WsConnected() => Colors.green,
        WsReconnecting() => Colors.orange,
        WsDisconnected() => cs.error,
        WsFailed() => cs.error,
      };

  String get _connStateLabel => switch (_connState) {
        WsIdle() => 'Idle',
        WsConnecting() => 'Connecting',
        WsConnected() => 'Connected',
        WsReconnecting() => 'Reconnecting',
        WsDisconnected() => 'Disconnected',
        WsFailed() => 'Failed',
      };

  IconData get _connStateIcon => switch (_connState) {
        WsIdle() => Icons.radio_button_unchecked,
        WsConnecting() => Icons.sync,
        WsConnected() => Icons.check_circle,
        WsReconnecting() => Icons.loop,
        WsDisconnected() => Icons.cancel,
        WsFailed() => Icons.error,
      };
}

// ── widgets ──────────────────────────────────────────────────────────────────

class _SubToggle extends StatelessWidget {
  const _SubToggle({
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: active,
      onSelected: enabled ? (_) => onTap() : null,
      selectedColor: cs.primaryContainer,
      checkmarkColor: cs.primary,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _LogEntry {
  final String topic;
  final String content;
  const _LogEntry(this.topic, this.content);
}

// ── fake channel (same pattern as demo_ws_page.dart) ────────────────────────

class _FakeWsChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeWsChannel();

  final _incoming = StreamController<dynamic>.broadcast();
  final _outgoing = StreamController<dynamic>();
  final _ready = Completer<void>();
  int? _closeCode;
  String? _closeReason;

  void completeReady() {
    if (!_ready.isCompleted) _ready.complete();
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
    if (!_parent._incoming.isClosed) await _parent._incoming.close();
    if (!_parent._outgoing.isClosed) await _parent._outgoing.close();
  }

  @override
  Future<void> get done => _parent._outgoing.done;
}
