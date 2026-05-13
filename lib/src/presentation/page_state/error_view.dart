import 'package:flutter/material.dart';

import '../../error/app_exception.dart';

/// 零图片依赖的默认错误 + 重试视图。
///
/// 业务包替换插图：
/// ```dart
/// ErrorView(
///   icon: SvgPicture.asset('images/wallet_trade/failed_widget_icon.svg', width: 180),
///   retryText: AppLocalizations.of(context)!.reconnect,
///   onRetry: retry,
/// )
/// ```
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.error,
    this.onRetry,
    this.icon,
    this.title,
    this.retryText,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
  });

  /// 原始错误对象，用于提取 message。
  final Object? error;
  final VoidCallback? onRetry;

  /// 自定义插图。null 时显示内置 [Icons.wifi_off_rounded]。
  final Widget? icon;

  /// 主文案。null 时从 [error] 自动提取。
  final String? title;

  /// 重试按钮文案。
  final String? retryText;

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
                  Icons.wifi_off_rounded,
                  size: 72,
                  color: colorScheme.outlineVariant,
                ),
            const SizedBox(height: 12),
            Text(
              title ?? _extractMessage(error),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(retryText ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _extractMessage(Object? e) {
    if (e == null) return 'Something went wrong';
    if (e is AppException) return e.displayMessage;
    return e.toString();
  }
}

/// 加载更多失败时贴在列表底部的紧凑提示条。
class MoreErrorBar extends StatelessWidget {
  const MoreErrorBar({
    super.key,
    required this.error,
    required this.onRetry,
    this.retryText,
  });

  final Object error;
  final VoidCallback onRetry;
  final String? retryText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 16, color: colorScheme.error),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              ErrorView._extractMessage(error),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.error),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              retryText ?? 'Retry',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
