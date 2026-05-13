// ignore_for_file: deprecated_member_use
// 保留旧 element 模型，与 custom_lint_builder 0.7.x 一致；等上游升级再迁移。

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// 禁止在 ViewModel 代码里直接调用 UI 层 API（`Navigator` / `ScaffoldMessenger`
/// / `showDialog` / `showModalBottomSheet` 等）。
///
/// 正确做法：VM `emit(EffectNavigate(...))` / `emit(EffectPop(...))` /
/// `emit(EffectShowDialog(...))`，由 UI 侧的 `EffectListener` 或 `DefaultEffectHandler`
/// 翻译为具体的导航 / 弹窗 / 提示。
///
/// ## 命中条件
///
/// 同时满足：
/// 1. 代码位于一个类内部；
/// 2. 该类或它的祖先（含 mixin）是以下之一：
///    - `ViewModelNotifier` / `FamilyViewModelNotifier`
///    - `AsyncViewModelNotifier` / `FamilyAsyncViewModelNotifier`
///    - `PagedNotifierMixin` / `PagedNotifierMixinNoArg`
/// 3. 出现以下调用：
///    - `Navigator.xxx(...)`（任何静态/工厂方法）
///    - `ScaffoldMessenger.xxx(...)`
///    - 顶层函数：`showDialog` / `showModalBottomSheet` / `showBottomSheet` /
///      `showGeneralDialog` / `showMenu` / `showDatePicker` / `showTimePicker` /
///      `showAboutDialog`
class NoUiInViewModel extends DartLintRule {
  const NoUiInViewModel() : super(code: _code);

  static const _code = LintCode(
    name: 'no_ui_in_viewmodel',
    problemMessage:
        'ViewModel 不应直接调用 UI 层 API（Navigator / ScaffoldMessenger / '
        'showDialog 等）。改为 `emit(EffectNavigate(...))` 等 effect，'
        '让 DefaultEffectHandler / EffectListener 翻译到具体实现。',
  );

  static const _viewModelSupertypes = {
    'ViewModelNotifier',
    'FamilyViewModelNotifier',
    'AsyncViewModelNotifier',
    'FamilyAsyncViewModelNotifier',
    'PagedNotifierMixin',
    'PagedNotifierMixinNoArg',
  };

  static const _bannedReceivers = {
    'Navigator',
    'ScaffoldMessenger',
  };

  static const _bannedTopLevel = {
    'showDialog',
    'showModalBottomSheet',
    'showBottomSheet',
    'showGeneralDialog',
    'showMenu',
    'showDatePicker',
    'showTimePicker',
    'showAboutDialog',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
      final element = classDecl?.declaredElement;
      if (element == null) return;
      if (!_isViewModel(element)) return;

      final methodName = node.methodName.name;
      final target = node.realTarget;

      if (target == null) {
        if (!_bannedTopLevel.contains(methodName)) return;
        if (!_isFlutterSdk(node.methodName.staticElement)) return;
        reporter.atNode(node, _code);
        return;
      }

      if (target is Identifier) {
        final receiverName = target.name;
        if (!_bannedReceivers.contains(receiverName)) return;
        if (!_isFlutterSdk(target.staticElement)) return;
        reporter.atNode(node, _code);
      }
    });
  }

  bool _isViewModel(ClassElement element) {
    final names = <String>{
      ...element.allSupertypes.map((t) => t.element.name),
      ...element.mixins.map((t) => t.element.name),
    };
    return names.any(_viewModelSupertypes.contains);
  }

  bool _isFlutterSdk(Element? element) {
    final uri = element?.librarySource?.uri.toString() ?? '';
    return uri.startsWith('package:flutter/');
  }
}