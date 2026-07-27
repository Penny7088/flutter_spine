import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spine/flutter_spine.dart';

import 'market_topic.dart';
import 'market_ws_gateway.dart';
import 'market_ws_providers.dart';

class DemoMarketWsPage extends ConsumerStatefulWidget {
  const DemoMarketWsPage({super.key});

  @override
  ConsumerState<DemoMarketWsPage> createState() => _DemoMarketWsPageState();
}

class _DemoMarketWsPageState extends ConsumerState<DemoMarketWsPage> {
  StreamSubscription<WsConnectionState>? _stateSub;

  final _log = <_LogEntry>[];
  WsConnectionState _connState = const WsIdle();

  final _chainCtrl = TextEditingController(text: 'eip155:1');
  final _addrCtrl = TextEditingController(text: 'native');

  bool _priceOn = false;
  bool _candleOn = false;
  bool _tradesOn = false;
  String _candleInterval = '4H';

  MarketWsGateway get _gw => ref.read(marketGatewayProvider);

  @override
  void initState() {
    super.initState();
    _stateSub = _gw.connectionState.listen((s) {
      setState(() => _connState = s);
    });
    _gw.connect();
    _logMsg('system', 'Connecting to $marketWsUri ...');
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    if (_priceOn) _unsubPrice();
    if (_candleOn) _unsubCandle();
    if (_tradesOn) _unsubTrades();
    _chainCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  String get _chain => _chainCtrl.text.trim();
  String get _addr => _addrCtrl.text.trim();

  // ── subscription ──────────────────────────────────────────────────────────

  void _togglePrice() {
    if (_priceOn) {
      _unsubPrice();
    } else {
      _gw.subscribePrice(_chain, _addr).listen((msg) {
        _logMsg('price', msg.toString());
        if (mounted) setState(() {});
      });
      _logMsg('system',
          'Subscribed: ${MarketTopic('price-info', _chain, _addr).encode()}');
    }
    setState(() => _priceOn = !_priceOn);
  }

  void _unsubPrice() {
    _gw.unsubscribePrice(_chain, _addr);
    _logMsg('system',
        'Unsubscribed: ${MarketTopic('price-info', _chain, _addr).encode()}');
  }

  void _toggleCandle() {
    if (_candleOn) {
      _unsubCandle();
    } else {
      _gw.subscribeCandle(_chain, _addr, _candleInterval).listen((msg) {
        _logMsg('candle', msg.toString());
        if (mounted) setState(() {});
      });
      _logMsg('system',
          'Subscribed: ${MarketTopic('candle$_candleInterval', _chain, _addr).encode()}');
    }
    setState(() => _candleOn = !_candleOn);
  }

  void _unsubCandle() {
    _gw.unsubscribeCandle(_chain, _addr, _candleInterval);
    _logMsg('system',
        'Unsubscribed: ${MarketTopic('candle$_candleInterval', _chain, _addr).encode()}');
  }

  void _toggleTrades() {
    if (_tradesOn) {
      _unsubTrades();
    } else {
      _gw.subscribeTrades(_chain, _addr).listen((msg) {
        _logMsg('trades', msg.toString());
        if (mounted) setState(() {});
      });
      _logMsg('system',
          'Subscribed: ${MarketTopic('trades', _chain, _addr).encode()}');
    }
    setState(() => _tradesOn = !_tradesOn);
  }

  void _unsubTrades() {
    _gw.unsubscribeTrades(_chain, _addr);
    _logMsg('system',
        'Unsubscribed: ${MarketTopic('trades', _chain, _addr).encode()}');
  }

  void _logMsg(String topic, String content) {
    _log.insert(0, _LogEntry(topic, content));
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
          _buildConnectionCard(cs),
          const SizedBox(height: 12),
          _buildSubscriptionCard(cs),
          const SizedBox(height: 12),
          _buildLogCard(cs),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(ColorScheme cs) {
    final connected = _connState is WsConnected;
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
                    onPressed: connected ? null : () => _gw.connect(),
                    icon: const Icon(Icons.wifi, size: 18),
                    label: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: connected ? () => _gw.disconnect() : null,
                    icon: const Icon(Icons.wifi_off, size: 18),
                    label: const Text('Disconnect'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: cs.errorContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'State: $_connStateLabel',
              style: TextStyle(
                  color: _connStateColor(cs), fontWeight: FontWeight.w600),
            ),
            if (_connState is WsReconnecting) ...[
              const SizedBox(height: 4),
              Text(
                'Retry #${(_connState as WsReconnecting).attempt}, '
                'next in ${(_connState as WsReconnecting).nextDelay.inMilliseconds}ms',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'URI: $marketWsUri',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(ColorScheme cs) {
    final connected = _connState is WsConnected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subscription',
                style: Theme.of(context).textTheme.titleSmall),
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
                if (_candleOn)
                  DropdownButton<String>(
                    value: _candleInterval,
                    items: ['1H', '4H', '1D']
                        .map((v) => DropdownMenuItem(
                            value: v, child: Text('K$v')))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      _unsubCandle();
                      setState(() => _candleInterval = v);
                      _gw.subscribeCandle(_chain, _addr, v).listen((msg) {
                        _logMsg('candle', msg.toString());
                        if (mounted) setState(() {});
                      });
                      setState(() => _candleOn = true);
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

  Widget _buildLogCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Message Log',
                    style: Theme.of(context).textTheme.titleSmall),
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
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 13),
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
