import 'package:go_router/go_router.dart';

import '../features/home/home_page.dart';
import '../features/new_task/new_task_page.dart';

/// 仅 2 个路由：演示足够。
///
/// VM 通过 `emit(EffectNavigate('/new'))` 跳转，
/// `emit(EffectPop())` 返回——VM 完全不感知 GoRouter 的存在。
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
      ],
    );
