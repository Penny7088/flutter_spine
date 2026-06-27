import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'home_vm.dart';

class HomePage extends ConsumerWidget {
  const HomePage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeVmProvider);
    final top = GoRouterState.of(context).uri.toString();
    int index = 0;
    if (top == '/stats') {
      index = 1;
    } else if (top == '/demos' || top.startsWith('/demos/')) {
      index = 2;
    }

    return AppPageScaffold(
      source: HomeVm,
      onEffect: (ctx, effect) {
        if (effect is GlobalCustomEffect) {
          showDialog(
            context: ctx,
            builder: (_) => AlertDialog(
              title: const Text('Global Effect (Shell)'),
              content: Text(effect.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
      bottomBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/tasks');
            case 1:
              context.go('/stats');
            case 2:
              context.go('/demos');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.widgets), label: 'Demos'),
        ],
      ),
      body: child,
    );
  }
}
