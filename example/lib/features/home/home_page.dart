import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:go_router/go_router.dart';

import 'stats_tab.dart';
import 'tasks_tab.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: AppPageScaffold(
        appBar: AppDefaultAppBar(
          title: 'flutter_spine demo',
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: 'Tasks'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
              Tab(icon: Icon(Icons.widgets), text: 'Demos'),
            ],
          ),
        ),
        actions: [
          _SettingsAction(),
        ],
        floatingActionButton: _NewTaskFab(),
        body: TabBarView(
          children: [
            TasksTab(),
            StatsTab(),
            _DemosTab(),
          ],
        ),
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Settings',
      onPressed: () => context.push('/settings'),
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

class _DemosTab extends StatelessWidget {
  const _DemosTab();

  @override
  Widget build(BuildContext context) {
    return AppTabChildScaffold(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DemoTile(
            icon: Icons.widgets_outlined,
            title: 'Skeleton Widgets',
            subtitle: 'SkeletonBox / SkeletonList',
            onTap: () => context.push('/demos/skeleton'),
          ),
          _DemoTile(
            icon: Icons.vibration,
            title: 'Effects',
            subtitle: 'Haptic / Toast / Dialog / Navigate / Pop',
            onTap: () => context.push('/demos/effects'),
          ),
          _DemoTile(
            icon: Icons.code,
            title: 'Extensions',
            subtitle: 'BuildContextX / DateTimeX / IterableX / NumFormatX / StringSafeX',
            onTap: () => context.push('/demos/extensions'),
          ),
          _DemoTile(
            icon: Icons.layers_outlined,
            title: 'AppRawPage',
            subtitle: 'Escape hatch with EffectListener only',
            onTap: () => context.push('/demos/raw-page'),
          ),
          _DemoTile(
            icon: Icons.person,
            title: 'My Page (Counter)',
            subtitle: 'ViewModelNotifier + EffectHaptic',
            onTap: () => context.push('/my-page'),
          ),
          _DemoTile(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'ThemeModeNotifier + KeyValueStorage + AppLogger',
            onTap: () => context.push('/settings'),
          ),
          _DemoTile(
            icon: Icons.dashboard_customize,
            title: 'AppListPageScaffold',
            subtitle: 'Combined AppPageScaffold + PagedListView',
            onTap: () => context.push('/demos'),
          ),
        ],
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
