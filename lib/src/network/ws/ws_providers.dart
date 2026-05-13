import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logging/logger_impl.dart';
import 'default_ws_client.dart';
import 'ws_client.dart';

/// 业务 host 必须 override 此 provider，给定一份 [WsClientConfig] 工厂——
/// 由 [Uri] 计算出该 URI 对应的配置（不同业务流可能用不同心跳间隔 / 协议）。
///
/// ## 用法
///
/// ```dart
/// runApp(ProviderScope(
///   overrides: [
///     wsConfigBuilderProvider.overrideWithValue(
///       (uri) => WsClientConfig(
///         url: uri,
///         heartbeatInterval: const Duration(seconds: 25),
///         heartbeatPayload: {'op': 'ping'},
///         maxReconnectAttempts: -1,
///       ),
///     ),
///   ],
///   child: const App(),
/// ));
/// ```
final wsConfigBuilderProvider = Provider<WsClientConfig Function(Uri url)>((_) {
  return (uri) => WsClientConfig(url: uri);
});

/// 按 [Uri] 取一个共享的 [WsClient] 实例（同一个 URI 复用同一个连接）。
///
/// 自动 keepAlive；ProviderScope 卸载时 `dispose()` 关闭连接。
///
/// ## 用法
///
/// ```dart
/// // 在 VM / Repository 里
/// final ws = ref.watch(wsClientProvider(Uri.parse('wss://api/x/feed')));
/// ws.connect();
/// ws.messages.listen(_onMessage);
/// ```
final wsClientProvider =
    Provider.family<WsClient, Uri>((ref, uri) {
  final config = ref.watch(wsConfigBuilderProvider)(uri);
  // logger 是可选的——业务没注入就传 null。
  final logger = ref.read(appLoggerProvider);
  final client = DefaultWsClient(config, logger: logger);
  ref.onDispose(client.dispose);
  return client;
});
