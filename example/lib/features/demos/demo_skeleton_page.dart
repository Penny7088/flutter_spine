import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';

class DemoSkeletonPage extends StatelessWidget {
  const DemoSkeletonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPageScaffold(
      title: 'Skeleton Widgets',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('SkeletonBox', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const SkeletonBox(width: 200, height: 14),
          const SizedBox(height: 16),
          Text('SkeletonRow', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const SkeletonRow(widths: [80, 120, 60], height: 14, spacing: 8),
          const SizedBox(height: 16),
          Text('SkeletonCard', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const SkeletonCard(margin: EdgeInsets.zero),
          const SizedBox(height: 16),
          Text('SkeletonList', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 400,
            child: SkeletonList(count: 4, cardHeight: 80),
          ),
        ],
      ),
    );
  }
}
