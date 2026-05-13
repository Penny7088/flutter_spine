import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'app_logger.dart';

/// 基于 `logger` 包的默认实现（PrettyPrinter）。
class PrettyAppLogger implements AppLogger {
  PrettyAppLogger({Logger? logger})
      : _logger = logger ??
            Logger(
              printer: PrettyPrinter(
                methodCount: 2,
                errorMethodCount: 8,
                lineLength: 120,
                colors: true,
                printEmojis: true,
                dateTimeFormat: DateTimeFormat.dateAndTime,
              ),
            );

  final Logger _logger;

  @override
  void debug(Object message, {Object? error, StackTrace? stackTrace}) =>
      _logger.d(message, error: error, stackTrace: stackTrace);

  @override
  void info(Object message, {Object? error, StackTrace? stackTrace}) =>
      _logger.i(message, error: error, stackTrace: stackTrace);

  @override
  void warn(Object message, {Object? error, StackTrace? stackTrace}) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  @override
  void error(Object message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}

/// 根级 logger provider。业务包在 [ProviderScope.overrides] 中替换为自己的实例。
///
/// ```dart
/// ProviderScope(
///   overrides: [appLoggerProvider.overrideWithValue(PrettyAppLogger())],
///   ...
/// )
/// ```
final appLoggerProvider = Provider<AppLogger>(
  (ref) => PrettyAppLogger(),
  name: 'appLoggerProvider',
);
