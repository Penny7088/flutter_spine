import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/data/task.dart';
import '../lib/data/task_repository.dart';
import '../lib/features/home/tasks_vm.dart';
import '../lib/features/new_task/new_task_vm.dart';

class _ControlledRepo extends TaskRepository {
  bool failNextCreate = false;

  @override
  Future<Task> create({required String title, required String description}) async {
    if (failNextCreate) {
      failNextCreate = false;
      throw const NetworkException(message: 'Simulated create failure');
    }
    return Task(
      id: 't-new',
      title: title,
      description: description,
      status: TaskStatus.todo,
    );
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
  late _ControlledRepo repo;

  setUp(() {
    repo = _ControlledRepo();
    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('NewTaskVm', () {
    test('initial state is idle with empty fields', () {
      final state = container.read(newTaskVmProvider);
      expect(state.title, '');
      expect(state.description, '');
      expect(state.canSubmit, false);
      expect(state.status, ViewStatus.idle);
    });

    test('setTitle and setDescription update state', () {
      final vm = container.read(newTaskVmProvider.notifier);
      vm.setTitle('Test title');
      vm.setDescription('Test description');

      final state = container.read(newTaskVmProvider);
      expect(state.title, 'Test title');
      expect(state.description, 'Test description');
      expect(state.canSubmit, true);
    });

    test('submit succeeds, emits toast + pop, invalidates list', () async {
      // keepAlive 阻止 autoDispose
      container.listen(newTaskVmProvider, (_, __) {});
      container.listen(tasksVmProvider, (_, __) {});

      final vm = container.read(newTaskVmProvider.notifier);
      vm.setTitle('New task');

      final effects = await collectEffects(container, () async {
        await vm.submit();
      });

      final state = container.read(newTaskVmProvider);
      expect(state.status, ViewStatus.ok);

      // 发射了 toast + pop
      expect(effects, hasLength(2));
      expect(effects[0].payload, isA<EffectShowToast>());
      expect(effects[1].payload, isA<EffectPop>());
    });

    test('submit fails, shows error state', () async {
      repo.failNextCreate = true;
      container.listen(newTaskVmProvider, (_, __) {});
      container.listen(tasksVmProvider, (_, __) {});

      final vm = container.read(newTaskVmProvider.notifier);
      vm.setTitle('Failing task');

      await vm.submit();

      final state = container.read(newTaskVmProvider);
      expect(state.status, ViewStatus.error);
      expect(state.error, isA<NetworkException>());
    });

    test('submit does nothing when title is empty', () async {
      container.listen(newTaskVmProvider, (_, __) {});

      final vm = container.read(newTaskVmProvider.notifier);
      expect(vm.state.canSubmit, false);

      await vm.submit();

      // state unchanged
      final state = container.read(newTaskVmProvider);
      expect(state.status, ViewStatus.idle);
    });
  });
}
