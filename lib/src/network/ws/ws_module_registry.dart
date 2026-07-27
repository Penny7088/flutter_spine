import 'ws_client.dart';

/// 单个 WebSocket 业务模块的自描述配置。
///
/// 每个业务模块（Market / Asset / Swap 等）定义一个 `WsModuleConfig` 实例，
/// 包含该模块的 URI、topicRouter、auth 策略等。注册到 [WsModuleRegistry] 后，
/// [wsConfigBuilderProvider] 自动按 URI 分发配置，无需在 main.dart 中写 if-else 分支。
///
/// ## 用法
///
/// ```dart
/// // market_ws_config.dart
/// final marketWsModule = WsModuleConfig(
///   uri: Uri.parse('wss://market-api.example/feed'),
///   topicRouter: marketTopicRouter,
/// );
///
/// // main.dart
/// WsModuleRegistry.build(
///   modules: [marketWsModule, assetWsModule, swapWsModule],
///   defaultConfig: (uri) => WsClientConfig(url: uri, ...),
/// )
/// ```
class WsModuleConfig {
  const WsModuleConfig({
    required this.uri,
    this.topicRouter,
    this.headersProvider,
    this.queryParamsProvider,
    this.onAuthExpired,
    this.isAuthCloseCode,
    this.heartbeatPayload,
    this.heartbeatInterval,
  });

  /// 该模块的 WebSocket 服务端地址。
  final Uri uri;

  /// topic 路由配置。业务消息按此配置分发到对应的 [WsClient.subscribe] 子流。
  final WsTopicRouter? topicRouter;

  final Map<String, dynamic> Function()? headersProvider;
  final Map<String, String> Function()? queryParamsProvider;
  final Future<String?> Function()? onAuthExpired;
  final bool Function(int?)? isAuthCloseCode;
  final Object? heartbeatPayload;
  final Duration? heartbeatInterval;

  /// 转换为 [WsClientConfig]。
  WsClientConfig toConfig() {
    return WsClientConfig(
      url: uri,
      topicRouter: topicRouter,
      headersProvider: headersProvider,
      queryParamsProvider: queryParamsProvider,
      onAuthExpired: onAuthExpired,
      isAuthCloseCode: isAuthCloseCode,
      heartbeatPayload: heartbeatPayload,
      heartbeatInterval: heartbeatInterval ?? Duration.zero,
    );
  }

  /// 转换为配置并合并 [shared] 中的默认值。未在模块自身配置的字段使用 shared 的值。
  WsClientConfig toConfigWith(WsClientConfig Function(Uri uri) shared) {
    final sharedConfig = shared(uri);
    return WsClientConfig(
      url: uri,
      topicRouter: topicRouter ?? sharedConfig.topicRouter,
      headersProvider: headersProvider ?? sharedConfig.headersProvider,
      queryParamsProvider: queryParamsProvider ?? sharedConfig.queryParamsProvider,
      onAuthExpired: onAuthExpired ?? sharedConfig.onAuthExpired,
      isAuthCloseCode: isAuthCloseCode ?? sharedConfig.isAuthCloseCode,
      heartbeatPayload: heartbeatPayload ?? sharedConfig.heartbeatPayload,
      heartbeatInterval: heartbeatInterval ?? sharedConfig.heartbeatInterval,
    );
  }
}

/// WebSocket 模块注册表——URI → 配置的映射。
///
/// 替代在 [wsConfigBuilderProvider] override 中手写 if-else 链。
/// 各模块在自己的配置文件中定义 [WsModuleConfig] 实例，
/// 注册表中按 URI 分发，新增模块只需在列表中加一项。
///
/// ## 用法
///
/// ```dart
/// extraOverrides: [
///   wsConfigBuilderProvider.overrideWithValue(
///     WsModuleRegistry.build(
///       modules: [marketWsModule, assetWsModule, swapWsModule],
///       defaultConfig: (uri) => WsClientConfig(url: uri, ...),
///     ),
///   ),
/// ],
/// ```
class WsModuleRegistry {
  const WsModuleRegistry._();

  /// 从模块列表构建一个 [WsClientConfig] 工厂函数。
  ///
  /// 连接时按 [WsModuleConfig.uri] 匹配，命中则返回模块的配置
  /// （合并 [defaultConfig] 中的未覆盖字段），未命中返回 [defaultConfig]。
  static WsClientConfig Function(Uri uri) build({
    required List<WsModuleConfig> modules,
    required WsClientConfig Function(Uri uri) defaultConfig,
  }) {
    final map = <Uri, WsModuleConfig>{
      for (final m in modules) m.uri: m,
    };
    return (uri) {
      final module = map[uri];
      if (module != null) {
        return module.toConfigWith(defaultConfig);
      }
      return defaultConfig(uri);
    };
  }
}
