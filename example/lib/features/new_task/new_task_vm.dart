import 'package:flutter/foundation.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task_repository.dart';
import '../home/tasks_vm.dart';

@immutable
class NewTaskState with HasViewStatus {
  const NewTaskState({
    this.title = '',
    this.description = '',
    this.status = ViewStatus.idle,
    this.error,
  });

  final String title;
  final String description;

  @override
  final ViewStatus status;

  @override
  final AppException? error;

  bool get canSubmit =>
      status != ViewStatus.loading && title.trim().isNotEmpty;

  NewTaskState copyWith({
    String? title,
    String? description,
    ViewStatus? status,
    AppException? error,
  }) =>
      NewTaskState(
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        error: error ?? this.error,
      );
}

/// 表单 VM——演示 [ViewModelNotifier.run] 的标准三段式：
/// `onStart`（loading） → `action`（call repo） → `onSuccess`（清空表单）
/// 失败由 `run()` 自动 emit `EffectShowError`，无需业务侧关心。
class NewTaskVm extends ViewModelNotifier<NewTaskState> {
  @override
  NewTaskState build() => const NewTaskState();

  void setTitle(String v) =>
      update((s) => s.copyWith(title: v));

  void setDescription(String v) =>
      update((s) => s.copyWith(description: v));

  Future<void> submit() async {
    if (!state.canSubmit) return;

    final r = await run(
      () => ref.read(taskRepositoryProvider).create(
            title: state.title.trim(),
            description: state.description.trim(),
          ),
      onStart: (s) => s.copyWith(status: ViewStatus.loading, error: null),
      onSuccess: (s, _) =>
          const NewTaskState(status: ViewStatus.ok),
      onFailure: (s, e) => s.copyWith(status: ViewStatus.error, error: e),
    );

    if (r is Ok) {
      // 让列表 Tab 拉到新数据；invalidate 是 Riverpod 直接 API。
      ref.invalidate(tasksVmProvider);
      emit(const EffectShowToast('Task created', level: ToastLevel.success));
      emit(const EffectPop());
    }
  }
}

final newTaskVmProvider =
    NotifierProvider.autoDispose<NewTaskVm, NewTaskState>(NewTaskVm.new);
