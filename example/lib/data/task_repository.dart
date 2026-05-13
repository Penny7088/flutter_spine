import 'dart:math';

import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'task.dart';

/// 内存版假仓库——演示数据流。
///
/// * 一切方法都通过 [safeApiCall] 包裹，证明业务侧只面对 [AppException]；
/// * `list(page, size)` 假分页 100 条；
/// * `create()` 偶尔抛 [NetworkException] 演示失败链路（toast 弹窗）；
/// * `updateStatus()` 立刻成功，演示乐观更新。
class TaskRepository {
  TaskRepository() : _items = List.generate(100, _seed) {
    _items.shuffle(Random(42));
  }

  final List<Task> _items;
  final _rand = Random();

  static Task _seed(int i) => Task(
        id: 't-$i',
        title: 'Task #$i',
        description: 'Auto-generated demo task #$i',
        status: TaskStatus.values[i % 3],
      );

  Future<List<Task>> list({required int page, required int size}) =>
      safeApiCall(() async {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        final start = (page - 1) * size;
        if (start >= _items.length) return const <Task>[];
        return _items.sublist(start, (start + size).clamp(0, _items.length));
      });

  Future<TaskStats> stats() => safeApiCall(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final by = <TaskStatus, int>{};
        for (final s in TaskStatus.values) {
          by[s] = _items.where((t) => t.status == s).length;
        }
        return TaskStats(total: _items.length, byStatus: by);
      });

  Future<Task> create({required String title, required String description}) =>
      safeApiCall(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (_rand.nextDouble() < 0.2) {
          throw const NetworkException(message: 'Random network failure (demo)');
        }
        final task = Task(
          id: 't-${_items.length}',
          title: title,
          description: description,
          status: TaskStatus.todo,
        );
        _items.insert(0, task);
        return task;
      });

  Future<void> updateStatus(String id, TaskStatus status) =>
      safeApiCall(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final i = _items.indexWhere((t) => t.id == id);
        if (i == -1) {
          throw const NotFoundException(message: 'Task not found');
        }
        _items[i] = _items[i].copyWith(status: status);
      });
}

/// 仓库 provider；测试中可 override 注入 fake。
final taskRepositoryProvider =
    Provider<TaskRepository>((_) => TaskRepository());
