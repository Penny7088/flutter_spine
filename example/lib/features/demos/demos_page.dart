import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:go_router/go_router.dart';

class DemosPage extends StatelessWidget {
  const DemosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPageScaffold(
      title: 'Demos',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DemoTile(
            icon: Icons.widgets_outlined,
            title: 'Skeleton Widgets',
            subtitle: 'SkeletonBox / SkeletonRow / SkeletonCard / SkeletonList',
            onTap: () => context.push('/demos/skeleton'),
          ),
          _DemoTile(
            icon: Icons.vibration,
            title: 'Effects',
            subtitle: 'EffectHaptic / EffectShowToast / EffectNavigate / EffectShowDialog',
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
            subtitle: 'Low-level escape hatch with EffectListener only',
            onTap: () => context.push('/demos/raw-page'),
          ),
          _DemoTile(
            icon: Icons.wifi,
            title: 'WebSocket Topic',
            subtitle: 'WsTopicRouter / subscribe / unsubscribe with fake channel',
            onTap: () => context.push('/demos/ws'),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'This page uses AppPageScaffold.\n'
                'AppListPageScaffold is demonstrated in the Tasks tab '
                '(via PagedListView inside AppTabChildScaffold).',
                style: theme.textTheme.bodySmall,
              ),
            ),
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
