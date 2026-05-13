import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task.dart';
import '../../data/task_repository.dart';

/// 简单数据展示 VM：用 [AsyncViewModelNotifier]，state 直接是 `AsyncValue<TaskStats>`。
///
/// `mutate()` 演示带 `applyTo` 的乐观刷新（这里只演示拉取，无 mutation）。
class StatsVm extends AsyncViewModelNotifier<TaskStats> {
  @override
  Future<TaskStats> build() => ref.read(taskRepositoryProvider).stats();
}

final statsVmProvider =
    AsyncNotifierProvider.autoDispose<StatsVm, TaskStats>(StatsVm.new);
