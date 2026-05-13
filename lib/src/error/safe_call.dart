import 'dart:async';

import 'package:flutter/services.dart';

import 'app_exception.dart';

/// 所有 DataSource / Repository / ChannelClient 出口的统一异常归一器。
///
/// 用法：
/// ```dart
/// Future<T> myCall<T>() => safeApiCall(() async {
///   final result = await channel.invokeMethod(...);
///   return parse(result);
/// });
/// ```
///
/// 保证：
///   1. 业务主动抛出的 [AppException] 原样 rethrow；
///   2. [PlatformException] 按 code 映射到对应子类；
///   3. [TimeoutException] → [TimeoutAppException]；
///   4. 其他所有异常 → [UnknownException]（保留 stackTrace）。
Future<T> safeApiCall<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on AppException {
    rethrow;
  } on PlatformException catch (e, st) {
    throw _mapPlatformException(e, st);
  } on TimeoutException catch (e, st) {
    throw TimeoutAppException(
      message: e.message ?? 'Connection timeout',
      raw: e,
      stackTrace: st,
    );
  } catch (e, st) {
    throw UnknownException(
      message: e.toString(),
      raw: e,
      stackTrace: st,
    );
  }
}

AppException _mapPlatformException(PlatformException e, StackTrace st) {
  final code = int.tryParse(e.code) ?? -1;
  final msg = e.message ?? e.code;
  return switch (code) {
    401 => UnauthorizedException(message: msg, raw: e, stackTrace: st),
    403 => ForbiddenException(message: msg, raw: e, stackTrace: st),
    404 => NotFoundException(message: msg, raw: e, stackTrace: st),
    -2 => NetworkException(message: msg, raw: e, stackTrace: st),
    -3 => TimeoutAppException(message: msg, raw: e, stackTrace: st),
    -4 => CancelledException(message: msg, raw: e, stackTrace: st),
    _ => ServerException(code: code, message: msg, raw: e, stackTrace: st),
  };
}
