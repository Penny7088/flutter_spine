import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class DemoWsPage extends ConsumerStatefulWidget {
  const DemoWsPage({super.key});

  @override
  ConsumerState<DemoWsPage> createState() => _DemoWsPageState();
}

class _DemoWsPageState extends ConsumerState<DemoWsPage> {
  WsClient? _client;
  _FakeWsChannel? _channel;
  StreamSubscription<WsConnectionState>? _stateSub;
  final _topicCtrl = TextEditingController();
  final _log = <_LogEntry>[];
  WsConnectionState _connState = const WsIdle();
  Timer? _simTimer;
  int _msgId = 0;

  @override
  void dispose() {
    _simTimer?.cancel();
    _stateSub?.cancel();
    _client?.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  // ── actions ───────────────────────────────────────────────────────────────

  void _connect() {
    final config = WsClientConfig(
      url: Uri.parse('wss://demo.local/ws'),
      heartbeatPayload: {'op': 'ping'},
      topicRouter: WsTopicRouter(
        topicExtractor: (raw) =>
            (jsonDecode(raw as String) as Map)['type'] as String?,
        subscribeFrameBuilder: (t) => {'op': 'subscribe', 'channel': t},
        unsubscribeFrameBuilder: (t) => {'op': 'unsubscribe', 'channel': t},
      ),
    );

    _channel = _FakeWsChannel();
    _channel!.completeReady();
    _client = DefaultWsClient(
      config,
      logger: ref.read(appLoggerProvider),
      channelFactory: (_) => _channel!,
    );

    _stateSub = _client!.connectionState.listen((s) {
      setState(() => _connState = s);
    });

    _client!.connect();
  }

  void _disconnect() {
    _simTimer?.cancel();
    _simTimer = null;
    _stateSub?.cancel();
    _client?.disconnect();
    setState(() {
      _connState = const WsDisconnected();
    });
  }

  void _subscribe(String topic) {
    if (topic.isEmpty || _client == null) return;
    _client!.subscribe<Map<String, dynamic>>(
      topic,
      decoder: (raw) => jsonDecode(raw as String) as Map<String, dynamic>,
    ).listen((msg) {
      _log.insert(0, _LogEntry(topic, msg['data'] as String? ?? msg.toString()));
      if (mounted) setState(() {});
    });
    _log.insert(0, _LogEntry(topic, '--- subscribed ---'));
    setState(() {});

    _simTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      _msgId++;
      for (final t in (_client?.subscribedTopics ?? <String>{})) {
        _channel?.receiveMessage(jsonEncode({
          'type': t,
          'data': 'msg #$_msgId at ${DateTime.now().toString().substring(11, 19)}',
        }));
      }
    });
  }

  void _unsubscribe(String topic) {
    _client?.unsubscribe(topic);
    _log.insert(0, _LogEntry(topic, '--- unsubscribed ---'));
    if (_client?.subscribedTopics.isEmpty ?? true) {
      _simTimer?.cancel();
      _simTimer = null;
    }
    setState(() {});
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscribed = _client?.subscribedTopics ?? <String>{};

    return AppPageScaffold(
      title: 'WebSocket Topic Demo',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── config code snippet ─────────────────────────────────────────────
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Config (in main.dart)',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    '''ws: (uri) => WsClientConfig(
  url: uri,
  topicRouter: WsTopicRouter(
    topicExtractor: (raw) =>
        (jsonDecode(raw as String) as Map)['type'] as String?,
    subscribeFrameBuilder: (t) =>
        {'op': 'subscribe', 'channel': t},
    unsubscribeFrameBuilder: (t) =>
        {'op': 'unsubscribe', 'channel': t},
  ),
),''',
                    style: theme.textTheme.bodySmall!.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── connection ──────────────────────────────────────────────────────
          _buildConnPanel(theme, subscribed),

          const SizedBox(height: 12),

          // ── topic controls ──────────────────────────────────────────────────
          if (_client != null && _connState is WsConnected) ...[
            _buildTopicControls(theme, subscribed),
            const SizedBox(height: 12),
          ],

          // ── message log ─────────────────────────────────────────────────────
          if (_log.isNotEmpty) ...[
            Text('Message Log', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final entry in _log.take(50))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _LogTile(entry),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnPanel(ThemeData theme, Set<String> subscribed) {
    final connected = _connState is WsConnected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _connState is WsConnected
                    ? Colors.green
                    : _connState is WsConnecting
                        ? Colors.orange
                        : Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'State: ${_connState.runtimeType.toString()}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (connected)
              FilledButton.tonal(
                onPressed: _disconnect,
                child: const Text('Disconnect'),
              )
            else
              FilledButton(
                onPressed: _connect,
                child: const Text('Connect'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicControls(ThemeData theme, Set<String> subscribed) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subscribe / Unsubscribe',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _topicCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Enter topic name...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      _subscribe(v.trim());
                      _topicCtrl.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    _subscribe(_topicCtrl.text.trim());
                    _topicCtrl.clear();
                  },
                  child: const Text('Subscribe'),
                ),
              ],
            ),
            if (subscribed.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Subscribed topics:',
                  style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: subscribed.map((t) {
                  return InputChip(
                    label: Text(t, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _unsubscribe(t),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── helper widgets ──────────────────────────────────────────────────────────

class _LogEntry {
  _LogEntry(this.topic, this.message);
  final String topic;
  final String message;
}

class _LogTile extends StatelessWidget {
  const _LogTile(this.entry);
  final _LogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(entry.topic,
                  style: const TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(entry.message,
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fake channel (same pattern as ws tests) ─────────────────────────────────

class _FakeWsChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  final _incoming = StreamController<dynamic>.broadcast();
  final _outgoing = StreamController<dynamic>();
  final _ready = Completer<void>();
  bool _closed = false;

  void completeReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void receiveMessage(dynamic msg) => _incoming.add(msg);

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
  Future get done => _parent._outgoing.stream.toList();
}
