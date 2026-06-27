import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DemoRawPage extends ConsumerWidget {
  const DemoRawPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(_rawDemoVmProvider.notifier);

    return AppRawPage(
      source: _RawDemoVm,
      child: Scaffold(
        appBar: AppBar(title: const Text('AppRawPage')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'AppRawPage is an escape hatch with only EffectListener.\n'
                'No AppBar, SafeArea, or keyboard dismiss built in.\n'
                'Use it for full-screen players, canvases, etc.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: vm.fireToast,
                icon: const Icon(Icons.notifications),
                label: const Text('Toast via Effect'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RawDemoVm extends ViewModelNotifier<int> {
  @override
  int build() => 0;

  void fireToast() {
    emit(const EffectShowToast('Effect works in AppRawPage too!',
        level: ToastLevel.info));
    update((_) => 0);
  }
}

final _rawDemoVmProvider =
    NotifierProvider.autoDispose<_RawDemoVm, int>(_RawDemoVm.new);
