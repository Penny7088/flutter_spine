import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task.dart';
import 'stats_vm.dart';

class StatsTab extends ConsumerWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(statsVmProvider);
    return AppPageScaffold(
      title: 'Stats',

      body: RefreshIndicator(
        onRefresh: () => ref.read(statsVmProvider.notifier).refresh(),
        child: asyncStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (stats) => _StatsBody(stats: stats),
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});
  final TaskStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.checklist),
            title: Text('Total tasks: ${stats.total}',
                style: theme.textTheme.titleLarge),
          ),
        ),
        const SizedBox(height: 8),
        for (final s in TaskStatus.values)
          Card(
            child: ListTile(
              leading: const Icon(Icons.label_outline),
              title: Text(s.label),
              trailing: Text(
                stats.countOf(s).toString(),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
      ],
    );
  }
}
