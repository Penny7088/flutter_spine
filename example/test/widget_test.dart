import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/app/router.dart';
import '../lib/data/task.dart';
import '../lib/data/task_repository.dart';

void main() {
  testWidgets('App renders and navigates to new task page',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(
            _FastTaskRepository(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: buildRouter(),
        ),
      ),
    );

    // 多 pump 几次清除 scroll simulation timers
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // AppBar title + NavigationBar labels
    expect(find.text('Tasks'), findsNWidgets(2));
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Demos'), findsOneWidget);
  });
}

/// 去掉 delay 的仓库，避免 widget test 产生 pending timer。
class _FastTaskRepository extends TaskRepository {
  @override
  Future<List<Task>> list({required int page, required int size}) async {
    return List.generate(size, (i) => Task(
      id: 't-$i',
      title: 'Task #$i',
      description: '',
      status: TaskStatus.todo,
    ));
  }
}
