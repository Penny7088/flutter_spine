import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';

import 'app/router.dart';
import 'features/demos/demo_asset_ws/asset_topic.dart';
import 'features/demos/demo_asset_ws/asset_topic_router.dart';
import 'features/demos/demo_market_ws/market_topic.dart';
import 'features/demos/demo_market_ws/market_topic_router.dart';
import 'features/demos/demo_swap_ws/swap_topic.dart';
import 'features/demos/demo_swap_ws/swap_topic_router.dart';
import 'storage/in_memory_storage.dart';

/// flutter_spine 启动入口 —— `FlutterSpine.runApp` 一行接管：
///
///   * `WidgetsFlutterBinding.ensureInitialized()`
///   * 异步初始化 storage（Hive / 其他）
///   * 自动构建 [ProviderScope.overrides]（HTTP / WS / Storage / Logger / EffectHandler）
///   * 自动追加 default observers（[ErrorObserver] + DEBUG 下 [LogObserver]）
///   * 在 MaterialApp 外面包一层 [EffectListener]
///   * kDebugMode 下打印 [BootstrapAudit] 接入清单
///
/// MaterialApp 的 theme / darkTheme / router / locale 等完全留给业务控制。

/// 共享的 WebSocket 配置工厂。
///
/// 所有业务模块共用相同的 auth / 心跳 / 重连策略，
/// 只需在各自的 [WsTopicRouter] 中定义不同的 topic 协议即可。
///
/// 如果有模块需要不同的策略（如某个模块不刷新 token），
/// 直接在该模块的 if 分支中写独立配置，不调本函数即可。
WsClientConfig _sharedWsConfig(Uri uri, {WsTopicRouter? topicRouter}) {
  return WsClientConfig(
    url: uri,
    topicRouter: topicRouter,
    heartbeatPayload: {'op': 'ping'},
    headersProvider: () => {'Authorization': 'Bearer demo-token-12345'},
    isAuthCloseCode: (code) => code == 4001,
    onAuthExpired: () async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return 'new-token-refreshed';
    },
  );
}

void main() {
  // =========================================================================
  // FlutterSpineConfig — 渐进式配置：字段全部可选，不配也能跑。
  //
  // 原则"从极简到全套"：
  //   1) 不传任何字段 → MaterialDefaultEffectHandler（自带 SnackBar / GoRouter /
  //      HapticFeedback），纯 UI 应用零额外配置。
  //   2) 配 logger    → 统一的 AppLogger（PrettyAppLogger debug 输出）。
  //   3) 配 storage   → 注入 KeyValueStorage 实现（HiveStorage / 自实现），
  //      themeModeProvider 等依赖 storage 的 provider 即可正常工作。
  //   4) 配 http      → 注入 DioHttpConfig，业务层 HttpClient 开箱即用。
  //   5) 配 ws        → 注入 WsClientConfig 工厂，业务层 WsClient 自动装配。
  // =========================================================================
  FlutterSpine.runApp(
    config: FlutterSpineConfig(
      // ── 1. EffectHandler（默认 MaterialDefaultEffectHandler）─────────────
      // 如果用默认，这行可以不传。这里显式写出以展示可配：
      effectHandler: const MaterialDefaultEffectHandler(),

      // ── 2. Logger ────────────────────────────────────────────────────────
      // 不传则用默认 PrettyAppLogger（info/debug/error 彩色输出到控制台）。
      // 可在此传入自定义 AppLogger 实现（如 写文件 + 上报远程）。
      logger: PrettyAppLogger(),

      // ── 3. Storage（KeyValueStorage）─────────────────────────────────────
      // 提供后：themeModeProvider 自动持久化主题选择；业务通过
      // ref.read(keyValueStorageProvider) 存取任意 KV。
      //
      // 这里用纯 Dart 的 InMemoryStorage 演示（页面刷新即重置）；
      // 生产环境替换为 HiveStorage：
      //
      //   storage: () async {
      //     await Hive.initFlutter();
      //     final box = await Hive.openBox('app_prefs');
      //     return HiveStorage.fromBox(box);
      //   },
      storage: () => InMemoryStorage(),

      // ── 4. HTTP（DioHttpConfig）──────────────────────────────────────────
      // 仅当业务需要走网络时才配。配完后业务层通过以下方式使用：
      //
      //   final client = ref.read(httpClientProvider);
      //   final resp = await client.get<MyData>('/api/items', decoder: ...);
      //
      // http: DioHttpConfig(
      //   baseUrl: 'https://api.example.com',
      //   connectTimeout: const Duration(seconds: 10),
      //   receiveTimeout: const Duration(seconds: 15),
      //   interceptors: [
      //     HttpLoggingInterceptor(),               // 请求/响应日志
      //     EnvelopeUnwrapInterceptor(              // 后端统一信封解包
      //       codeKey: 'code',
      //       messageKey: 'message',
      //       dataKey: 'data',
      //     ),
      //   ],
      //   retry: RetryConfig(                        // 指数退避重试
      //     maxRetries: 3,
      //     baseDelay: Duration(seconds: 1),
      //   ),
      //   authRefresh: AuthRefreshConfig(            // 401 自动刷新 token
      //     refreshToken: () => _refreshToken(),
      //   ),
      // ),

      // ── 5. WebSocket ────────────────────────────────────────────────────
      // `ws` 提供全局默认的 WsClientConfig 工厂，所有 wsClientProvider(uri)
      // 都从这里取基础配置。
      //
      // 各业务模块（Market / Asset / Swap 等）如需专用配置（topicRouter、
      // headersProvider、onAuthExpired 等），通过下面的 extraOverrides
      // 按 URI 覆盖 wsConfigBuilderProvider 即可。
      ws: (uri) => WsClientConfig(
        url: uri,
        heartbeatPayload: {'op': 'ping'},
      ),

      // ── 6. Extra Overrides ──────────────────────────────────────────────
      extraOverrides: [
        // 按 URI 为不同业务模块注入其专属的 topicRouter。
        // 共享的 auth / 心跳 / 重连策略由 _sharedWsConfig 统一管理，
        // 每个模块只需指定自己的 WsTopicRouter 即可。
        wsConfigBuilderProvider.overrideWithValue((uri) {
          if (uri == marketWsUri) {
            return _sharedWsConfig(uri, topicRouter: marketTopicRouter);
          }
          if (uri == assetWsUri) {
            return _sharedWsConfig(uri, topicRouter: assetTopicRouter);
          }
          if (uri == swapWsUri) {
            return _sharedWsConfig(uri, topicRouter: swapTopicRouter);
          }
          return WsClientConfig(
            url: uri,
            heartbeatPayload: {'op': 'ping'},
          );
        }),
      ],
    ),

    // ── MaterialApp ─────────────────────────────────────────────────────────
    // FlutterSpine.runApp 不接管 MaterialApp——theme / darkTheme /
    // themeMode / locale / routerConfig 等 100% 由业务控制。
    app: (ctx) => MaterialApp.router(
      title: 'flutter_spine demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      routerConfig: buildRouter(),
    ),
  );
}
