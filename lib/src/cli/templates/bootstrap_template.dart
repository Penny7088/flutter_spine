import '../../../flutter_spine.dart';

/// `bootstrap` 命令：在新工程里一键生成 main.dart + router 骨架。
///
/// **不再生成 effect_handler.dart**——直接用 `MaterialDefaultEffectHandler`，
/// 业务有定制需求自己 new 一份覆盖即可。
///
/// 业务可在 main.dart 里继续配置 [FlutterSpineConfig]：
/// * `http: DioHttpConfig(...)` → 接入自家 baseUrl / interceptors
/// * `ws: (uri) => WsClientConfig(...)` → 接入自家 ws topic 协议
/// * `effectHandler: MaterialDefaultEffectHandler(toast: ...)` → 用自家 toast / dialog
const bootstrapMainTemplate = r'''
import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';

void main() {
  // 一行启动 flutter_spine——半包：本类只接管 ProviderScope + EffectListener，
  // MaterialApp 100% 由业务控制。
  FlutterSpine.runApp(
    config: const FlutterSpineConfig(
      // 想用自定义 toast / dialog？
      //   effectHandler: MaterialDefaultEffectHandler(
      //     toast: (ctx, msg, lvl) { BotToast.showText(text: msg); return true; },
      //     dialogs: { 'confirm': (ctx, args) => myConfirmDialog(ctx, args) },
      //   ),
      // 想接 HTTP？
      //   http: DioHttpConfig(
      //     baseUrl: 'https://api.example.com',
      //     interceptors: [AuthTokenInterceptor(tokenProvider: () => null)],
      //   ),
      // 想接 WebSocket（带 topic 路由）？
      //   ws: (uri) => WsClientConfig(
      //     url: uri,
      //     topicRouter: WsTopicRouter(
      //       topicExtractor: (msg) => (msg as Map)['topic'] as String?,
      //       subscribeFrameBuilder: (topic) => {'op': 'sub', 'topic': topic},
      //     ),
      //   ),
      // 想接 KV 存储？
      //   storage: () async => HiveStorage.fromBox(await Hive.openBox('prefs')),
    ),
    app: (ctx) => const _App(),
  );
}

class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: '{{Title}}',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      routerConfig: router,
    );
  }
}
''';

/// 已废弃——保留空字符串方便老代码不要硬崩。新工程不要再生成。
@Deprecated('用 MaterialDefaultEffectHandler 即可。如需定制，业务自己写一份。')
const bootstrapEffectHandlerTemplate = '';

const bootstrapRouterTemplate = r'''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // 业务路由：CLI `dart run flutter_spine:new feature xxx --with-route`
      // 会自动在这里追加 entry。
    ],
  );
});
''';
