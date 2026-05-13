import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'effect.dart';

/// 内置 effect 的默认处理器。
///
/// 由宿主业务实现——把 toast / 导航 / 弹窗 / 震动绑定到具体选型
/// （BotToast、go_router、Fluttertoast、原生 bridge 等等）。
/// flutter_spine 不耦合任何 UI 三方库。
///
/// ## handle 返回值约定
///
/// `EffectListener` 会在业务回调前先调用 [handle]：
///   * 返回 `true` → 已处理，**短路** 业务 `onEffect`；
///   * 返回 `false` → 未处理，继续传给业务 `onEffect`。
///
/// 这样 App 根级的 handler 吃掉内置 effect（toast/navigate/pop），
/// Page 级的 listener 只需关心自家业务 effect，职责清晰无重复。
///
/// ## 宿主实现模板
///
/// ```dart
/// class MyEffectHandler extends DefaultEffectHandler {
///   const MyEffectHandler();
///
///   @override
///   bool handle(BuildContext ctx, Effect e) => switch (e) {
///     EffectShowToast(:final message, :final level) => _toast(message, level),
///     EffectShowError(:final error) => _toast(error.displayMessage, ToastLevel.error),
///     EffectNavigate(:final path, :final args) => _navigate(ctx, path, args),
///     EffectPop(:final result) => _pop(ctx, result),
///     EffectShowDialog() => false,  // 业务弹窗交给 Page 处理
///     EffectHaptic(:final kind) => _haptic(kind),
///     _ => false,                    // 业务自定义 effect 一律不处理
///   };
///
///   bool _toast(String msg, ToastLevel level) { BotToast.showText(text: msg); return true; }
///   // ...
/// }
/// ```
///
/// ## 注入
///
/// ```dart
/// runApp(ProviderScope(
///   overrides: [
///     defaultEffectHandlerProvider.overrideWithValue(const MyEffectHandler()),
///   ],
///   child: ...,
/// ));
/// ```
abstract class DefaultEffectHandler {
  const DefaultEffectHandler();

  /// 处理一个 effect。返回 `true` 表示已处理（EffectListener 将短路业务回调）。
  bool handle(BuildContext ctx, Effect effect);
}

/// 不处理任何 effect 的兜底 handler。
///
/// 所有 `handle` 调用都返回 `false`，所以 effect 全部透传到业务 `onEffect`。
/// 用途：
///   * 测试：不想 override provider 时当默认 stub；
///   * 未接入阶段：通用包接入第一步可以先注册这个，再逐步补各 effect 处理。
class NoopDefaultEffectHandler extends DefaultEffectHandler {
  const NoopDefaultEffectHandler();

  @override
  bool handle(BuildContext ctx, Effect effect) => false;
}

/// 默认处理器 Provider。
///
/// 宿主**必须** override，否则运行时抛 [UnimplementedError]；
/// 如果确实不想处理任何内置 effect，用 [NoopDefaultEffectHandler] 显式兜底。
final defaultEffectHandlerProvider = Provider<DefaultEffectHandler>((ref) {
  throw UnimplementedError(
    'defaultEffectHandlerProvider must be overridden. '
    'Provide your DefaultEffectHandler implementation in ProviderScope.overrides, '
    'or use const NoopDefaultEffectHandler() if you want to handle everything in onEffect.',
  );
});
