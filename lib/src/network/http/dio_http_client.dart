import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' show MediaType;

import '../../error/app_exception.dart';
import 'http_auth_refresh_interceptor.dart';
import 'http_client.dart';
import 'http_method.dart';
import 'http_response.dart';
import 'http_retry_interceptor.dart';
import 'multipart_file_part.dart';

/// `HttpClient` 的 Dio 实现。
///
/// 业务一般不直接 `new` 它——通过 `httpClientProvider` 注入即可。
/// 自定义 baseUrl / 拦截器：传 `dio` 参数（已配置好的实例）或 `config` 参数（让本类
/// 自己造）。
class DioHttpClient extends HttpClient {
  /// 用一个**已配置好的** \[dio\] 实例（你自己加好 baseUrl / interceptors / adapter）。
  /// 适合复杂场景或单元测试（注入 `MockHttpClientAdapter`）。
  DioHttpClient.fromDio(this._dio);

  /// 用一份 [DioHttpConfig] 让本类自动创建 Dio。常规用法。
  factory DioHttpClient.fromConfig(DioHttpConfig config) {
    final dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.connectTimeout,
      sendTimeout: config.sendTimeout,
      receiveTimeout: config.receiveTimeout,
      headers: {...config.defaultHeaders},
      contentType: config.defaultContentType,
      responseType: ResponseType.json,
    ));
    for (final i in config.interceptors) {
      dio.interceptors.add(i);
    }
    // AuthRefresh 必须排在业务 interceptors 之后、Retry 之前——
    // 这样 401 先被 refresh 处理，5xx / timeout 才进 retry。
    if (config.authRefresh != null) {
      dio.interceptors.add(
        AuthRefreshInterceptor(
          dio: dio,
          refreshToken: config.authRefresh!.refreshToken,
          headerName: config.authRefresh!.headerName,
          scheme: config.authRefresh!.scheme,
          skipPaths: config.authRefresh!.skipPaths,
          shouldRefresh: config.authRefresh!.shouldRefresh,
          logger: config.authRefresh!.logger,
        ),
      );
    }
    if (config.retry != null) {
      dio.interceptors.add(
        RetryInterceptor(
          dio: dio,
          maxRetries: config.retry!.maxRetries,
          baseDelay: config.retry!.baseDelay,
          maxDelay: config.retry!.maxDelay,
          jitterRatio: config.retry!.jitterRatio,
          idempotentMethods: config.retry!.idempotentMethods,
          shouldRetry: config.retry!.shouldRetry,
          logger: config.retry!.logger,
        ),
      );
    }
    return DioHttpClient.fromDio(dio);
  }

  final Dio _dio;

  /// 暴露底层 Dio——调试 / 临时绕过用。**业务代码尽量不要依赖**。
  Dio get rawDio => _dio;

  @override
  CancelToken createCancelToken() => CancelToken();

  @override
  void close() => _dio.close(force: true);

  @override
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
  }) async {
    final res = await requestRaw<T>(
      method: method,
      path: path,
      decoder: decoder,
      body: body,
      query: query,
      headers: headers,
      cancelToken: cancelToken,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      responseType: responseType,
    );
    return res.data;
  }

  @override
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
  }) async {
    if (files.isEmpty) {
      throw ArgumentError.value(files, 'files', 'must contain at least one file');
    }

    final formMap = <String, dynamic>{
      if (fields != null) ...fields,
    };
    // 同 field 多文件 → 用 List 让 Dio 生成多份 part。
    final filesByField = <String, List<MultipartFile>>{};
    for (final f in files) {
      filesByField.putIfAbsent(f.field, () => []).add(_toDioMultipartFile(f));
    }
    for (final entry in filesByField.entries) {
      formMap[entry.key] = entry.value.length == 1 ? entry.value.single : entry.value;
    }

    final formData = FormData.fromMap(formMap, ListFormat.multiCompatible);

    try {
      final dioRes = await _dio.request<dynamic>(
        path,
        data: formData,
        queryParameters: query,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: Options(
          method: method.name,
          headers: headers,
          sendTimeout: sendTimeout,
          receiveTimeout: receiveTimeout,
          // contentType 由 FormData 自动设为 multipart/form-data; boundary=...
        ),
      );

      final raw = dioRes.data;
      return decoder != null ? decoder(raw) : raw as T;
    } on DioException catch (e, st) {
      throw _mapDioException(e, st);
    } on AppException {
      rethrow;
    } catch (e, st) {
      throw UnknownException(message: e.toString(), raw: e, stackTrace: st);
    }
  }

  MultipartFile _toDioMultipartFile(MultipartFilePart f) {
    final mediaType = f.contentType == null ? null : MediaType.parse(f.contentType!);
    return switch (f.source) {
      MultipartSourcePath(:final path) => MultipartFile.fromFileSync(
          path,
          filename: f.filename,
          contentType: mediaType,
        ),
      MultipartSourceBytes(:final bytes) => MultipartFile.fromBytes(
          bytes,
          filename: f.filename,
          contentType: mediaType,
        ),
      MultipartSourceStream(:final stream, :final length) =>
        MultipartFile.fromStream(
          () => stream,
          length,
          filename: f.filename,
          contentType: mediaType,
        ),
    };
  }

  @override
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
  }) async {
    try {
      final dioRes = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(
          method: method.name,
          headers: headers,
          sendTimeout: sendTimeout,
          receiveTimeout: receiveTimeout,
          responseType: _toDioResponseType(responseType),
        ),
      );

      final raw = dioRes.data;
      final T data = decoder != null
          ? decoder(raw)
          // 没传 decoder：直接 cast；调用方自负责类型正确。
          : raw as T;

      return HttpResponse<T>(
        statusCode: dioRes.statusCode ?? 0,
        data: data,
        headers: dioRes.headers.map.map(
          (k, v) => MapEntry(k.toLowerCase(), v),
        ),
        requestPath: path,
      );
    } on DioException catch (e, st) {
      throw _mapDioException(e, st);
    } on AppException {
      rethrow;
    } catch (e, st) {
      throw UnknownException(message: e.toString(), raw: e, stackTrace: st);
    }
  }
}

