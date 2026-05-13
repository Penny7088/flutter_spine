import 'package:dio/dio.dart' show CancelToken;

import '../../error/app_exception.dart';
import 'http_method.dart';
import 'http_response.dart';
import 'multipart_file_part.dart';

export 'package:dio/dio.dart' show CancelToken;

/// 上传进度回调。`sent` / `total` 为字节数；`total = -1` 时表示未知大小。
typedef UploadProgressCallback = void Function(int sent, int total);

/// 用于解码 HTTP 响应 body 的回调签名。
///
/// 入参 `raw` 是 `dio` 已解码完成的 JSON 对象（通常是 `Map<String, dynamic>` 或
/// `List<dynamic>`），decoder 负责把它映射成业务模型 `T`。
typedef HttpDecoder<T> = T Function(Object? raw);

/// HTTP 客户端抽象。
///
/// 所有方法的失败一律转成 [AppException] 抛出（业务侧可直接用 `safeApiCall` 风格
/// 写法 / `Result.toResult()` 转 [Result]）。
///
/// ## 用法
///
/// ```dart
/// final user = await httpClient.get<User>(
///   '/users/me',
///   decoder: (j) => User.fromJson(j! as Map<String, dynamic>),
/// );
///
/// // POST + body
/// final order = await httpClient.post<Order>(
///   '/orders',
///   body: {'sku': 'a', 'qty': 2},
///   decoder: (j) => Order.fromJson(j! as Map<String, dynamic>),
/// );
///
/// // 取消
/// final ct = httpClient.createCancelToken();
/// final f = httpClient.get('/long', cancelToken: ct);
/// ct.cancel();           // → 抛 CancelledException
///
/// // 拿原始 response（含 status / headers）
/// final res = await httpClient.requestRaw(
///   method: HttpMethod.get,
///   path: '/files/123',
///   responseType: HttpResponseType.bytes,
/// );
/// ```
///
/// ## 实现注意
///
/// * 实现类（如 [DioHttpClient]）必须保证：所有非 [AppException] 异常归一到
///   [UnknownException]；网络/超时/取消/HTTP 错误码映射到对应 [AppException] 子类；
/// * 多次实例化是允许的（不同 baseUrl / 不同 interceptor 链），但**通常**整个 app
///   只需一个 `httpClientProvider` 注入的实例。
abstract class HttpClient {
  /// 通用入口。其他便捷方法都委托到这里。
  Future<T> request<T>({
    required HttpMethod method,
    required String path,
    HttpDecoder<T>? decoder,
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    HttpResponseType responseType = HttpResponseType.json,
  });

  /// 拿到完整 [HttpResponse]（含 status code / headers）。decoder 不传时 `data` 是
  /// 解码后的 raw（Map/List/String/bytes 取决于 [responseType]）。
  Future<HttpResponse<T>> requestRaw<T>({
    required HttpMethod method,
    required String path,
    HttpDecoder<T>? decoder,
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    HttpResponseType responseType = HttpResponseType.json,
  });

  Future<T> get<T>(
    String path, {
    HttpDecoder<T>? decoder,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) =>
      request<T>(
        method: HttpMethod.get,
        path: path,
        decoder: decoder,
        query: query,
        headers: headers,
        cancelToken: cancelToken,
      );

  Future<T> post<T>(
    String path, {
    HttpDecoder<T>? decoder,
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) =>
      request<T>(
        method: HttpMethod.post,
        path: path,
        decoder: decoder,
        body: body,
        query: query,
        headers: headers,
        cancelToken: cancelToken,
      );

  Future<T> put<T>(
    String path, {
    HttpDecoder<T>? decoder,
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) =>
      request<T>(
        method: HttpMethod.put,
        path: path,
        decoder: decoder,
        body: body,
        query: query,
        headers: headers,
        cancelToken: cancelToken,
      );

  Future<T> patch<T>(
    String path, {
    HttpDecoder<T>? decoder,
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) =>
      request<T>(
        method: HttpMethod.patch,
        path: path,
        decoder: decoder,
        body: body,
        query: query,
        headers: headers,
        cancelToken: cancelToken,
      );

  Future<T> delete<T>(
    String path, {
    HttpDecoder<T>? decoder,
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) =>
      request<T>(
        method: HttpMethod.delete,
        path: path,
        decoder: decoder,
        body: body,
        query: query,
        headers: headers,
        cancelToken: cancelToken,
      );

  /// 上传 multipart 表单（含一个或多个文件 + 普通字段）。
  ///
  /// * [files]：至少传一个 [MultipartFilePart]——三种来源任选（path / bytes / stream）；
  /// * [fields]：表单的普通字段（非文件），值会被 `toString()` 然后编码；
  /// * [onSendProgress]：进度回调，参数为 `(已发送字节, 总字节)`，整段流程**多次回调**；
  /// * [method]：默认 [HttpMethod.post]，少数后端用 PUT 上传；
  /// * 其他参数语义同 [request]。
  ///
  /// ```dart
  /// final result = await httpClient.upload<UploadResult>(
  ///   '/files',
  ///   files: [
  ///     MultipartFilePart.fromPath(field: 'file', filePath: '/sd/a.png'),
  ///   ],
  ///   fields: {'tag': 'avatar'},
  ///   onSendProgress: (sent, total) => debugPrint('${sent * 100 ~/ total}%'),
  ///   decoder: (j) => UploadResult.fromJson(j! as Map<String, dynamic>),
  /// );
  /// ```
  ///
  /// 错误归一同 [request]：网络/超时/取消/HTTP 错误码 → 对应 [AppException] 子类。
  Future<T> upload<T>(
    String path, {
    required List<MultipartFilePart> files,
    HttpDecoder<T>? decoder,
    Map<String, dynamic>? fields,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    HttpMethod method = HttpMethod.post,
    UploadProgressCallback? onSendProgress,
    CancelToken? cancelToken,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  });

  /// 创建一个 [CancelToken]。业务取消请求时 `ct.cancel()` 即可。
  CancelToken createCancelToken();

  /// 关闭底层连接池。一般 app 全局单例不需要主动调；测试 / 多 host 切换时用。
  void close();
}

/// 期望服务端返回什么类型。
enum HttpResponseType {
  /// 解析为 JSON 对象（Map/List/String/null）——推荐默认。
  json,

  /// 不解析，body 作为 [String] 原文返回。
  text,

  /// 不解析，body 作为 `List<int>` 字节流返回——下载文件常用。
  bytes,
}
