import 'dart:async';

import 'package:dio/dio.dart';

import '../../../flutter_spine.dart';

/// 业务侧实现"刷 token"的回调签名。
///
/// * 返回非空字符串：refresh 成功，新 token 会被本拦截器写回 `Authorization` 头并重发请求；
/// * 返回 `null` / 抛异常：refresh 失败，原 401 错误原样向上抛出。
typedef RefreshTokenCallback = Future<String?> Function();

/// `401 → refresh → retry` 拦截器（带**单飞**保证）。
///
/// ## 与 [AuthTokenInterceptor] 的关系
///
/// * [AuthTokenInterceptor]：**请求前**取静态 token 注入头；**不**懂 401。
/// * [AuthRefreshInterceptor]（本类）：**响应后** 401 处理；调业务的 [refreshToken]
///   拿新 token，写回 `Authorization` 头后重发原请求。
///
/// 推荐配合使用：
///
/// ```dart
/// // AuthRefreshInterceptor 需要持有 Dio 引用以便重发；
/// // 推荐通过 [DioHttpClient.fromDio] 自行组装 Dio 实例后注册：
/// final dio = Dio(BaseOptions(baseUrl: '...'));
/// dio.interceptors.addAll([
///   AuthTokenInterceptor(tokenProvider: () => session.token),
///   AuthRefreshInterceptor(
///     dio: dio,
///     refreshToken: () => ref.read(authRepoProvider).refresh(),
///     skipPaths: ['/auth/login', '/auth/refresh'],
///   ),
/// ]);
/// final client = DioHttpClient.fromDio(dio);
/// ```
///
/// ## 单飞保证
///
/// 多个并发请求同时拿到 401 时，只有**第一个**会调 [refreshToken]；
/// 其他请求 `await` 同一个 future，refresh 完成后用同一份 new token 各自重发。
/// **不会**出现 N 个并发 401 → N 次刷 token 的雪崩。
///
/// ## 失败语义
///
/// * `refreshToken()` 返回 `null` / 空字符串 → 视为"refresh 失败，要求重新登录"，
///   原 401 [DioException] 被原样向上抛（`DioHttpClient` → `UnauthorizedException`）；
/// * `refreshToken()` 自己抛异常 → 同上，原 401 抛出（refresh 自己抛的异常会进 \[logger.warn\]）；
/// * 重发后请求**仍然 401** → 直接抛出该 401（避免无限循环；本拦截器对一次请求最多只重试一次）。
class AuthRefreshInterceptor extends Interceptor {
  AuthRefreshInterceptor({
    required this.dio,
    required this.refreshToken,
    String headerName = 'Authorization',
    String scheme = 'Bearer',
    List<String> skipPaths = const [],
    bool Function(DioException error)? shouldRefresh,
    this.logger,
  })  : _headerName = headerName,
        _scheme = scheme,
        _skipPaths = skipPaths,
        _shouldRefresh = shouldRefresh;

  /// 用来重发原请求的 Dio 实例。
  final Dio dio;

  /// 业务的"刷 token"回调。返回新 token 字符串或 `null`（失败）。
  final RefreshTokenCallback refreshToken;

  final String _headerName;
  final String _scheme;
  final List<String> _skipPaths;

  /// 自定义谓词：返回 `true` 才触发 refresh 流程。默认 `statusCode == 401`。
  /// 业务想把 419 / 自定义 code 等也走 refresh 链路时传它。
  final bool Function(DioException error)? _shouldRefresh;

  final AppLogger? logger;

  /// 同一请求最多 refresh+重试一次（防无限循环）。
  static const _retriedKey = '_flutter_spine_http_auth_retried';

  /// 单飞 future。多个并发 401 共用此 future，refresh 完成后一起继续。
  Future<String?>? _inflightRefresh;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final opts = err.requestOptions;

    if (_skipPaths.any(opts.path.startsWith) ||
        (opts.extra[_retriedKey] as bool?) == true ||
        !_shouldTrigger(err)) {
      handler.next(err);
      return;
    }

    String? newToken;
    try {
      newToken = await (_inflightRefresh ??=
          refreshToken().whenComplete(() => _inflightRefresh = null));
    } catch (e, st) {
      logger?.warn(
        'AuthRefreshInterceptor: refreshToken() threw $e',
        error: e,
        stackTrace: st,
      );
      handler.next(err);
      return;
    }

    if (newToken == null || newToken.isEmpty) {
      logger?.debug(
        'AuthRefreshInterceptor: refreshToken returned null/empty, '
        'propagating original 401',
      );
      handler.next(err);
      return;
    }

    final retriedExtra = {...opts.extra, _retriedKey: true};
    final retriedHeaders = {...opts.headers};
    retriedHeaders[_headerName] =
        _scheme.isEmpty ? newToken : '$_scheme $newToken';

    final newOpts = opts.copyWith(
      extra: retriedExtra,
      headers: retriedHeaders,
    );

    try {
      final response = await dio.fetch<dynamic>(newOpts);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _shouldTrigger(DioException err) {
    final pred = _shouldRefresh;
    if (pred != null) return pred(err);
    return err.response?.statusCode == 401;
  }
}

/// 给 [AuthRefreshInterceptor] 用的"声明式"配置。
class AuthRefreshConfig {
  const AuthRefreshConfig({
    required this.refreshToken,
    this.headerName = 'Authorization',
    this.scheme = 'Bearer',
    this.skipPaths = const [],
    this.shouldRefresh,
    this.logger,
  });

  final RefreshTokenCallback refreshToken;
  final String headerName;
  final String scheme;
  final List<String> skipPaths;
  final bool Function(DioException error)? shouldRefresh;
  final AppLogger? logger;
}
