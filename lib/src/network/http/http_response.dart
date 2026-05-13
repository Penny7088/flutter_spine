import 'package:flutter/foundation.dart';

/// HTTP 响应包装。一般业务用不到——`HttpClient.request`/`get`/`post` 直接返回
/// 经 `decoder` 解码后的 `T`。需要拿到 status / headers / 原始 body 时，使用
/// `HttpClient.requestRaw` 或自定义 decoder 时入参。
@immutable
class HttpResponse<T> {
  const HttpResponse({
    required this.statusCode,
    required this.data,
    this.headers = const {},
    this.requestPath,
  });

  /// HTTP 状态码（200-599）。
  final int statusCode;

  /// 解码后的 body。
  final T data;

  /// 响应头（小写化）。
  final Map<String, List<String>> headers;

  /// 调试用：本次请求的目标 path。
  final String? requestPath;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  String? header(String name) {
    final list = headers[name.toLowerCase()];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  HttpResponse<R> map<R>(R Function(T data) f) => HttpResponse<R>(
        statusCode: statusCode,
        data: f(data),
        headers: headers,
        requestPath: requestPath,
      );
}
