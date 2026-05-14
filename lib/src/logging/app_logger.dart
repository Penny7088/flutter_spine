import '../../flutter_spine.dart';

/// 日志抽象接口。业务包针对不同环境注入不同实现（prod vs debug vs test）。
///
/// 好处：
///   * Core 不强依赖任何 logger 库；
///   * 单测中可注入 [NoopAppLogger]，不产生控制台噪音；
///   * 后续切换日志库只需替换 [PrettyAppLogger]。
abstract class AppLogger {
  void debug(Object message, {Object? error, StackTrace? stackTrace});
  void info(Object message, {Object? error, StackTrace? stackTrace});
  void warn(Object message, {Object? error, StackTrace? stackTrace});
  void error(Object message, {Object? error, StackTrace? stackTrace});
}

/// 什么也不做的 logger，用于测试或需要静默的场景。
class NoopAppLogger implements AppLogger {
  const NoopAppLogger();

  @override
  void debug(Object message, {Object? error, StackTrace? stackTrace}) {}
  @override
  void info(Object message, {Object? error, StackTrace? stackTrace}) {}
  @override
  void warn(Object message, {Object? error, StackTrace? stackTrace}) {}
  @override
  void error(Object message, {Object? error, StackTrace? stackTrace}) {}
}
