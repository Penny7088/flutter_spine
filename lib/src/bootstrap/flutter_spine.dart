import 'package:flutter/widgets.dart' as flutter show runApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../flutter_spine.dart';

/// 一行启动 flutter_spine 应用——业务侧 main.dart 收敛到 ~15 行。
///
/// **半包**（明确的边界）：本类只接管：
/// * `WidgetsFlutterBinding.ensureInitialized()`
/// * `await config.storage()` 异步初始化
/// * 自动构造 [ProviderScope.overrides]（HTTP / WS / Storage / Logger / EffectHandler）
/// * 自动追加 default observers（[ErrorObserver] + DEBUG 下 [LogObserver]）
/// * 在 [app] 外面包一层 [EffectListener]（业务的 `MaterialApp` 在 listener 内）
/// * `kDebugMode` 下打印 [BootstrapAudit]
///
/// **不**接管：
/// * `MaterialApp` / theme / locale / routerConfig —— 业务 100% 控制
/// * 任何 UI 三方库（toast、dialog、router） —— 见 [MaterialDefaultEffectHandler]
///
/// ## 用法
///
/// ```dart
/// void main() {
///   FlutterSpine.runApp(
///     config: FlutterSpineConfig(
///       effectHandler: const MaterialDefaultEffectHandler(),
///       http: DioHttpConfig(baseUrl: 'https://api.example.com'),
///     ),
///     app: (ctx) => MaterialApp.router(
///       title: 'My App',
///       theme: ThemeData(useMaterial3: true),
///       routerConfig: router,
///     ),
///   );
/// }
/// ```
class FlutterSpine {
  FlutterSpine._();

  /// 启动入口。详见 [FlutterSpine] 类文档。
  static Future<void> runApp({
    FlutterSpineConfig config = const FlutterSpineConfig(),
    required Widget Function(BuildContext) app,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    final overrides = await _buildOverrides(config);
    final observers = _buildObservers(config);

    BootstrapAudit.printToConsole(config);

    // 用别名调用顶层 `runApp` —— 避免和本类静态方法 `FlutterSpine.runApp` 同名混淆。
    flutter.runApp(
      ProviderScope(
        overrides: overrides,
        observers: observers,
        child: Builder(
          builder: (ctx) => EffectListener(
            handleDefaults: false,
            onEffect: (_, __) {},
            child: app(ctx),
          ),
        ),
      ),
    );
  }

  // ── 内部辅助 ──────────────────────────────────────────────────────────────

  static Future<List<Override>> _buildOverrides(FlutterSpineConfig c) async {
    final overrides = <Override>[];

    overrides.add(defaultEffectHandlerProvider.overrideWithValue(c.effectHandler));

    if (c.http != null) {
      overrides.add(httpConfigProvider.overrideWithValue(c.http!));
    }

    if (c.ws != null) {
      overrides.add(wsConfigBuilderProvider.overrideWithValue(c.ws!));
    }

    if (c.storage != null) {
      final storage = await c.storage!();
      overrides.add(keyValueStorageProvider.overrideWithValue(storage));
    }

    if (c.logger != null) {
      overrides.add(appLoggerProvider.overrideWithValue(c.logger!));
    }

    overrides.addAll(c.extraOverrides);
    return overrides;
  }

  static List<ProviderObserver> _buildObservers(FlutterSpineConfig c) {
    final logger = c.logger ?? PrettyAppLogger();
    final list = <ProviderObserver>[];
    if (c.errorObserverEnabled) {
      list.add(ErrorObserver(logger: logger));
    }
    if (c.logObserverInDebug && _isDebugMode) {
      list.add(LogObserver(logger: logger));
    }
    list.addAll(c.extraObservers);
    return list;
  }

  static bool get _isDebugMode {
    var debug = false;
    assert(() {
      debug = true;
      return true;
    }());
    return debug;
  }
}
