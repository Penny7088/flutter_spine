import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/app_exception.dart';
import '../logging/app_logger.dart';

/// toast 回调类型。业务包传入 `BotToast.showText` 或其他实现。
/// Core 不依赖任何 toast 库。
typedef ErrorToastCallback = void Function(String message);

/// 决定是否对某个 Provider 的错误弹 toast 的谓词。
/// 返回 false 时只记日志，不弹。
typedef ShouldShowToast = bool Function(
  ProviderBase<Object?> provider,
  Object error,
);

/// 统一的 Provider 错误处理器。
///
/// * 所有 Provider 失败时记录错误日志（通过注入的 [AppLogger]）；
/// * 若提供了 [onToast] 且 [shouldShowToast] 返回 true，则弹出 toast；
/// * [CancelledException] 默认被 [shouldShowToast] 过滤，不弹 toast。
///
/// 用法：
/// ```dart
/// runApp(ProviderScope(
///   observers: [
///     ErrorObserver(
///       logger: PrettyAppLogger(),
///       onToast: BotToast.showText,
///     ),
///   ],
///   child: const App(),
/// ));
/// ```
class ErrorObserver extends ProviderObserver {
  const ErrorObserver({
    required this.logger,
    this.onToast,
    this.shouldShowToast,
  });

  final AppLogger logger;
  final ErrorToastCallback? onToast;
  final ShouldShowToast? shouldShowToast;

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    final name = provider.name ?? provider.runtimeType.toString();
    logger.error('[Provider $name] $error', error: error, stackTrace: stackTrace);

    if (onToast == null) return;

    final shouldToast = shouldShowToast?.call(provider, error) ??
        _defaultShouldToast(provider, error);
    if (!shouldToast) return;

    final msg = switch (error) {
      AppException e => e.displayMessage,
      _ => error.toString(),
    };
    if (msg.isNotEmpty) onToast!(msg);
  }

  static bool _defaultShouldToast(ProviderBase<Object?> _, Object error) {
    return error is! CancelledException;
  }
}
