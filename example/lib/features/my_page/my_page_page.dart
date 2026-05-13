import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'my_page_vm.dart';

class MyPagePage extends ConsumerWidget {
  const MyPagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myPageVmProvider);
    final vm = ref.read(myPageVmProvider.notifier);

    return AppPageScaffold(
      title: 'My Page',
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Counter: ${state.counter}',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.tonal(
                  onPressed: vm.decrement,
                  child: const Text('−'),
                ),
                FilledButton(
                  onPressed: vm.increment,
                  child: const Text('+'),
                ),
                OutlinedButton(
                  onPressed: vm.resetWithToast,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
