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
    this.isConnectAuthError,
    this.protocols,
    this.connectTimeout,
    this.baseReconnectDelay,
    this.maxReconnectDelay,
    this.maxReconnectAttempts,
    this.reconnectJitterRatio,
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
  final bool Function(Object error)? isConnectAuthError;
  final Iterable<String>? protocols;
  final Duration? connectTimeout;
  final Duration? baseReconnectDelay;
  final Duration? maxReconnectDelay;
  final int? maxReconnectAttempts;
  final double? reconnectJitterRatio;
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
      isConnectAuthError: isConnectAuthError,
      protocols: protocols,
      connectTimeout: connectTimeout ?? const Duration(seconds: 10),
      baseReconnectDelay: baseReconnectDelay ?? const Duration(seconds: 1),
      maxReconnectDelay: maxReconnectDelay ?? const Duration(seconds: 30),
      maxReconnectAttempts: maxReconnectAttempts ?? -1,
      reconnectJitterRatio: reconnectJitterRatio ?? 0.2,
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
      isConnectAuthError: isConnectAuthError ?? sharedConfig.isConnectAuthError,
      protocols: protocols ?? sharedConfig.protocols,
      connectTimeout: connectTimeout ?? sharedConfig.connectTimeout,
      baseReconnectDelay: baseReconnectDelay ?? sharedConfig.baseReconnectDelay,
      maxReconnectDelay: maxReconnectDelay ?? sharedConfig.maxReconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? sharedConfig.maxReconnectAttempts,
      reconnectJitterRatio: reconnectJitterRatio ?? sharedConfig.reconnectJitterRatio,
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
