import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'default_effect_handler.dart';
import 'effect.dart';

/// 业务自定义 toast 实现的注入点。
///
/// 业务想用 BotToast / Fluttertoast / 自绘组件 → 在
/// [MaterialDefaultEffectHandler.toast] 里传一份。返回 `true` 表示已展示，
/// 返回 `false` 会让 [MaterialDefaultEffectHandler] 用 SnackBar 兜底。
typedef ToastShower = bool Function(
  BuildContext ctx,
  String message,
  ToastLevel level,
);

/// 业务自定义 dialog 的注册项。`EffectShowDialog(dialogId, args)` 进来
/// 按 `dialogId` 查表，命中就调对应 builder。返回的 Future 会被丢弃
/// （effect 本身是 fire-and-forget；要拿结果走 [EffectPop]）。
typedef DialogShower = Future<void> Function(
  BuildContext ctx,
  Object? args,
);

/// `flutter_spine` 内置的 `DefaultEffectHandler` 实现，绑定到
/// **Material 3 + go_router** 生态。覆盖 6 个内置 effect：
///
/// | Effect | 默认行为 |
/// |---|---|
/// | [EffectShowToast] / [EffectShowError] | `ScaffoldMessenger.showSnackBar`（业务可用 [toast] 替换） |
/// | [EffectNavigate] | `GoRouter.maybeOf(ctx)?.push(path, extra: args)`，无 GoRouter 时回退 `Navigator.pushNamed` |
/// | [EffectPop] | 同上回退顺序 |
/// | [EffectShowDialog] | 查 [dialogs] 表；内置 `'alert'` / `'confirm'` 两个 |
/// | [EffectHaptic] | `HapticFeedback.xxxImpact`（[hapticEnabled] 控制开关） |
/// | 业务自定义 | 一律返回 `false`，透传给 Page 级 `EffectListener.onEffect` |
///
/// 业务自定义 effect 必须自行用 `EffectListener.onEffect` 处理——本类**不会**
/// 试图猜测业务语义。
///
/// ## 用法
///
/// ```dart
/// // 1) 极简——零配置
/// FlutterSpineConfig(effectHandler: const MaterialDefaultEffectHandler())
///
/// // 2) 业务用 BotToast
/// FlutterSpineConfig(
///   effectHandler: MaterialDefaultEffectHandler(
///     toast: (ctx, msg, lvl) {
///       BotToast.showText(text: msg);
///       return true;
///     },
///   ),
/// )
///
/// // 3) 业务注册业务弹窗
/// FlutterSpineConfig(
///   effectHandler: MaterialDefaultEffectHandler(
///     dialogs: {
///       'order_confirm': (ctx, args) => showDialog(
///         context: ctx,
///         builder: (_) => OrderConfirmDialog(args as OrderArgs),
///       ),
///     },
///   ),
/// )
/// ```
///
/// `dialogs` 业务注册项**会覆盖**同名内置项——业务想自己接管 `'alert'` /
/// `'confirm'` 直接传同名 key。
class MaterialDefaultEffectHandler extends DefaultEffectHandler {
  const MaterialDefaultEffectHandler({
    this.toast,
    this.dialogs = const {},
    this.useGoRouter = true,
    this.hapticEnabled = true,
  });

  /// 业务自定义 toast 实现。`null` → 用 SnackBar 兜底。
  final ToastShower? toast;

  /// `dialogId` → builder 注册表。**会覆盖**内置 `'alert'` / `'confirm'`。
  final Map<String, DialogShower> dialogs;

  /// 路由策略：true → 优先 `GoRouter.maybeOf`，找不到回退 `Navigator`；
  /// false → 直接 `Navigator.pushNamed`。
  final bool useGoRouter;

  /// 是否处理 [EffectHaptic]。某些 app（无障碍 / 桌面端）想完全关掉震动 → 传 `false`。
  final bool hapticEnabled;

