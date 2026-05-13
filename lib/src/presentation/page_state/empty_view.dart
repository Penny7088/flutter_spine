import 'package:flutter/material.dart';

/// 零图片依赖的默认空态视图。
///
/// 业务包通过传入 [icon]（如 SvgPicture）、[title]、[subtitle] 替换默认样式：
/// ```dart
/// EmptyView(
///   icon: SvgPicture.asset('images/common/data_empty.svg'),
///   title: AppLocalizations.of(context)!.noData,
/// )
/// ```
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.icon,
    this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
  });

  /// 自定义图标 / 插图。null 时显示内置 [Icons.inbox_outlined]。
  final Widget? icon;

  /// 主文案。
  final String? title;

  /// 副文案。
  final String? subtitle;

  /// 可选操作按钮（如"去发布"）。
  final Widget? action;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon ??
                Icon(
                  Icons.inbox_outlined,
                  size: 72,
                  color: colorScheme.outlineVariant,
                ),
            if (title != null) ...[
              const SizedBox(height: 12),
              Text(
                title!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
