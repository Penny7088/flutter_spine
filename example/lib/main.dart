import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';

import 'app/router.dart';

void main() {
  // 一行启动——半包：FlutterSpine 包 ProviderScope + EffectListener，
  // MaterialApp 留给业务 100% 控制。
  FlutterSpine.runApp(
    config: const FlutterSpineConfig(
      // 不传任何字段也能跑——effectHandler 默认 MaterialDefaultEffectHandler，
      // 自动用 SnackBar / GoRouter / HapticFeedback 处理所有内置 effect。
    ),
    app: (ctx) => MaterialApp.router(
      title: 'flutter_spine demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      routerConfig: buildRouter(),
    ),
  );
}
