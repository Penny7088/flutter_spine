import '../error/app_exception.dart';

/// [Effect] 是"一次性副作用"的标记类型。
///
/// 与 state 的区别：
///   * **state** 描述持久的 UI 状态（列表数据、表单值、加载标志），进入 state 后会被持续展示；
///   * **effect** 描述一次性动作（toast、导航、弹窗、震动、埋点），发射后消费完即止，
///     不适合放在 state——否则会出现"刷新页面后 toast 又弹一次"的重放 bug。
///
/// ## 使用
///
/// VM 侧（通过 `ViewModelNotifier.emit`）：
/// ```dart
/// emit(const EffectShowToast('已取消', level: ToastLevel.success));
/// ```
///
/// UI 侧（通过 `EffectListener`）：
/// ```dart
/// EffectListener(
///   source: OrderListVm,
///   onEffect: (ctx, e) {
///     if (e is OpenPaymentGateway) _openNative(e.orderId);
///   },
///   child: ...,
/// )
/// ```
///
/// ## 扩展
///
/// 业务自定义 effect 直接 `extends Effect`；当存在多个业务 effect 且希望穷尽匹配时，
/// 可用 `sealed class` 分组：
/// ```dart
/// sealed class OrderEffect extends Effect { const OrderEffect(); }
/// class OpenPaymentGateway extends OrderEffect {
///   const OpenPaymentGateway(this.orderId);
///   final String orderId;
/// }
/// ```
abstract class Effect {
  const Effect();
}

/// Toast 的语义级别。具体外观由 `DefaultEffectHandler` 的实现方（BotToast / Fluttertoast / 自绘）决定。
enum ToastLevel { info, success, warn, error }

/// 震动反馈类型。具体强度由实现方映射到平台能力（iOS UIImpactFeedback / Android VibrationEffect）。
enum HapticKind {
  light,
  medium,
  heavy,
  selection,
  success,
  warn,
  error,
}

// ── 内置 Effect ─────────────────────────────────────────────────────────────

/// 弹一个 toast。
class EffectShowToast extends Effect {
  const EffectShowToast(this.message, {this.level = ToastLevel.info});

  final String message;
  final ToastLevel level;

  @override
  String toString() => 'EffectShowToast($level, "$message")';
}

/// 展示一个 [AppException] 错误。
///
/// 通常由 `ViewModelNotifier.run` 在失败时自动发射；
/// 也可业务手动 `emit(EffectShowError(e))`。
class EffectShowError extends Effect {
  const EffectShowError(this.error);

  final AppException error;

  @override
  String toString() => 'EffectShowError($error)';
}

/// 跳转到指定路由。
///
/// [path] 的协议由 `DefaultEffectHandler` 的实现方约定——
/// 可以是 go_router 路径、Navigator route name、或原生 bridge action。
class EffectNavigate extends Effect {
  const EffectNavigate(this.path, {this.args});

  final String path;
  final Object? args;

  @override
  String toString() => 'EffectNavigate($path, args=$args)';
}

/// 关闭当前路由。[result] 会作为 pop 的返回值。
class EffectPop extends Effect {
  const EffectPop([this.result]);

  final Object? result;

  @override
  String toString() => 'EffectPop(result=$result)';
}

/// 展示一个预注册的弹窗。[dialogId] 作为 key，由宿主 handler 按 id 分发到具体 Widget。
class EffectShowDialog extends Effect {
  const EffectShowDialog(this.dialogId, {this.args});

  final String dialogId;
  final Object? args;

  @override
  String toString() => 'EffectShowDialog($dialogId, args=$args)';
}

/// 触发一次震动反馈。
class EffectHaptic extends Effect {
  const EffectHaptic(this.kind);

  final HapticKind kind;

  @override
  String toString() => 'EffectHaptic($kind)';
}
