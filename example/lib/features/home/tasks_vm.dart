import 'package:flutter/foundation.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task.dart';
import '../../data/task_repository.dart';

/// 业务侧分页状态（v0.2.6 起 flutter_spine 不再提供任何分页类型，
/// 状态类 / Notifier 逻辑全部由业务自己实现）。
@immutable
class TaskListState {
  const TaskListState({
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.moreError,
  });

  final List<Task> items;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? moreError;

  bool get isEmpty => items.isEmpty;

  TaskListState copyWith({
    List<Task>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    Object? moreError,
    bool clearMoreError = false,
  }) =>
      TaskListState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        moreError: clearMoreError ? null : (moreError ?? this.moreError),
      );
}

class TasksVm extends AutoDisposeAsyncNotifier<TaskListState> {
  static const _pageSize = 20;

  @override
  Future<TaskListState> build() async {
    ref.keepAlive();
    return _fetch(1);
  }

  Future<TaskListState> _fetch(int page) async {
    final items = await ref
        .read(taskRepositoryProvider)
        .list(page: page, size: _pageSize);
    return TaskListState(
      items: items,
      page: page,
      hasMore: items.length >= _pageSize,
    );
  }

  /// 下拉刷新：重建自身，拉第 1 页。
  Future<void> refresh() async {
    await future;
    ref.invalidateSelf();
    await future;
  }

  /// 加载下一页。返回是否还有更多（失败 / 已到底返回 false）。
  Future<bool> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return false;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final nextPage = current.page + 1;
      final newItems = await ref
          .read(taskRepositoryProvider)
          .list(page: nextPage, size: _pageSize);
      final next = TaskListState(
        items: [...current.items, ...newItems],
        page: nextPage,
        hasMore: newItems.length >= _pageSize,
      );
      state = AsyncData(next);
      return next.hasMore;
    } catch (e) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, moreError: e),
      );
      return false;
    }
  }

  /// 乐观更新 + 失败回滚（快照恢复，不重拉）。
  Future<void> changeStatus(String id, TaskStatus next) async {
    final snapshot = state.valueOrNull;
    if (snapshot == null) return;

    state = AsyncData(
      snapshot.copyWith(
        items: [
          for (final t in snapshot.items)
            if (t.id == id) t.copyWith(status: next) else t,
        ],
      ),
    );

    try {
      await ref.read(taskRepositoryProvider).updateStatus(id, next);
      _emit(const EffectShowToast('Updated', level: ToastLevel.success));
    } on AppException catch (e) {
      state = AsyncData(snapshot);
      _emit(EffectShowError(e));
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
    AutoDisposeAsyncNotifierProvider<TasksVm, TaskListState>(TasksVm.new);
