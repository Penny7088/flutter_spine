import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 统一的默认 AppBar。
///
/// `AppPageScaffold` 在未传自定义 appBar 时会用它兜底。
/// 业务可以直接用，也可以在项目里封装二级主题化版本。
///
/// ## 用法
///
/// ```dart
/// AppDefaultAppBar(
///   title: 'Orders',
///   actions: [IconButton(icon: Icon(Icons.search), onPressed: ...)],
/// )
/// ```
///
/// 自定义返回行为：
///
/// ```dart
/// AppDefaultAppBar(
///   title: 'Edit',
///   onBack: () => _confirmDiscardThenPop(),
/// )
/// ```
///
/// 用 Widget 作为标题：
///
/// ```dart
/// AppDefaultAppBar(titleWidget: _LogoTitle())
/// ```
class AppDefaultAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppDefaultAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.onBack,
    this.centerTitle,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.bottom,
    this.systemOverlayStyle,
  }) : assert(
          title == null || titleWidget == null,
          'title 与 titleWidget 不能同时传，二选一',
        );

  /// 文字标题。与 [titleWidget] 互斥。
  final String? title;

  /// Widget 标题（例如 Logo / Tab）。与 [title] 互斥。
  final Widget? titleWidget;

  /// 自定义 leading。null 时，若能 `pop` 则展示默认返回键。
  final Widget? leading;

  final List<Widget>? actions;

  /// 返回按钮回调。传入后会替换默认返回逻辑（例如做"未保存确认"）。
  final VoidCallback? onBack;

  final bool? centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;

  final PreferredSizeWidget? bottom;

  final SystemUiOverlayStyle? systemOverlayStyle;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final effectiveLeading = leading ??
        (onBack != null
            ? IconButton(
                icon: const BackButtonIcon(),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
              )
            : null);

    return AppBar(
      title: titleWidget ?? (title != null ? Text(title!) : null),
      leading: effectiveLeading,
      actions: actions,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      bottom: bottom,
      systemOverlayStyle: systemOverlayStyle,
    );
  }
}
