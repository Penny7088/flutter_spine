import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task.dart';
import '../../data/task_repository.dart';

class StatsVm extends AsyncViewModelNotifier<TaskStats> {
  @override
  Future<TaskStats> build() {
    ref.keepAlive();
    return ref.read(taskRepositoryProvider).stats();
  }
}

final statsVmProvider =
    AsyncNotifierProvider.autoDispose<StatsVm, TaskStats>(StatsVm.new);
