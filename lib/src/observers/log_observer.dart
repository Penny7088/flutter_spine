import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';

/// Debug 模式挂载的 Provider 生命周期日志。
///
/// 用法：
/// ```dart
/// if (kDebugMode) LogObserver(logger: myLogger),
/// ```
class LogObserver extends ProviderObserver {
  const LogObserver({required this.logger});

  final AppLogger logger;

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    logger.debug('[+] ${_name(provider)}');
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (newValue is AsyncLoading) return;
    logger.debug('[~] ${_name(provider)}');
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    logger.debug('[-] ${_name(provider)}');
  }

  String _name(ProviderBase<Object?> p) =>
      p.name ?? p.runtimeType.toString();
}
