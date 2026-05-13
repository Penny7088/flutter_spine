import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../effect/default_effect_handler.dart';
import '../effect/material_default_effect_handler.dart';
import '../logging/app_logger.dart';
import '../network/http/dio_http_client.dart';
import '../network/ws/ws_client.dart';
import '../storage/key_value_storage.dart';

/// `FlutterSpine.runApp` 的配置容器。所有字段都是**渐进式**——
/// 从"只填 effectHandler"到"全套接入"业务想配多少配多少。
///
/// ```dart
/// // 极简：直接跑
/// const FlutterSpineConfig()
///
/// // 业务配 HTTP
/// FlutterSpineConfig(
///   http: DioHttpConfig(baseUrl: 'https://api.example.com'),
/// )
///
/// // 业务全套
/// FlutterSpineConfig(
///   effectHandler: MaterialDefaultEffectHandler(toast: ...),
///   http: DioHttpConfig(baseUrl: ..., interceptors: [...]),
///   ws: (uri) => WsClientConfig(url: uri, topicRouter: ...),
///   storage: () async => HiveStorage.fromBox(await Hive.openBox('prefs')),
///   logger: PrettyAppLogger(),
///   extraObservers: [MyAnalyticsObserver()],
///   extraOverrides: [myAppConfigProvider.overrideWithValue(...)],
/// )
/// ```
class FlutterSpineConfig {
  const FlutterSpineConfig({
    this.effectHandler = const MaterialDefaultEffectHandler(),
    this.http,
    this.ws,
    this.storage,
    this.logger,
    this.extraObservers = const [],
    this.extraOverrides = const [],
    this.errorObserverEnabled = true,
    this.logObserverInDebug = true,
  });

  /// 内置 effect 的处理器。**默认 [MaterialDefaultEffectHandler]**——
  /// 业务零配也能弹 SnackBar / 走 GoRouter。
  ///
  /// 想完全自定义传自家 `class XxxHandler extends DefaultEffectHandler`；
  /// 想关掉默认 toast/路由 处理传 [NoopDefaultEffectHandler]。
  final DefaultEffectHandler effectHandler;

  /// HTTP 配置。`null` → `httpClientProvider` 在被 read 时抛错（懒失败）。
  /// 业务确定本 app 不用 HTTP 可以放空。
  final DioHttpConfig? http;

  /// WS 配置工厂。`null` → 用 flutter_spine 自带的"无 router / 默认参数" builder。
  final WsClientConfig Function(Uri url)? ws;

  /// 异步初始化的 KV 存储（Hive 等通常需要 `await openBox`）。
  /// 类型是 `FutureOr` —— 同步 / 异步都接受。
  /// `null` → `keyValueStorageProvider` 在被 read 时抛错。
  final FutureOr<KeyValueStorage> Function()? storage;

  /// 自定义 logger；`null` → `appLoggerProvider` 用默认的 `PrettyAppLogger`。
  final AppLogger? logger;

  /// 业务自定义 observers（埋点 / 性能监控等），追加在默认 observers 后面。
  final List<ProviderObserver> extraObservers;

  /// 业务自定义 overrides，**追加在 flutter_spine 默认 overrides 之后**——
  /// 同名 provider 业务的覆盖会胜出。
  final List<Override> extraOverrides;

  /// 是否注入默认 [ErrorObserver]（捕异步错误打日志）。默认 true。
  final bool errorObserverEnabled;

  /// `kDebugMode` 下是否注入 [LogObserver]。默认 true（release 自动跳过）。
  final bool logObserverInDebug;
}
