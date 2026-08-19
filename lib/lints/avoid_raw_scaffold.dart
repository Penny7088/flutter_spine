// ignore_for_file: deprecated_member_use
// custom_lint_builder 0.7.x 仍基于 analyzer 旧 element 模型；
// analyzer 7 已标记 .element / .library / .staticElement 废弃，但迁移到 ClassElement2
// 需要 custom_lint_builder 同步升级，目前保持 0.7 API。

import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// 禁止业务页面直接使用 `Scaffold(...)`；必须用 flutter_spine 提供的
/// `AppPageScaffold` / `AppFormPageScaffold` /
/// `AppBottomSheetScaffold` / `AppRawPage` 之一。
///
/// 这样所有页面自动获得：统一 AppBar、SafeArea、键盘收起、Effect 分发、
/// 以及与 MVVM 基类的默认联动。
///
/// ## 豁免
///
/// 这些位置允许裸 `Scaffold`：
/// * `flutter_spine` 自身的 scaffold 实现：`package/flutter_spine/lib/src/ui/scaffold/**`
/// * 测试 fixture：路径含 `/test/` 或 `/test_fixtures/`
/// * 文档 / 示例：路径含 `/example/`
class AvoidRawScaffold extends DartLintRule {
  const AvoidRawScaffold() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_raw_scaffold',
    problemMessage:
        '业务页面请使用 AppPageScaffold / '
        'AppFormPageScaffold / AppBottomSheetScaffold / '
        'AppRawPage 之一，而不是裸 Scaffold。',
    correctionMessage:
        '改用 AppPageScaffold(title: ..., body: ...) 可自动获得 '
        'AppBar / SafeArea / 键盘收起 / Effect 分发。',
  );

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
      if (element.name != 'Scaffold') return;

      final uri = element.library?.source.uri.toString() ?? '';
      if (!uri.startsWith('package:flutter/')) return;

      reporter.atNode(node, _code);
    });
  }

  bool _isExempt(String path) {
    return path.contains('/package/flutter_spine/lib/') ||
        path.contains('/test/') ||
        path.contains('/test_fixtures/') ||
        path.contains('/example/');
  }
}