  @override
  bool handle(BuildContext ctx, Effect effect) => switch (effect) {
        EffectShowToast(:final message, :final level) =>
          _toast(ctx, message, level),
        EffectShowError(:final error) =>
          _toast(ctx, error.displayMessage, ToastLevel.error),
        EffectNavigate(:final path, :final args) => _navigate(ctx, path, args),
        EffectPop(:final result) => _pop(ctx, result),
        EffectShowDialog(:final dialogId, :final args) =>
          _dialog(ctx, dialogId, args),
        EffectHaptic(:final kind) => hapticEnabled ? _haptic(kind) : false,
        _ => false,
      };

  // ── toast ────────────────────────────────────────────────────────────────

  bool _toast(BuildContext ctx, String message, ToastLevel level) {
    if (toast != null) {
      final ok = toast!(ctx, message, level);
      if (ok) return true;
      // 业务 toast 返回 false → 走 SnackBar 兜底（不丢消息）
    }
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) return false;
    final scheme = Theme.of(ctx).colorScheme;
    final color = switch (level) {
      ToastLevel.success => Colors.green.shade600,
      ToastLevel.warn => Colors.orange.shade700,
      ToastLevel.error => scheme.error,
      ToastLevel.info => null,
    };
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
    return true;
  }

  // ── navigate / pop ───────────────────────────────────────────────────────

  bool _navigate(BuildContext ctx, String path, Object? args) {
    if (useGoRouter) {
      final router = GoRouter.maybeOf(ctx);
      if (router != null) {
        router.push(path, extra: args);
        return true;
      }
    }
    if (Navigator.maybeOf(ctx) != null) {
      Navigator.of(ctx).pushNamed(path, arguments: args);
      return true;
    }
    return false;
  }

  bool _pop(BuildContext ctx, Object? result) {
    if (useGoRouter) {
      final router = GoRouter.maybeOf(ctx);
      if (router != null && router.canPop()) {
        router.pop(result);
        return true;
      }
    }
    if (Navigator.canPop(ctx)) {
      Navigator.pop(ctx, result);
      return true;
    }
    return false;
  }

  // ── dialog ───────────────────────────────────────────────────────────────

  bool _dialog(BuildContext ctx, String dialogId, Object? args) {
    final shower = dialogs[dialogId] ?? _builtinDialogs[dialogId];
    if (shower == null) return false;
    // fire-and-forget；调用方拿结果走 EffectPop
    shower(ctx, args);
    return true;
  }

  static final Map<String, DialogShower> _builtinDialogs = {
    'alert': _builtinAlert,
    'confirm': _builtinConfirm,
  };

  /// 内置 `'alert'`：单按钮提示。args = `{title, body, ok}` 或 `null`。
  static Future<void> _builtinAlert(BuildContext ctx, Object? args) {
    final cfg = args is Map ? args : const <Object?, Object?>{};
    return showDialog<void>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(cfg['title']?.toString() ?? 'Alert'),
        content: Text(cfg['body']?.toString() ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(cfg['ok']?.toString() ?? 'OK'),
          ),
        ],
      ),
    );
  }

  /// 内置 `'confirm'`：双按钮确认。args = `{title, body, ok, cancel}`；
  /// pop 结果为 `bool`。
  static Future<void> _builtinConfirm(BuildContext ctx, Object? args) {
    final cfg = args is Map ? args : const <Object?, Object?>{};
    return showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(cfg['title']?.toString() ?? 'Confirm'),
        content: Text(cfg['body']?.toString() ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(cfg['cancel']?.toString() ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(cfg['ok']?.toString() ?? 'OK'),
          ),
        ],
      ),
    );
  }

  // ── haptic ───────────────────────────────────────────────────────────────

  bool _haptic(HapticKind kind) {
    switch (kind) {
      case HapticKind.light:
      case HapticKind.selection:
        HapticFeedback.lightImpact();
      case HapticKind.medium:
      case HapticKind.warn:
        HapticFeedback.mediumImpact();
      case HapticKind.heavy:
      case HapticKind.error:
      case HapticKind.success:
        HapticFeedback.heavyImpact();
    }
    return true;
  }
}
