// ignore_for_file: deprecated_member_use
// 保留旧 element 模型，与 custom_lint_builder 0.7.x 一致。

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// 禁止业务代码直接调用 Hive 静态 API：
///
/// * `Hive.box(...)`
/// * `Hive.openBox(...)`
/// * `Hive.openLazyBox(...)`
/// * `Hive.registerAdapter(...)`
/// * `Hive.initFlutter(...)` / `Hive.init(...)`（除了启动初始化）
/// * `HiveBoxes.xxx`（常见的单例盒子门面，如存在）
///
/// 要求改用 `KeyValueStorage` 抽象——这样：
/// * 测试里可 override 为内存实现；
/// * 业务不感知 Hive / SharedPreferences / Secure Storage 的差异；
/// * 按 `KeyNamespace` 管理 key 前缀，避免跨模块冲突。
///
/// ## 豁免
///
/// * `flutter_spine` 自身的存储实现（`package/flutter_spine/lib/src/storage/**`）
/// * 应用启动代码（`/main.dart` / `lib/bootstrap.dart`）——调 `Hive.initFlutter` 无可替代
/// * 测试 / example 路径
class AvoidDirectHiveAccess extends DartLintRule {
  const AvoidDirectHiveAccess() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_direct_hive_access',
    problemMessage:
        '业务代码请使用 KeyValueStorage，不要直接调 Hive 静态 API。',
    correctionMessage:
        '注入 `KeyValueStorage`（或从 Riverpod provider 读取），'
        '通过 `read` / `write` / `delete` 访问。',
  );

  static const _hiveUri = 'package:hive/';
  static const _hiveFlutterUri = 'package:hive_flutter/';

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName.replaceAll('\\', '/');
    if (_isExempt(path)) return;

    context.registry.addMethodInvocation((node) {
      final target = node.realTarget;
      if (target == null) return;

      final name = switch (target) {
        Identifier() => target.name,
        _ => null,
      };
      if (name != 'Hive') return;

      final uri = _libraryUri(_resolveElement(target));
      if (!_isHiveLib(uri)) return;

      reporter.atNode(node, _code);
    });

    context.registry.addPrefixedIdentifier((node) {
      if (node.prefix.name != 'Hive') return;

      final uri = _libraryUri(node.prefix.staticElement);
      if (!_isHiveLib(uri)) return;

      reporter.atNode(node, _code);
    });
  }

  Element? _resolveElement(dynamic node) {
    if (node is SimpleIdentifier) return node.staticElement;
    if (node is PrefixedIdentifier) return node.staticElement;
    return null;
  }

  String _libraryUri(Element? element) {
    return element?.librarySource?.uri.toString() ?? '';
  }

  bool _isHiveLib(String uri) =>
      uri.startsWith(_hiveUri) || uri.startsWith(_hiveFlutterUri);

  bool _isExempt(String path) {
    return path.contains('/package/flutter_spine/lib/src/storage/') ||
        path.endsWith('/lib/main.dart') ||
        path.endsWith('/lib/bootstrap.dart') ||
        path.contains('/test/') ||
        path.contains('/test_fixtures/') ||
        path.contains('/example/');
  }
}