import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';

import 'app/router.dart';
import 'data/ws_modules.dart';
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
      //     // 可选：使用内置拦截器或自行实现 Dio Interceptor
      //     HttpLoggingInterceptor(logger: PrettyAppLogger()),
      //     EnvelopeUnwrapInterceptor(
      //       codeKey: 'code',
      //       messageKey: 'message',
      //       dataKey: 'data',
      //     ),
      //   ],
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
        heartbeatPayload: {'type': 'ping'},
      ),

      // ── 6. Extra Overrides ──────────────────────────────────────────────
      extraOverrides: [
        // 使用 WsModuleRegistry 替代 if-else 分支。
        // 各模块的 topicRouter 通过 wsModules 列表注入，
        // 共享的 auth / 心跳 / 重连策略由 sharedWsConfig 统一提供。
        wsConfigBuilderProvider.overrideWithValue(
          WsModuleRegistry.build(
            modules: wsModules,
            defaultConfig: sharedWsConfig,
          ),
        ),
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
