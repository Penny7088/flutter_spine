import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'default_effect_handler.dart';
import 'effect.dart';
import 'effect_bus.dart';

/// 订阅 [effectBusProvider] 并把 effect 派发到 UI 的 Widget。
///
/// ## 两种使用模式
///
/// ### 1. App 根级——处理所有内置 effect
///
/// ```dart
/// runApp(ProviderScope(
///   overrides: [
///     defaultEffectHandlerProvider.overrideWithValue(const MyHandler()),
///   ],
///   child: MaterialApp.router(
///     builder: (ctx, child) => EffectListener(
///       onEffect: (_, __) {}, // 业务 effect 交给 Page 处理
///       child: child!,
///     ),
///     // ...
///   ),
/// ));
/// ```
///
/// 注意把 [EffectListener] 放在 `MaterialApp.builder` 里，确保 `BuildContext` 能
/// `Navigator.of()` / `ScaffoldMessenger.of()`。
///
/// ### 2. Page 级——处理本页 VM 的业务 effect
///
/// ```dart
/// EffectListener(
///   source: OrderListVm,          // 只处理 OrderListVm 发出的 effect
///   onEffect: (ctx, e) {
///     if (e is OpenPaymentGateway) _openNative(e.orderId);
///   },
///   child: ...,
/// )
/// ```
///
/// `AppPageScaffold` 内部已经集成了这个 listener，一般不用业务手动写。
///
/// ## 派发顺序
///
/// 1. 若设置了 [source] 且 envelope.source 不匹配 → 忽略；
/// 2. 若 [handleDefaults] = true，先调 [DefaultEffectHandler.handle]：
///    - 返回 `true`：已处理，**短路** [onEffect]；
///    - 返回 `false`：未处理，继续传给 [onEffect]；
/// 3. 调用 [onEffect]。
class EffectListener extends ConsumerStatefulWidget {
  const EffectListener({
    super.key,
    required this.onEffect,
    required this.child,
    this.source,
    this.handleDefaults = true,
  });

  /// 业务 effect 回调。
  ///
  /// 当 [handleDefaults] = true 时，已被默认 handler 处理（返回 true）的 effect **不会**进入这里。
  final void Function(BuildContext ctx, Effect effect) onEffect;

  /// 只监听指定 VM 类型的 effect（按 `runtimeType` 比对）。
  ///
  /// `null` 表示监听全量。典型用法：
  ///   * 根级 listener → `null`（接所有内置 effect）；
  ///   * Page 级 listener → 传该页 VM 的 Type（只接本页业务 effect）。
  final Type? source;

  /// 是否在 [onEffect] 之前调 [DefaultEffectHandler]。默认 `true`。
  ///
  /// 若设为 `false`，业务回调会拿到所有 effect（包括内置的），用于"自己完全接管"的场景。
  final bool handleDefaults;

  final Widget child;

  @override
  ConsumerState<EffectListener> createState() => _EffectListenerState();
}

class _EffectListenerState extends ConsumerState<EffectListener> {
  StreamSubscription<EffectEnvelope>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(effectBusProvider).stream.listen(_onEnvelope);
  }

  void _onEnvelope(EffectEnvelope env) {
    if (!mounted) return;
    if (widget.source != null && env.source != widget.source) return;

    var handled = false;
    if (widget.handleDefaults) {
      final handler = ref.read(defaultEffectHandlerProvider);
      handled = handler.handle(context, env.payload);
    }
    if (!handled) widget.onEffect(context, env.payload);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
