import 'package:flutter/material.dart';

import '../../../flutter_spine.dart';

/// 骨架屏基础色块。不依赖 shimmer 包，业务层可自行包一层动画。
///
/// 业务包用 shimmer 包裹示例（在 flutter_wallet 中）：
/// ```dart
/// Shimmer.fromColors(
///   baseColor: const Color(0xFFE8E8E8),
///   highlightColor: const Color(0xFFF5F5F5),
///   child: SkeletonList(),
/// )
/// ```
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 4,
    this.color,
  });

  final double? width;
  final double height;
  final double borderRadius;

  /// null 时根据深色/浅色主题自动选色。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ??
            (isDark
                ? const Color(0xFF2E2E2E)
                : const Color(0xFFE8E8E8)),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// 水平一行骨架，[widths] 指定每段宽度。
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({
    super.key,
    this.widths = const [80, 120],
    this.height = 14,
    this.spacing = 8,
  });

  final List<double> widths;
  final double height;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < widths.length; i++) ...[
          SkeletonBox(width: widths[i], height: height),
          if (i < widths.length - 1) SizedBox(width: spacing),
        ],
      ],
    );
  }
}

/// 单张卡片骨架（模拟列表 item）。
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.height = 96,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.borderRadius = 12,
    this.lineCount = 3,
    this.lineWidths,
  });

  final double height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;

  /// 每行骨架色块的宽度。null 时使用默认宽度序列。
  final int lineCount;
  final List<double>? lineWidths;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultWidths = [120.0, 200.0, 160.0, 180.0, 100.0];
    return Container(
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < lineCount; i++)
            SkeletonBox(
              width: lineWidths?.elementAtOrNull(i) ??
                  defaultWidths[i % defaultWidths.length],
              height: i == 0 ? 16 : 12,
            ),
        ],
      ),
    );
  }
}

/// 列表骨架屏：重复 [count] 张 [SkeletonCard]，
/// 用于首屏加载代替 [LoadingView]。
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 6,
    this.cardHeight = 96,
  });

  final int count;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => SkeletonCard(height: cardHeight),
    );
  }
}
