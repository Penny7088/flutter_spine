import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'new_task_vm.dart';

class NewTaskPage extends ConsumerWidget {
  const NewTaskPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(newTaskVmProvider);
    final vm = ref.read(newTaskVmProvider.notifier);

    return AppFormPageScaffold(
      title: 'New Task',
      source: NewTaskVm,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            onChanged: vm.setTitle,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: vm.setDescription,
            maxLines: 4,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
      bottomAction: FilledButton.icon(
        icon: state.status.isLoading
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check),
        label: Text(state.status.isLoading ? 'Saving…' : 'Create'),
        onPressed: state.canSubmit ? vm.submit : null,
      ),
    );
  }
}
