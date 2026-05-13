/// 应用层统一异常。所有 DataSource / Repository / ChannelClient 出口只抛 [AppException]。
///
/// UI / Notifier 只需 `catch (AppException e)` 即可安全处理全部错误分支。
/// 其余异常由 `safeApiCall` 归一到 [UnknownException]。
///
/// 设计原则：
///   * sealed class 强制 switch 穷尽；
///   * 保留 [raw] / [stackTrace] 便于日志上报；
///   * code 统一 int：负值保留给本地语义，正值沿用 HTTP / 业务后端码。
sealed class AppException implements Exception {
  const AppException({
    required this.code,
    required this.message,
    this.raw,
    this.stackTrace,
  });

  final int code;
  final String message;
  final Object? raw;
  final StackTrace? stackTrace;

  /// UI 展示文本。子类可覆盖以做本地化映射。
  String get displayMessage => message;

  @override
  String toString() => '$runtimeType($code): $message';
}

/// 无网络 / DNS / Socket 级错误。
class NetworkException extends AppException {
  const NetworkException({
    String message = 'No internet connection',
    Object? raw,
    StackTrace? stackTrace,
  }) : super(code: -2, message: message, raw: raw, stackTrace: stackTrace);
}

/// 请求 / 连接超时。
class TimeoutAppException extends AppException {
  const TimeoutAppException({
    String message = 'Connection timeout',
    Object? raw,
    StackTrace? stackTrace,
  }) : super(code: -3, message: message, raw: raw, stackTrace: stackTrace);
}

/// 用户主动取消。通常不需要弹 toast，UI 层可 `switch` 过滤。
class CancelledException extends AppException {
  const CancelledException({
    String message = 'Cancelled',
    Object? raw,
    StackTrace? stackTrace,
  }) : super(code: -4, message: message, raw: raw, stackTrace: stackTrace);
}

/// 未登录 / Token 过期（HTTP 401）。上层可监听并跳转原生登录。
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    String message = 'Unauthorized',
    Object? raw,
    StackTrace? stackTrace,
  }) : super(code: 401, message: message, raw: raw, stackTrace: stackTrace);
}

/// 权限不足（HTTP 403）。
class ForbiddenException extends AppException {
  const ForbiddenException({
    String message = 'Forbidden',
    Object? raw,
    StackTrace? stackTrace,
  }) : super(code: 403, message: message, raw: raw, stackTrace: stackTrace);
}

/// 资源不存在（HTTP 404）。
class NotFoundException extends AppException {
  const NotFoundException({
    String message = 'Not found',
    Object? raw,
    StackTrace? stackTrace,
  }) : super(code: 404, message: message, raw: raw, stackTrace: stackTrace);
}

/// 服务端业务错误。[code] 是后端返回的业务码（如 45001、46100 等）。
class ServerException extends AppException {
  const ServerException({
    required super.code,
    required super.message,
    super.raw,
    super.stackTrace,
  });
}

/// 本地缓存（Hive / SharedPreferences）读写异常。
class CacheException extends AppException {
  const CacheException({
    String message = 'Cache error',
    Object? raw,
    StackTrace? stackTrace,
  }) : super(code: -10, message: message, raw: raw, stackTrace: stackTrace);
}

/// 兜底。不要在业务代码中主动抛出；由 [safeApiCall] 兜底使用。
class UnknownException extends AppException {
  const UnknownException({
    required super.message,
    super.raw,
    super.stackTrace,
  }) : super(code: -1);
}
