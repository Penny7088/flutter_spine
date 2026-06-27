import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';

import 'app/router.dart';
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
      // 不传则 wsClientProvider 用"无 topicRouter + 默认参数"的 builder，
      // 业务层依然可以创建连接，但 subscribe/unsubscribe 不可用。
      // 开启 topic router 后，路由请看 DemoWsPage（/demos/ws）。
      // ws: (uri) => WsClientConfig(
      //   url: uri,
      //   heartbeatInterval: Duration(seconds: 30),
      //   maxReconnectAttempts: 10,
      //   topicRouter: WsTopicRouter(
      //     topicExtractor: (raw) =>
      //         (jsonDecode(raw as String) as Map)['type'] as String?,
      //     subscribeFrameBuilder: (t) => {'op': 'subscribe', 'channel': t},
      //     unsubscribeFrameBuilder: (t) => {'op': 'unsubscribe', 'channel': t},
      //   ),
      // ),

      // ── 6. Extra Observers ──────────────────────────────────────────────
      // 追加业务自定义 ProviderObserver（埋点 / 性能监控等）。
      // extraObservers: [AnalyticsObserver()],

      // ── 7. Extra Overrides ──────────────────────────────────────────────
      // 业务自定义 provider 覆写（如注入测试环境配置）。
      // extraOverrides: [
      //   appConfigProvider.overrideWithValue(AppConfig.dev()),
      // ],
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
