// ignore_for_file: deprecated_member_use
// 保留旧 element 模型，与 custom_lint_builder 0.7.x 一致。

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// 禁止在 Notifier / ViewModel 上声明 `static` 可变字段。
///
/// Riverpod 的 autoDispose / family / test override 都依赖"状态由 Notifier 实例
/// 独占"的不变式——static 字段会跨实例共享，出现：
/// * family key 切换后 page 仍读到旧页数据；
/// * 测试 container 销毁后变量仍持有，下条测试读到脏数据；
/// * 热重载不清零。
///
/// ## 命中条件
///
/// 同时满足：
/// 1. 类是 VM / Notifier（extends 或 with 任一）：
///    - `ViewModelNotifier` / `FamilyViewModelNotifier`
///    - `AsyncViewModelNotifier` / `FamilyAsyncViewModelNotifier`
///    - `Notifier` / `AsyncNotifier` / 它们的 auto-dispose / family 变体
/// 2. 字段声明是 `static`；
/// 3. 字段**不是** `const` 也**不是** `final`（即可变）。
///
/// 可变 `static` 字段中，唯一豁免的是 `static const` 和 `static final` ——-
/// 它们是只读全局常量，不会产生跨实例污染。
class AvoidStaticMutableInNotifier extends DartLintRule {
  const AvoidStaticMutableInNotifier() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_static_mutable_in_notifier',
    problemMessage:
        'Notifier / ViewModel 禁止声明可变的 static 字段。'
        'static 会跨实例共享，导致 family key 切换、测试隔离、热重载全部失效。',
    correctionMessage:
        '把状态搬进 state 对象；常量请改用 `static const` 或 `static final`。',
  );

  static const _notifierSupertypes = {
    'ViewModelNotifier',
    'FamilyViewModelNotifier',
    'AsyncViewModelNotifier',
    'FamilyAsyncViewModelNotifier',
    'Notifier',
    'AsyncNotifier',
    'AutoDisposeNotifier',
    'AutoDisposeAsyncNotifier',
    'FamilyNotifier',
    'FamilyAsyncNotifier',
    'AutoDisposeFamilyNotifier',
    'AutoDisposeFamilyAsyncNotifier',
    'StreamNotifier',
    'AutoDisposeStreamNotifier',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName.replaceAll('\\', '/');
    if (_isExempt(path)) return;

    context.registry.addFieldDeclaration((node) {
      if (!node.isStatic) return;

      final keyword = node.fields.keyword?.keyword;
      if (keyword != null &&
          (keyword.lexeme == 'const' || keyword.lexeme == 'final')) {
        return;
      }

      final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
      final element = classDecl?.declaredElement;
      if (element == null) return;
      if (!_isNotifier(element)) return;

      for (final variable in node.fields.variables) {
        reporter.atNode(variable, _code);
      }
    });
  }

  bool _isNotifier(ClassElement element) {
    final names = <String>{
      ...element.allSupertypes.map((t) => t.element.name),
      ...element.mixins.map((t) => t.element.name),
    };
    return names.any(_notifierSupertypes.contains);
  }

  bool _isExempt(String path) {
    return path.contains('/test/') ||
        path.contains('/test_fixtures/') ||
        path.contains('/example/');
  }
}