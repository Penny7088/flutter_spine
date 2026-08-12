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

/// 流式 HTTP 响应——用于 SSE / 大文件下载 / 长连接 push。
///
/// ```dart
/// final res = await http.requestStream(method: HttpMethod.get, path: '/events');
/// await for (final chunk in res.stream) {
///   // SSE 事件解析 / 写入文件 / ...
/// }
/// ```
class StreamedHttpResponse {
  const StreamedHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.stream,
    this.requestPath,
  });

  final int statusCode;
  final Map<String, List<String>> headers;
  final Stream<List<int>> stream;
  final String? requestPath;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  String? header(String name) {
    final list = headers[name.toLowerCase()];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }
}
