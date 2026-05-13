import 'package:flutter/widgets.dart';

import '../../effect/effect.dart';
import '../../effect/effect_listener.dart';

/// 逃生舱：不做任何页面结构假设，只接入 Effect 分发。
///
/// 99% 的页面应当用 `AppPageScaffold` / `AppListPageScaffold` 等更具结构的版本。
/// 只有在面对全屏播放器、自绘画布、特殊启动页等"非标准页面"时才降级到本类，
/// 以便这些页面依然能响应 VM 侧的 toast / navigate / haptic 等副作用。
///
/// ## 用法
///
/// ```dart
/// AppRawPage(
///   source: SplashVm,
///   child: CustomSplashAnimation(),
/// )
/// ```
class AppRawPage extends StatelessWidget {
  const AppRawPage({
    super.key,
    required this.child,
    this.source,
    this.onEffect,
    this.handleDefaultEffects = true,
  });

  /// 整页内容。外部完全自控。
  final Widget child;

  /// 只监听指定 VM 的 effect（按 `runtimeType`）。null 表示监听全量。
  final Type? source;

  /// 业务自定义 effect 回调。
  final void Function(BuildContext ctx, Effect effect)? onEffect;

  /// 是否在 [onEffect] 之前走一遍 `DefaultEffectHandler`。默认 true。
  final bool handleDefaultEffects;

  @override
  Widget build(BuildContext context) {
    return EffectListener(
      source: source,
      handleDefaults: handleDefaultEffects,
      onEffect: (ctx, e) => onEffect?.call(ctx, e),
      child: child,
    );
  }
}
