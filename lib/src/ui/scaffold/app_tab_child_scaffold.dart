import 'package:flutter/material.dart';

import '../../effect/effect.dart';
import '../../effect/effect_listener.dart';

/// Tab 子页骨架。放在 `TabBarView` / `PageView` 等容器里的"页面"。
///
/// 自身**不提供** AppBar / Scaffold —— 外层 Tab 宿主页已经有了；
/// 只负责两件事：
///
/// 1. 订阅该子页 VM 的 effect（按 [source] 过滤，避免跨 Tab 干扰）；
/// 2. 可选的 `AutomaticKeepAlive` —— 切走再切回保留滚动位置 / 状态（默认开）。
///
/// ## 用法
///
/// ```dart
/// TabBarView(children: [
///   AppTabChildScaffold(
///     source: OrderTabAllVm,
///     child: _AllOrdersList(),
///   ),
///   AppTabChildScaffold(
///     source: OrderTabPendingVm,
///     child: _PendingOrdersList(),
///   ),
/// ])
/// ```
class AppTabChildScaffold extends StatefulWidget {
  const AppTabChildScaffold({
    super.key,
    required this.child,
    this.source,
    this.onEffect,
    this.handleDefaultEffects = true,
    this.keepAlive = true,
  });

  final Widget child;

  final Type? source;
  final void Function(BuildContext ctx, Effect effect)? onEffect;
  final bool handleDefaultEffects;

  /// 是否保持子页 state 不被销毁。默认 true。
  final bool keepAlive;

  @override
  State<AppTabChildScaffold> createState() => _AppTabChildScaffoldState();
}

class _AppTabChildScaffoldState extends State<AppTabChildScaffold>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return EffectListener(
      source: widget.source,
      handleDefaults: widget.handleDefaultEffects,
      onEffect: (ctx, e) => widget.onEffect?.call(ctx, e),
      child: widget.child,
    );
  }
}
