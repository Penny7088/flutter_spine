import 'package:dio/dio.dart';

import '../../../flutter_spine.dart';

/// 自动给请求挂上 `Authorization` 头。
///
/// tokenProvider 是个 sync 函数（不是 async）——保持 interceptor 同步链路简单。
/// 业务侧若需要异步取 token（比如刷新），请在 `tokenProvider` 内部走"读 cache"，
/// 真正的刷新逻辑通过另一条路径触发。
///
/// ## 用法
///
/// ```dart
/// AuthTokenInterceptor(
///   tokenProvider: () => ref.read(tokenStorageProvider).read(),
///   scheme: 'Bearer',                      // 默认；也可改 'Token'
///   headerName: 'Authorization',           // 默认
///   skipPaths: ['/auth/login', '/auth/refresh'],
/// )
/// ```
class AuthTokenInterceptor extends Interceptor {
  AuthTokenInterceptor({
    required String? Function() tokenProvider,
    String headerName = 'Authorization',
    String scheme = 'Bearer',
    List<String> skipPaths = const [],
  })  : _tokenProvider = tokenProvider,
        _headerName = headerName,
        _scheme = scheme,
        _skipPaths = skipPaths;

  final String? Function() _tokenProvider;
  final String _headerName;
  final String _scheme;
  final List<String> _skipPaths;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (_skipPaths.any(options.path.startsWith)) {
      handler.next(options);
      return;
    }
    final token = _tokenProvider();
    if (token != null && token.isNotEmpty) {
      final value = _scheme.isEmpty ? token : '$_scheme $token';
      options.headers[_headerName] = value;
    }
    handler.next(options);
  }
}

/// 统一记请求 / 响应日志。
///
/// 默认只记 method+path+status+耗时；如要 dump body，开 [logRequestBody]/[logResponseBody]
/// 但请只在 debug 包开（避免日志泄漏 PII）。
class HttpLoggingInterceptor extends Interceptor {
  HttpLoggingInterceptor({
    required AppLogger logger,
    this.logRequestBody = false,
    this.logResponseBody = false,
    this.maxBodyLogLength = 2048,
  }) : _logger = logger;

  final AppLogger _logger;
  final bool logRequestBody;
  final bool logResponseBody;
  final int maxBodyLogLength;

  static const _stopwatchKey = '_flutter_spine_http_log_stopwatch';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    options.extra[_stopwatchKey] = Stopwatch()..start();
    final buf = StringBuffer('→ ${options.method} ${options.uri}');
    if (logRequestBody && options.data != null) {
      buf.write('\n  body: ${_truncate(options.data)}');
    }
    _logger.debug(buf.toString());
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final ms = _elapsed(response.requestOptions);
    final buf = StringBuffer(
      '← ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.uri} (${ms}ms)',
    );
    if (logResponseBody && response.data != null) {
      buf.write('\n  body: ${_truncate(response.data)}');
    }
    _logger.debug(buf.toString());
    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    final ms = _elapsed(err.requestOptions);
    _logger.warn(
      '✗ ${err.response?.statusCode ?? '-'} ${err.requestOptions.method} '
      '${err.requestOptions.uri} (${ms}ms) — ${err.type.name}: '
      '${err.message ?? ''}',
    );
    handler.next(err);
  }

  int _elapsed(RequestOptions options) {
    final sw = options.extra[_stopwatchKey];
    if (sw is Stopwatch) {
      sw.stop();
      return sw.elapsedMilliseconds;
    }
    return 0;
  }

  String _truncate(Object? body) {
    final s = body.toString();
    return s.length <= maxBodyLogLength
        ? s
        : '${s.substring(0, maxBodyLogLength)}…(+${s.length - maxBodyLogLength})';
  }
}

/// 业务后端"约定 envelope"的解包拦截器（可选）。
///
/// 适合后端返回 `{code, message, data}` 这种统一结构：当 `code != successCode` 时
/// 把响应转成 [DioException]，让 [DioHttpClient] 翻成 `ServerException`。
///
/// 不需要这种 envelope 的项目可以**不**使用本拦截器。
///
/// ```dart
/// EnvelopeUnwrapInterceptor(
///   successCode: 0,
///   codeKey: 'code',
///   messageKey: 'message',
///   dataKey: 'data',
/// )
/// ```
class EnvelopeUnwrapInterceptor extends Interceptor {
  const EnvelopeUnwrapInterceptor({
    this.successCode = 0,
    this.codeKey = 'code',
    this.messageKey = 'message',
    this.dataKey = 'data',
  });

  final int successCode;
  final String codeKey;
  final String messageKey;
  final String dataKey;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final body = response.data;
    if (body is! Map) {
      handler.next(response);
      return;
    }

    final code = body[codeKey];
    final isOk = (code is int && code == successCode) ||
        (code is String && code == successCode.toString());

    if (!isOk) {
      final intCode = code is int
          ? code
          : (code is String ? int.tryParse(code) : null) ?? -1;
      final msg = body[messageKey]?.toString() ?? 'Server error: $code';
      // 把 AppException 塞到 DioException.error，DioHttpClient 的 mapper 会原样
      // 抛出而非二次包装。这样业务拿到的 ServerException.code 就是后端业务码。
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: ServerException(code: intCode, message: msg, raw: body),
        ),
      );
      return;
    }

    response.data = body[dataKey];
    handler.next(response);
  }
}
