import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task.dart';
import '../../data/task_repository.dart';

class TasksVm extends AutoDisposeAsyncNotifier<PagedState<Task>>
    with PagedNotifierMixinNoArg<Task> {
  @override
  Future<PagedState<Task>> build() async {
    ref.keepAlive();
    return super.build();
  }

  @override
  int get pageSize => 20;

  @override
  Future<List<Task>> fetchPage(int page, int size) =>
      ref.read(taskRepositoryProvider).list(page: page, size: size);

  Future<void> changeStatus(String id, TaskStatus next) async {
    patch((items) =>
        [for (final t in items) if (t.id == id) t.copyWith(status: next) else t]);

    try {
      await ref.read(taskRepositoryProvider).updateStatus(id, next);
      _emit(const EffectShowToast('Updated', level: ToastLevel.success));
    } on AppException catch (e) {
      _emit(EffectShowError(e));
      await refresh();
    }
  }

  void _emit(Effect e) =>
      ref.read(effectBusProvider).emit(runtimeType, e);

  Result<Task>? lastResult;

  Future<Result<Task>> createWithResult(String title, String desc) async {
    final r = await ref.read(taskRepositoryProvider).create(
          title: title,
          description: desc,
        ).toResult();
    lastResult = r;
    if (r is Ok<Task>) {
      await refresh();
    }
    return r;
  }
}

final tasksVmProvider =
    AutoDisposeAsyncNotifierProvider<TasksVm, PagedState<Task>>(TasksVm.new);
