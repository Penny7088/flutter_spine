import 'package:go_router/go_router.dart';

import '../features/demos/demo_effect_routing_page.dart';
import '../features/demos/demo_effects_page.dart';
import '../features/demos/demo_extensions_page.dart';
import '../features/demos/demo_raw_page.dart';
import '../features/demos/demo_skeleton_page.dart';
import '../features/demos/demo_ws_page.dart';
import '../features/demos/demos_page.dart';
import '../features/home/home_page.dart';
import '../features/home/stats_tab.dart';
import '../features/home/tasks_tab.dart';
import '../features/my_page/my_page_page.dart';
import '../features/new_task/new_task_page.dart';
import '../features/settings/settings_page.dart';

GoRouter buildRouter() => GoRouter(
      initialLocation: '/tasks',
      routes: [
        ShellRoute(
          builder: (ctx, state, child) => HomePage(child: child),
          routes: [
            GoRoute(
              path: '/tasks',
              builder: (_, __) => const TasksTab(),
            ),
            GoRoute(
              path: '/stats',
              builder: (_, __) => const StatsTab(),
            ),
            GoRoute(
              path: '/demos',
              builder: (_, __) => const DemosPage(),
              routes: [
                GoRoute(
                  path: 'skeleton',
                  builder: (_, __) => const DemoSkeletonPage(),
                ),
                GoRoute(
                  path: 'effects',
                  builder: (_, __) => const DemoEffectsPage(),
                ),
                GoRoute(
                  path: 'extensions',
                  builder: (_, __) => const DemoExtensionsPage(),
                ),
                GoRoute(
                  path: 'raw-page',
                  builder: (_, __) => const DemoRawPage(),
                ),
                GoRoute(
                  path: 'ws',
                  builder: (_, __) => const DemoWsPage(),
                ),
                GoRoute(
                  path: 'effect-routing',
                  builder: (_, __) => const DemoEffectRoutingPage(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/',
          redirect: (_, __) => '/tasks',
        ),
        GoRoute(
          path: '/new',
          builder: (_, __) => const NewTaskPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsPage(),
        ),
        GoRoute(
          path: '/my-page',
          builder: (_, __) => const MyPagePage(),
        ),
      ],
    );
