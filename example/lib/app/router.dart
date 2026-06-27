import 'package:go_router/go_router.dart';

import '../features/demos/demo_effects_page.dart';
import '../features/demos/demo_extensions_page.dart';
import '../features/demos/demo_raw_page.dart';
import '../features/demos/demo_skeleton_page.dart';
import '../features/demos/demo_ws_page.dart';
import '../features/demos/demos_page.dart';
import '../features/home/home_page.dart';
import '../features/my_page/my_page_page.dart';
import '../features/new_task/new_task_page.dart';
import '../features/settings/settings_page.dart';

GoRouter buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const HomePage(),
        ),
        GoRoute(
          path: '/new',
          builder: (_, __) => const NewTaskPage(),
        ),
        GoRoute(
          path: '/my-page',
          builder: (_, __) => const MyPagePage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsPage(),
        ),
        GoRoute(
          path: '/demos',
          builder: (_, __) => const DemosPage(),
        ),
        GoRoute(
          path: '/demos/raw-page',
          builder: (_, __) => const DemoRawPage(),
        ),
        GoRoute(
          path: '/demos/skeleton',
          builder: (_, __) => const DemoSkeletonPage(),
        ),
        GoRoute(
          path: '/demos/extensions',
          builder: (_, __) => const DemoExtensionsPage(),
        ),
        GoRoute(
          path: '/demos/effects',
          builder: (_, __) => const DemoEffectsPage(),
        ),
        GoRoute(
          path: '/demos/ws',
          builder: (_, __) => const DemoWsPage(),
        ),
      ],
    );
