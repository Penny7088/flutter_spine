import 'package:flutter/material.dart';

import '../../effect/effect.dart';
import '../../effect/effect_listener.dart';
import '../appbar/app_default_appbar.dart';

/// 最常用的页面骨架。提供：
///
/// * 统一 AppBar（传 [appBar] 覆盖，传 [title]/[titleWidget] 走默认）
/// * `EffectListener` 接入（可按 [source] 过滤某个 VM）
/// * 点击空白处收起键盘（[dismissKeyboardOnTap]）
/// * SafeArea 包裹 body（[safeArea]）
/// * FAB / drawer / 底部栏等常见 Scaffold 槽位直通
///
/// **不做**：
///
/// * 不监听任何具体 VM 的 state——state 监听由 body 内部用 `Consumer` / `ref.watch`
///   自行完成，避免整页在任何一处 state 变化时整体重建；
/// * 不内置 loading / error / empty 态——那是 `AsyncPageStateView` 的职责。
///
/// ## 用法
///
/// ```dart
/// class OrderDetailPage extends ConsumerWidget {
///   @override
///   Widget build(BuildContext ctx, WidgetRef ref) {
///     return AppPageScaffold(
///       title: 'Order Detail',
///       source: OrderDetailVm,
///       body: Consumer(builder: (ctx, ref, _) {
///         final s = ref.watch(orderDetailVmProvider);
///         return _OrderBody(state: s);
///       }),
///     );
///   }
/// }
/// ```
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.appBar,
    this.actions,
    this.leading,
    this.onBack,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.safeArea = true,
    this.safeAreaTop = false,
    this.dismissKeyboardOnTap = true,
    this.source,
    this.onEffect,
    this.handleDefaultEffects = true,
  }) : assert(
          appBar == null || (title == null && titleWidget == null),
          '传了自定义 appBar 就不要再传 title/titleWidget，避免两个标题。',
        );

  // ── 内容 ───────────────────────────────────────────────────────────────
  final Widget body;

  // ── AppBar ─────────────────────────────────────────────────────────────
  final String? title;
  final Widget? titleWidget;

  /// 完全自定义 AppBar。传入后，[title] / [titleWidget] / [actions] / [leading] / [onBack] 都失效。
  final PreferredSizeWidget? appBar;

  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onBack;

  // ── Scaffold 槽位 ──────────────────────────────────────────────────────
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;

  /// 语义化别名：底部固定栏（单一 Widget），会作为 `bottomNavigationBar`。
  /// 与 [bottomNavigationBar] 互斥。
  final Widget? bottomBar;

  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  // ── 行为 ───────────────────────────────────────────────────────────────
  /// 是否用 SafeArea 包裹 body。默认 true。
  final bool safeArea;

  /// SafeArea 是否生效顶部（通常 false，避免和 AppBar 重复留白）。
  final bool safeAreaTop;

  /// 点击空白处收起键盘。默认 true。
  final bool dismissKeyboardOnTap;

  // ── Effect ─────────────────────────────────────────────────────────────
  /// 只监听指定 VM 类型发出的 effect。null = 监听全量。
  final Type? source;

  /// 业务 effect 回调。内置 effect 一般不需要这里处理（由 root handler 吃掉）。
  final void Function(BuildContext ctx, Effect effect)? onEffect;

  /// 是否先交给 `DefaultEffectHandler` 处理。默认 true。
  final bool handleDefaultEffects;

  @override
  Widget build(BuildContext context) {
    assert(
      !(bottomBar != null && bottomNavigationBar != null),
      'bottomBar 与 bottomNavigationBar 互斥，二选一',
    );

    final effectiveAppBar = appBar ?? _buildDefaultAppBar();

    Widget content = body;
    if (safeArea) {
      content = SafeArea(top: safeAreaTop, child: content);
    }

    final scaffold = Scaffold(
      appBar: effectiveAppBar,
      body: content,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomBar ?? bottomNavigationBar,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );

    final rooted = dismissKeyboardOnTap
        ? GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: scaffold,
          )
        : scaffold;

    return EffectListener(
      source: source,
      handleDefaults: handleDefaultEffects,
      onEffect: (ctx, e) => onEffect?.call(ctx, e),
      child: rooted,
    );
  }

  PreferredSizeWidget? _buildDefaultAppBar() {
    final hasAnyAppBarSlot = title != null ||
        titleWidget != null ||
        leading != null ||
        (actions != null && actions!.isNotEmpty);
    if (!hasAnyAppBarSlot) return null;
    return AppDefaultAppBar(
      title: title,
      titleWidget: titleWidget,
      leading: leading,
      actions: actions,
      onBack: onBack,
    );
  }
}
