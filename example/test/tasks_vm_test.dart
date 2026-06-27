import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/data/task.dart';
import '../lib/data/task_repository.dart';
import '../lib/features/home/tasks_vm.dart';

class _FakeTaskRepository extends TaskRepository {
  bool failNextUpdate = false;

  @override
  Future<void> updateStatus(String id, TaskStatus status) async {
    if (failNextUpdate) {
      failNextUpdate = false;
      throw const NetworkException(message: 'Simulated failure');
    }
    await super.updateStatus(id, status);
  }
}

Future<List<EffectEnvelope>> collectEffects(
  ProviderContainer container,
  Future<void> Function() run,
) async {
  final envs = <EffectEnvelope>[];
  final sub = container.read(effectBusProvider).stream.listen(envs.add);
  await run();
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return envs;
}

void main() {
  late ProviderContainer container;
  late _FakeTaskRepository repo;

  setUp(() {
    repo = _FakeTaskRepository();
    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('TasksVm', () {
    test('fetchPage returns items', () async {
      container.listen(tasksVmProvider, (_, __) {});
      final vm = container.read(tasksVmProvider.notifier);

      await vm.refresh();

      final state = container.read(tasksVmProvider);
      expect(state.valueOrNull, isNotNull);
      expect(state.valueOrNull!.items.length, greaterThan(0));
    });

    test('changeStatus optimistically updates then succeeds', () async {
      container.listen(tasksVmProvider, (_, __) {});
      final vm = container.read(tasksVmProvider.notifier);
      await vm.refresh();

      final items = container.read(tasksVmProvider).valueOrNull!.items;
      final targetId = items.first.id;

      final effects = await collectEffects(container, () async {
        await vm.changeStatus(targetId, TaskStatus.done);
      });

      expect(effects, hasLength(1));
      expect(effects.first.payload, isA<EffectShowToast>());
    });

    test('changeStatus rolls back on failure', () async {
      repo.failNextUpdate = true;
      container.listen(tasksVmProvider, (_, __) {});
      final vm = container.read(tasksVmProvider.notifier);
      await vm.refresh();

      final items = container.read(tasksVmProvider).valueOrNull!.items;
      final targetId = items.first.id;
      final originalStatus = items.first.status;

      final effects = await collectEffects(container, () async {
        await vm.changeStatus(targetId, TaskStatus.done);
      });

      // Rolled back to original status
      final state = container.read(tasksVmProvider);
      final restored = state.valueOrNull!.items.firstWhere((t) => t.id == targetId);
      expect(restored.status, originalStatus);

      expect(effects, hasLength(1));
      expect(effects.first.payload, isA<EffectShowError>());
    });
  });
}
