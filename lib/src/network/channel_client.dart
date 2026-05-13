import 'package:flutter/services.dart';

import '../error/app_exception.dart';
import '../error/safe_call.dart';

/// [MethodChannel] 的薄封装。职责仅限于：
///   1. 发起调用；
///   2. 通过 [safeApiCall] 把 [PlatformException] 归一到 [AppException]；
///   3. 可选的结果解码。
///
/// 不做：toast、缓存、sys_lang 拼装、业务 code 校验——这些属于 DataSource 层。
class ChannelClient {
  const ChannelClient(this._channel);

  final MethodChannel _channel;

  /// 调用并返回 `Map<String, dynamic>`。
  /// 返回 null 或非 Map 时抛 [UnknownException]。
  Future<Map<String, dynamic>> invokeMap(
    String method, [
    Map<String, dynamic>? args,
  ]) =>
      safeApiCall(() async {
        final res = await _channel.invokeMethod<dynamic>(method, args);
        if (res == null) {
          throw const UnknownException(message: 'channel returned null');
        }
        return Map<String, dynamic>.from(res as Map);
      });

  /// 调用并用 [decoder] 将原始返回值转成目标类型。
  Future<T> invokeAs<T>(
    String method,
    T Function(Object? raw) decoder, [
    Map<String, dynamic>? args,
  ]) =>
      safeApiCall(() async {
        final res = await _channel.invokeMethod<dynamic>(method, args);
        return decoder(res);
      });

  /// fire-and-forget 调用（无需关注返回值）。
  Future<void> invokeVoid(
    String method, [
    Map<String, dynamic>? args,
  ]) =>
      safeApiCall(
        () => _channel.invokeMethod<dynamic>(method, args),
      );
}
