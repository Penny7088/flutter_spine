import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:go_router/go_router.dart';

import 'stats_tab.dart';
import 'tasks_tab.dart';

/// 父页面：标准 [AppPageScaffold] + 自带 TabBar 的 [AppDefaultAppBar]。
///
/// 子 Tab 用 [AppTabChildScaffold]，避免 Scaffold 嵌套。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: AppPageScaffold(
        appBar: AppDefaultAppBar(
          title: 'flutter_spine demo',
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: 'Tasks'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
            ],
          ),
        ),
        floatingActionButton: _NewTaskFab(),
        body: TabBarView(
          children: [
            TasksTab(),
            StatsTab(),
          ],
        ),
      ),
    );
  }
}

class _NewTaskFab extends StatelessWidget {
  const _NewTaskFab();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => context.push('/new'),
      tooltip: 'New task',
      child: const Icon(Icons.add),
    );
  }
}
