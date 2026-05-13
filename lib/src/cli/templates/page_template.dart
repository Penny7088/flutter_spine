/// 同步 VM + 普通 page 三件套（state / vm / page）。
/// 适合"基本不调接口、靠 update 改状态"的页面，例如设置页 / 关于页。
const pageStateTemplate = r'''
import 'package:flutter/foundation.dart';

@immutable
class {{Name}}State {
  const {{Name}}State({
    this.counter = 0,
  });

  final int counter;

  {{Name}}State copyWith({int? counter}) =>
      {{Name}}State(counter: counter ?? this.counter);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is {{Name}}State && other.counter == counter;

  @override
  int get hashCode => counter.hashCode;
}
''';

const pageVmTemplate = r'''
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '{{name_snake}}_state.dart';

final {{name}}VmProvider =
    NotifierProvider.autoDispose<{{Name}}Vm, {{Name}}State>({{Name}}Vm.new);

class {{Name}}Vm extends ViewModelNotifier<{{Name}}State> {
  @override
  {{Name}}State build() => const {{Name}}State();

  void increment() => update((s) => s.copyWith(counter: s.counter + 1));

  void decrement() => update((s) => s.copyWith(counter: s.counter - 1));

  Future<void> resetWithToast() async {
    update((s) => s.copyWith(counter: 0));
    emit(const EffectShowToast('Reset done', level: ToastLevel.success));
  }
}
''';

const pagePageTemplate = r'''
import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '{{name_snake}}_vm.dart';

class {{Name}}Page extends ConsumerWidget {
  const {{Name}}Page({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch({{name}}VmProvider);
    final vm = ref.read({{name}}VmProvider.notifier);

    return AppPageScaffold(
      title: '{{Title}}',
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
''';

const pageVmTestTemplate = r'''
import 'package:flutter_core_test/flutter_core_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:{{pkg}}/features/{{name_snake}}/{{name_snake}}_vm.dart';

void main() {
  group('{{Name}}Vm', () {
    test('increment / decrement', () {
      final h = createVmTestHarness();
      h.keepAlive({{name}}VmProvider);
      final vm = h.read({{name}}VmProvider.notifier);

      vm.increment();
      expect(h.read({{name}}VmProvider).counter, 1);

      vm.decrement();
      vm.decrement();
      expect(h.read({{name}}VmProvider).counter, -1);
    });

    test('resetWithToast 发 EffectShowToast', () async {
      final h = createVmTestHarness();
      h.keepAlive({{name}}VmProvider);
      await h.read({{name}}VmProvider.notifier).resetWithToast();
      await h.pump();
      expect(h.effects.lastPayload, isToast());
    });
  });
}
''';
