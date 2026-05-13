import 'package:flutter/material.dart';

import '../../effect/effect.dart';
import 'app_page_scaffold.dart';

/// 表单页骨架：可滚动表单 + 底部固定提交栏（自动避让键盘）。
///
/// 解决常见痛点：
///
/// * 键盘弹出时底部按钮会被盖住 —— 本类把提交栏放在 `bottomNavigationBar`，
///   由 Scaffold 自动随键盘上顶；
/// * 表单内容过长超出屏幕 —— 本类默认用 `SingleChildScrollView` 托住 body；
/// * 按钮紧贴屏幕边 —— 内置 SafeArea + padding。
///
/// body 本身不需要再套 scroll；如果你确定不需要滚动，传 `scrollable: false`。
///
/// ## 用法
///
/// ```dart
/// AppFormPageScaffold(
///   title: 'Edit Profile',
///   source: EditProfileVm,
///   bottomAction: Consumer(builder: (ctx, ref, _) {
///     final busy = ref.watch(editProfileVmProvider.select((s) => s.isSubmitting));
///     return FilledButton(
///       onPressed: busy ? null : () => ref.read(editProfileVmProvider.notifier).submit(),
///       child: Text(busy ? 'Saving…' : 'Save'),
///     );
///   }),
///   body: _ProfileForm(),
/// )
/// ```
class AppFormPageScaffold extends StatelessWidget {
  const AppFormPageScaffold({
    super.key,
    required this.body,
    required this.bottomAction,
    this.bodyPadding = const EdgeInsets.all(16),
    this.bottomActionPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.scrollable = true,
    this.scrollController,
    this.scrollPhysics,
    this.title,
    this.titleWidget,
    this.appBar,
    this.actions,
    this.leading,
    this.onBack,
    this.backgroundColor,
    this.bottomActionDecoration,
    this.dismissKeyboardOnTap = true,
    this.source,
    this.onEffect,
    this.handleDefaultEffects = true,
  });

  // ── 内容 ───────────────────────────────────────────────────────────────
  final Widget body;

  /// 底部固定的提交栏（按钮 / 按钮组 / 协议勾选等），通常是 `FilledButton` 或 `Row`。
  final Widget bottomAction;

  /// body 的 padding。默认 `all(16)`。不滚动时也生效。
  final EdgeInsetsGeometry bodyPadding;

  /// [bottomAction] 的 padding。默认 `horizontal:16, vertical:12`。
  final EdgeInsetsGeometry bottomActionPadding;

  /// body 是否用 `SingleChildScrollView` 托住。默认 true。
  final bool scrollable;

  final ScrollController? scrollController;
  final ScrollPhysics? scrollPhysics;

  // ── AppBar ─────────────────────────────────────────────────────────────
  final String? title;
  final Widget? titleWidget;
  final PreferredSizeWidget? appBar;
  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onBack;

  // ── 样式 ───────────────────────────────────────────────────────────────
  final Color? backgroundColor;

  /// 底部栏的背景装饰（比如加个顶部分隔线 + 色）。null 时无额外装饰。
  final Decoration? bottomActionDecoration;

  final bool dismissKeyboardOnTap;

  // ── Effect ─────────────────────────────────────────────────────────────
  final Type? source;
  final void Function(BuildContext ctx, Effect effect)? onEffect;
  final bool handleDefaultEffects;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: bodyPadding, child: body);
    if (scrollable) {
      content = SingleChildScrollView(
        controller: scrollController,
        physics: scrollPhysics,
        child: content,
      );
    }

    final bottom = Material(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        decoration: bottomActionDecoration,
        child: SafeArea(
          top: false,
          child: Padding(padding: bottomActionPadding, child: bottomAction),
        ),
      ),
    );

    return AppPageScaffold(
      title: title,
      titleWidget: titleWidget,
      appBar: appBar,
      actions: actions,
      leading: leading,
      onBack: onBack,
      backgroundColor: backgroundColor,
      bottomNavigationBar: bottom,
      safeArea: true,
      dismissKeyboardOnTap: dismissKeyboardOnTap,
      source: source,
      onEffect: onEffect,
      handleDefaultEffects: handleDefaultEffects,
      body: content,
    );
  }
}
