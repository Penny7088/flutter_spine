import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task.dart';
import '../status_picker/status_picker_sheet.dart';
import 'tasks_vm.dart';

class TasksTab extends ConsumerWidget {
  const TasksTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppTabChildScaffold(
      source: TasksVm,
      child: PagedListView<Task>(
        provider: tasksVmProvider,
        controllerProvider: tasksVmProvider.notifier,
        firstLoading: const SkeletonList(),
        itemBuilder: (ctx, task, _) => _TaskTile(
          task: task,
          onPickStatus: () => _pickStatus(ctx, ref, task),
        ),
        separatorBuilder: (_, __) => const Divider(height: 1),
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
