import 'package:flutter/material.dart';

import '../../effect/effect.dart';
import '../../effect/effect_listener.dart';

/// 半屏 BottomSheet 的内容骨架。
///
/// 自身**不调用** `showModalBottomSheet`——那是业务决策（动画、barrier 颜色、是否可拖拽）。
/// 本类只规范化 bottomSheet 的内容结构：
///
/// ```
/// ┌────────────────────────┐
/// │       drag handle       │  ← 可关
/// ├────────────────────────┤
/// │  title       [close ✕]  │  ← 可关
/// ├────────────────────────┤
/// │                         │
/// │        body (滚动)      │
/// │                         │
/// └────────────────────────┘
/// ```
///
/// ## 用法
///
/// ```dart
/// showModalBottomSheet(
///   context: ctx,
///   isScrollControlled: true,  // 想全高/键盘自适应就传 true
///   builder: (_) => AppBottomSheetScaffold(
///     title: 'Select Payment',
///     source: PaymentPickerVm,
///     body: _PaymentList(),
///   ),
/// );
/// ```
class AppBottomSheetScaffold extends StatelessWidget {
  const AppBottomSheetScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.showDragHandle = true,
    this.showCloseButton = false,
    this.onClose,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.scrollable = true,
    this.scrollController,
    this.backgroundColor,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(16)),
    this.heightFactor,
    this.source,
    this.onEffect,
    this.handleDefaultEffects = false,
  }) : assert(
          title == null || titleWidget == null,
          'title 与 titleWidget 不能同时传',
        );

  // ── 内容 ───────────────────────────────────────────────────────────────
  final Widget body;

  // ── 头部 ───────────────────────────────────────────────────────────────
  final String? title;
  final Widget? titleWidget;

  /// 标题栏右侧的 actions。
  final List<Widget>? actions;

  final bool showDragHandle;

  /// 标题栏右侧是否展示 "✕" 关闭按钮。默认 false（现代交互靠手势/点外部关闭）。
  final bool showCloseButton;

  /// 关闭回调；未传时点击 ✕ 走 `Navigator.maybePop`。
  final VoidCallback? onClose;

  // ── 布局 ───────────────────────────────────────────────────────────────
  final EdgeInsetsGeometry padding;
  final bool scrollable;
  final ScrollController? scrollController;

  final Color? backgroundColor;
  final BorderRadiusGeometry borderRadius;

  /// 高度占屏幕高度的比例。null = 按内容自适应（并受 showModalBottomSheet 的约束）。
  final double? heightFactor;

  // ── Effect ─────────────────────────────────────────────────────────────
  final Type? source;
  final void Function(BuildContext ctx, Effect effect)? onEffect;
  final bool handleDefaultEffects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final hasHeader = title != null ||
        titleWidget != null ||
        showCloseButton ||
        (actions != null && actions!.isNotEmpty);

    Widget content = body;
    if (scrollable) {
      content = SingleChildScrollView(
        controller: scrollController,
        child: content,
      );
    }

    Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDragHandle) _DragHandle(theme: theme),
        if (hasHeader) _Header(
          title: title,
          titleWidget: titleWidget,
          actions: actions,
          showCloseButton: showCloseButton,
          onClose: onClose,
        ),
        Flexible(
          child: Padding(padding: padding, child: content),
        ),
      ],
    );

    if (heightFactor != null) {
      column = FractionallySizedBox(heightFactor: heightFactor, child: column);
    }

    final sheet = Material(
      color: backgroundColor ?? theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(top: false, child: column),
      ),
    );

    return EffectListener(
      source: source,
      handleDefaults: handleDefaultEffects,
      onEffect: (ctx, e) => onEffect?.call(ctx, e),
      child: sheet,
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurfaceVariant.withAlpha(102),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.titleWidget,
    required this.actions,
    required this.showCloseButton,
    required this.onClose,
  });

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showCloseButton;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.titleMedium,
              child: titleWidget ??
                  (title != null ? Text(title!) : const SizedBox.shrink()),
            ),
          ),
          if (actions != null) ...actions!,
          if (showCloseButton)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose ?? () => Navigator.maybePop(context),
            ),
        ],
      ),
    );
  }
}
