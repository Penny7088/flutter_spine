import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task.dart';
import '../../data/task_repository.dart';

/// 分页列表 VM。直接用 [PagedNotifierMixinNoArg] 拿到 refresh / loadMore /
/// patch 三件套，自己只写 `fetchPage`。
///
/// 多了一个 `changeStatus` 演示乐观更新 + 失败回滚 + 失败 toast。
class TasksVm extends AutoDisposeAsyncNotifier<PagedState<Task>>
    with PagedNotifierMixinNoArg<Task> {
  @override
  int get pageSize => 20;

  @override
  Future<List<Task>> fetchPage(int page, int size) =>
      ref.read(taskRepositoryProvider).list(page: page, size: size);

  Future<void> changeStatus(String id, TaskStatus next) async {
    // 1) 立刻乐观更新 UI。
    patch((items) =>
        [for (final t in items) if (t.id == id) t.copyWith(status: next) else t]);

    // 2) 调远端；成功则不动；失败则发 EffectShowError + refresh 恢复真值。
    try {
      await ref.read(taskRepositoryProvider).updateStatus(id, next);
      _emit(const EffectShowToast('已更新', level: ToastLevel.success));
    } on AppException catch (e) {
      _emit(EffectShowError(e));
      await refresh();
    }
  }

  void _emit(Effect e) =>
      ref.read(effectBusProvider).emit(runtimeType, e);
}

final tasksVmProvider =
    AutoDisposeAsyncNotifierProvider<TasksVm, PagedState<Task>>(TasksVm.new);
