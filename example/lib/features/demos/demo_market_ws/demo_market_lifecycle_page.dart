import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'market_stream_providers.dart';
import 'market_topic_router.dart';
import 'market_ws_gateway.dart';
import 'market_ws_providers.dart';

class DemoMarketLifecyclePage extends ConsumerStatefulWidget {
  const DemoMarketLifecyclePage({super.key});

  @override
  ConsumerState<DemoMarketLifecyclePage> createState() =>
      _DemoMarketLifecyclePageState();
}

class _DemoMarketLifecyclePageState
    extends ConsumerState<DemoMarketLifecyclePage> {
  final _logs = <_LifecycleLog>[];
  (String, String, String)? _selected; // (chain, addr, symbol)
  _FakeClient? _fakeClient;

  void _log(String event, String detail) {
    _logs.insert(
      0,
      _LifecycleLog(DateTime.now().toString().substring(11, 22), event, detail),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {

    return ProviderScope(
      overrides: [
        marketGatewayProvider.overrideWith((ref) {
          if (_fakeClient == null) {
            _fakeClient = _FakeClient();
            _fakeClient!._logFn = _log;
          }
          return MarketWsGateway(_fakeClient!.client);
        }),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(_selected == null
              ? 'WS Lifecycle Demo'
              : '${_selected!.$3} Detail'),
          leading: _selected != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _selected = null),
                )
              : null,
          actions: [
            if (_fakeClient != null)
              _ActiveCountBadge(
                count: _fakeClient!.client.subscribedTopics.length,
              ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _selected == null
                  ? _buildListPage()
                  : _buildDetailPage(_selected!.$1, _selected!.$2),
            ),
            _LifecycleLogView(logs: _logs),
          ],
        ),
      ),
    );
  }

  Widget _buildListPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader('Tokens — tap to enter detail'),
        const SizedBox(height: 8),
        _TokenTile('BTC', 'eip155:1', 'native',
            onTap: () => setState(() => _selected = ('eip155:1', 'native', 'BTC'))),
        _TokenTile('ETH', 'eip155:1', '0xeth',
            onTap: () => setState(() => _selected = ('eip155:1', '0xeth', 'ETH'))),
        _TokenTile('USDC', 'eip155:1', '0xusdc',
            onTap: () => setState(() => _selected = ('eip155:1', '0xusdc', 'USDC'))),
        const SizedBox(height: 24),
        const _SectionHeader('How it works'),
        const SizedBox(height: 8),
        const _InfoCard(
          '1. Tap a token above to show its detail page (inline, no Navigator.push)\n\n'
          '2. The detail page watches StreamProvider.autoDispose.family\n'
          '    → subscribePrice is called → WsClient refCount +1\n\n'
          '3. Press the ← back arrow\n'
          '    → detail widget is removed from tree\n'
          '    → StreamProvider autoDispose fires immediately\n'
          '    → ref.onDispose calls unsubscribePrice\n'
          '    → WsClient refCount -1 → if 0, sends unsubscribe frame\n\n'
          '4. The bottom log shows each subscribe/unsubscribe event.\n'
          '5. The app bar badge shows active topic count in real time.',
        ),
        const SizedBox(height: 8),
        // 同时 watch 两个 token 验证引用计数
        _SectionHeader('Cross-page ref counting'),
        const SizedBox(height: 8),
        const _InfoCard(
          'This section watches BTC price from the LIST page.\n'
          'When you enter BTC detail, both the list and detail\n'
          'watch the same topic → refCount = 2.\n'
          'When you leave detail → refCount drops to 1\n'
          '(the list page still watches).\n'
          'Check the badge: it should show 1, not 0.',
        ),
        const SizedBox(height: 8),
        // 列表页面也 watch BTC
        _SharedWatcher(
          chain: 'eip155:1',
          addr: 'native',
          symbol: 'BTC (list page)',
        ),
      ],
    );
  }

  Widget _buildDetailPage(String chain, String addr) {
    final params = (chain, addr);
    final priceAsync = ref.watch(priceStreamProvider(params));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Chain: $chain', style: _monoStyle(context)),
        Text('Address: $addr', style: _monoStyle(context)),
        const SizedBox(height: 24),
        Text('Live Price', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        priceAsync.when(
          data: (price) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _PriceColumn(
                      'Price', '\$${price.price.toStringAsFixed(2)}'),
                  _PriceColumn(
                      '24h', '${price.change24h.toStringAsFixed(2)}%'),
                ],
              ),
            ),
          ),
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Press ← to go back.\nThis widget will be removed from tree,\n'
          'autoDispose will fire, unsubscribePrice will be called.\n'
          'Watch the log at the bottom and the badge in the app bar.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  static TextStyle _monoStyle(BuildContext context) => TextStyle(
        fontSize: 12,
        fontFamily: 'monospace',
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
}

