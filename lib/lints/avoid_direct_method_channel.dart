// ignore_for_file: deprecated_member_use
// 保留旧 element 模型，与 custom_lint_builder 0.7.x 一致。

import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// 禁止业务代码直接实例化 `MethodChannel` 或 `EventChannel`。
///
/// 原因：
/// * 没有统一的错误语义（`PlatformException` → `AppException` 转换缺失）；
/// * 没有 channel 名称注册中心，容易 typo；
/// * 测试时无法按 method 粒度 mock，只能全局 `setMockMethodCallHandler`；
/// * VM 直接触达原生层，违反分层——应该经 DataSource → Repository。
///
/// 要求改用 `ChannelClient`（flutter_spine/network），或在此之上做一层
/// 业务 ApiClient 封装；ViewModel 只调 Repository。
///
/// ## 豁免
///
/// * flutter_spine 的 `ChannelClient` 实现本身：`package/flutter_spine/lib/src/network/**`
/// * 测试 / fixture / example 路径
/// * 应用启动代码 `/lib/main.dart` / `lib/bootstrap.dart`
class AvoidDirectMethodChannel extends DartLintRule {
  const AvoidDirectMethodChannel() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_direct_method_channel',
    problemMessage:
        '业务代码请使用 ChannelClient 而不是直接 new MethodChannel/EventChannel。',
    correctionMessage:
        '在 DataSource 层注入 `ChannelClient`，VM / Repository 不触碰原生 API。',
  );

  static const _bannedTypes = {'MethodChannel', 'EventChannel'};
  static const _servicesUri = 'package:flutter/src/services/';

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName.replaceAll('\\', '/');
    if (_isExempt(path)) return;

    context.registry.addInstanceCreationExpression((node) {
      final type = node.staticType;
      if (type == null) return;
      final element = type.element;
      if (element == null) return;
      if (!_bannedTypes.contains(element.name)) return;

      final uri = element.library?.source.uri.toString() ?? '';
      if (!uri.startsWith(_servicesUri)) return;

      reporter.atNode(node, _code);
    });
  }

  bool _isExempt(String path) {
    return path.contains('/package/flutter_spine/lib/src/network/') ||
        path.endsWith('/lib/main.dart') ||
        path.endsWith('/lib/bootstrap.dart') ||
        path.contains('/test/') ||
        path.contains('/test_fixtures/') ||
        path.contains('/example/');
  }
}