ResponseType _toDioResponseType(HttpResponseType t) => switch (t) {
      HttpResponseType.json => ResponseType.json,
      HttpResponseType.text => ResponseType.plain,
      HttpResponseType.bytes => ResponseType.bytes,
    };

/// 把 [DioException] 归一到 [AppException]。**给 [DioHttpClient] 内部用，也供测试用**。
AppException mapDioExceptionToAppException(DioException e, [StackTrace? st]) =>
    _mapDioException(e, st ?? StackTrace.current);

AppException _mapDioException(DioException e, StackTrace st) {
  // Pass-through：interceptor 已经塞了语义化 AppException（例如
  // EnvelopeUnwrapInterceptor 用业务 code 包了 ServerException），原样抛出。
  final inner = e.error;
  if (inner is AppException) return inner;

  switch (e.type) {
    case DioExceptionType.cancel:
      return CancelledException(
        message: e.message ?? 'Request cancelled',
        raw: e,
        stackTrace: st,
      );

    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return TimeoutAppException(
        message: e.message ?? 'Connection timeout',
        raw: e,
        stackTrace: st,
      );

    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return NetworkException(
        message: e.message ?? 'Network error',
        raw: e,
        stackTrace: st,
      );

    case DioExceptionType.badResponse:
      final status = e.response?.statusCode ?? -1;
      final body = e.response?.data;
      final msg = _extractServerMessage(body) ?? e.message ?? 'HTTP $status';
      return switch (status) {
        401 => UnauthorizedException(message: msg, raw: e, stackTrace: st),
        403 => ForbiddenException(message: msg, raw: e, stackTrace: st),
        404 => NotFoundException(message: msg, raw: e, stackTrace: st),
        _ => ServerException(
            code: status,
            message: msg,
            raw: e,
            stackTrace: st,
          ),
      };

    case DioExceptionType.unknown:
      // dio 把底层 SocketException 等都丢这里——按 message 大致分一下。
      final innerMsg = inner?.toString() ?? e.message ?? 'Unknown error';
      if (innerMsg.contains('SocketException') ||
          innerMsg.contains('Failed host lookup') ||
          innerMsg.contains('Connection refused')) {
        return NetworkException(message: innerMsg, raw: e, stackTrace: st);
      }
      return UnknownException(message: innerMsg, raw: e, stackTrace: st);

    default:
      return UnknownException(
        message: e.message ?? 'Unknown HTTP error',
        raw: e,
        stackTrace: st,
      );
  }
}

/// 尝试从 server JSON 错误响应里抽出可读 message。
///
/// 兼容常见后端约定：`{message: ...}` / `{msg: ...}` / `{error: ...}` /
/// `{error: {message: ...}}`。
String? _extractServerMessage(Object? body) {
  if (body is! Map) return null;
  for (final key in const ['message', 'msg', 'error_description']) {
    final v = body[key];
    if (v is String && v.isNotEmpty) return v;
  }
  final err = body['error'];
  if (err is String && err.isNotEmpty) return err;
  if (err is Map) {
    final v = err['message'];
    if (v is String && v.isNotEmpty) return v;
  }
  return null;
}

/// `DioHttpClient.fromConfig` 的入参。
class DioHttpConfig {
  const DioHttpConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.sendTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.defaultHeaders = const {},
    this.defaultContentType = Headers.jsonContentType,
    this.interceptors = const [],
    this.authRefresh,
    this.retry,
  });

  final String baseUrl;
  final Duration connectTimeout;
  final Duration sendTimeout;
  final Duration receiveTimeout;
  final Map<String, String> defaultHeaders;
  final String defaultContentType;

  /// 业务自定义 / 内置（auth / logging / error）interceptor 列表，按顺序注册。
  final List<Interceptor> interceptors;

  /// 401 → refresh → retry 配置。`null` = 不挂 [AuthRefreshInterceptor]。
  /// 见 [AuthRefreshInterceptor] 的文档。
  final AuthRefreshConfig? authRefresh;

  /// 失败重试配置。`null` = 不挂 [RetryInterceptor]。
  /// 见 [RetryInterceptor] 的文档。
  final RetryConfig? retry;
}
