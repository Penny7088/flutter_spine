import 'package:flutter/material.dart';

import '../../../flutter_spine.dart';

/// 默认加载中视图。
///
/// 业务层可通过 [PagedListView.firstLoading] 或 [AsyncPageStateView.loading]
/// 参数传入自定义 Widget 覆盖（如骨架屏 [SkeletonList]）。
class LoadingView extends StatelessWidget {
  const LoadingView({
    super.key,
    this.size = 36,
    this.color,
    this.strokeWidth = 2.5,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
