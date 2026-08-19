import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/task.dart';
import '../status_picker/status_picker_sheet.dart';
import 'tasks_vm.dart';

/// 业务侧分页列表写法演示（v0.2.6 起 flutter_spine 移除分页模块，
/// 状态类 / 刷新 / 加载更多全部由业务自己实现）：
///
///   * 状态类 → `TaskListState`（见 tasks_vm.dart）
///   * 下拉刷新 → `RefreshIndicator` + `controller.refresh()`
///   * 滚动到底 → `NotificationListener` + `controller.loadMore()`
///   * 首屏 loading / error / 空态 → `AsyncValue.when` + 三态组件
class TasksTab extends ConsumerStatefulWidget {
  const TasksTab({super.key});

  @override
  ConsumerState<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<TasksTab> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
      ref.read(tasksVmProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Tasks',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/new'),
        tooltip: 'New task',
        child: const Icon(Icons.add),
      ),
      body: ref.watch(tasksVmProvider).when(
            loading: () => const SkeletonList(),
            error: (e, st) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(tasksVmProvider),
            ),
            data: (state) => _buildList(ref, state),
          ),
    );
  }

  Widget _buildList(WidgetRef ref, TaskListState state) {
    if (state.isEmpty) return const EmptyView();

    final items = state.items;
    return RefreshIndicator(
      onRefresh: () => ref.read(tasksVmProvider.notifier).refresh(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            if (i >= items.length) return _buildFooter(ref, state);
            final task = items[i];
            return _TaskTile(
              task: task,
              onPickStatus: () => _pickStatus(ctx, ref, task),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooter(WidgetRef ref, TaskListState state) {
    final error = state.moreError;
    if (error != null) {
      return MoreErrorBar(
        error: error,
        onRetry: () => ref.read(tasksVmProvider.notifier).loadMore(),
      );
    }
    if (!state.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('— 没有更多了 —', textAlign: TextAlign.center),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Future<void> _pickStatus(
    BuildContext ctx,
    WidgetRef ref,
    Task task,
  ) async {
    final picked = await showModalBottomSheet<TaskStatus>(
      context: ctx,
      isScrollControlled: true,
      builder: (_) => StatusPickerSheet(current: task.status),
    );
    if (picked != null && picked != task.status) {
      await ref.read(tasksVmProvider.notifier).changeStatus(task.id, picked);
    }
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onPickStatus});

  final Task task;
  final VoidCallback onPickStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(child: Text(task.id.substring(2))),
      title: Text(task.title),
      subtitle: Text(task.description,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: ActionChip(
        label:
            Text(task.status.label, style: theme.textTheme.labelMedium),
        onPressed: onPickStatus,
      ),
    );
  }
}