class _ActiveCountBadge extends StatelessWidget {
  const _ActiveCountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('topics: $count', style: const TextStyle(fontSize: 11)),
    );
  }
}

class _SharedWatcher extends ConsumerWidget {
  const _SharedWatcher({
    required this.chain,
    required this.addr,
    required this.symbol,
  });

  final String chain;
  final String addr;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceAsync = ref.watch(priceStreamProvider((chain, addr)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            priceAsync.when(
              data: (p) => Text('\$${p.price.toStringAsFixed(2)}',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              loading: () => const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, _) => const Text('-', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── fake client ──────────────────────────────────────────────────────────────

class _FakeClient {
  late final DefaultWsClient client;
  late final _LifecycleFakeChannel channel;
  void Function(String event, String detail)? _logFn;

  _FakeClient() {
    final config = WsClientConfig(
      url: Uri.parse('wss://market-api.example/feed'),
      topicRouter: marketTopicRouter,
      heartbeatPayload: {'op': 'ping'},
    );
    channel = _LifecycleFakeChannel();
    channel.completeReady();
    client = DefaultWsClient(config, channelFactory: (_) => channel);

    // 拦截 subscribe/unsubscribe 帧
    channel.sentMessages.listen((msg) {
      try {
        final m = jsonDecode(msg as String) as Map<String, dynamic>;
        final op = m['op'] as String? ?? '';
        final ch = m['channel'] as String? ?? '';
        final token = m['tokenContractAddress'] as String? ?? '';
        _logFn?.call(op, 'channel=$ch token=$token');
      } catch (_) {}
    });

    client.connect();

    // 周期性模拟价格推送
    final random = Random();
    Timer.periodic(const Duration(seconds: 1), (_) {
      _simPrice(channel, random, 'native', 'BTC/USD', 50000, 1000);
      _simPrice(channel, random, '0xeth', 'ETH/USD', 3000, 100);
      _simPrice(channel, random, '0xusdc', 'USDC/USD', 1.0, 0.01);
    });
  }

  static void _simPrice(_LifecycleFakeChannel ch, Random r,
      String addr, String symbol, double base, double noise) {
    ch.receiveMessage(jsonEncode({
      'channel': 'price-info',
      'chainCaip2': 'eip155:1',
      'tokenContractAddress': addr,
      'symbol': symbol,
      'price': base + r.nextDouble() * noise,
      'change24h': r.nextDouble() * 10 - 5,
    }));
  }
}

// ── widgets ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600));
  }
}

class _TokenTile extends StatelessWidget {
  const _TokenTile(this.symbol, this.chain, this.addr, {required this.onTap});
  final String symbol;
  final String chain;
  final String addr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(symbol[0])),
        title: Text('$symbol/USD'),
        subtitle: Text('$chain ⋅ $addr', style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _PriceColumn extends StatelessWidget {
  const _PriceColumn(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label,
          style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      Text(value,
          style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

// ── lifecycle log ────────────────────────────────────────────────────────────

class _LifecycleLogView extends StatelessWidget {
  const _LifecycleLogView({required this.logs});
  final List<_LifecycleLog> logs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Row(
              children: [
                Text('Lifecycle Log',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                _Tag('subscribe', cs.primary),
                const SizedBox(width: 4),
                _Tag('unsubscribe', Colors.orange),
              ],
            ),
          ),
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text('Tap a token to begin',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)))
                : ListView.builder(
                    itemCount: logs.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (_, i) {
                      final e = logs[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          children: [
                            Text(e.time,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: cs.onSurfaceVariant)),
                            const SizedBox(width: 8),
                            _Tag(
                              e.event,
                              e.event == 'subscribe'
                                  ? cs.primary
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(e.detail,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: cs.onSurface),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _LifecycleLog {
  final String time;
  final String event;
  final String detail;
  const _LifecycleLog(this.time, this.event, this.detail);
}

// ── fake channel ─────────────────────────────────────────────────────────────

class _LifecycleFakeChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _LifecycleFakeChannel();

  final _incoming = StreamController<dynamic>.broadcast();
  final _outgoing = StreamController<dynamic>();
  final _ready = Completer<void>();
  int? _closeCode;
  String? _closeReason;

  void completeReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void receiveMessage(dynamic msg) => _incoming.add(msg);

  Stream<dynamic> get sentMessages => _outgoing.stream;

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _LifecycleFakeSink(this);

  @override
  String? get protocol => null;
  @override
  int? get closeCode => _closeCode;
  @override
  String? get closeReason => _closeReason;
}

class _LifecycleFakeSink implements WebSocketSink {
  _LifecycleFakeSink(this._parent);
  final _LifecycleFakeChannel _parent;

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
