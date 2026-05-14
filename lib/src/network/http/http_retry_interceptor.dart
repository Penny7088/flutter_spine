import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../flutter_spine.dart';

/// 请求重试拦截器（指数退避 + 抖动 + 幂等性判断）。
///
/// ## 默认行为
///
/// * 仅在以下情况重试：
///   - 连接 / 发送 / 接收**超时**（`DioExceptionType.connection/send/receiveTimeout`）；
///   - 连接错误（`DioExceptionType.connectionError`、`DioExceptionType.unknown` 含 SocketException）；
///   - HTTP **5xx**（`DioExceptionType.badResponse` 且 `statusCode >= 500`）；
///   - 当且仅当请求方法是**幂等**的（`GET` / `HEAD` / `PUT` / `DELETE` / `PATCH`）；
/// * 默认 [maxRetries]=3，间隔 `baseDelay * 2^n ± jitterRatio` 封顶 [maxDelay]；
/// * **不**重试：`401` / `4xx`（业务错） / 用户主动取消（`DioExceptionType.cancel`）；
/// * **不**重试：`POST`（默认认为非幂等）—— 确实需要时业务在请求 [Options.extra]
///   塞 `'flutter_core_retry_force_idempotent': true` 强制开启。
///
/// ## 用法
///
/// ```dart
/// DioHttpConfig(
///   baseUrl: 'https://api.example.com',
///   interceptors: [
///     // 注意：RetryInterceptor 需要持有 Dio 引用以便重发——所以改用
///     // [DioHttpConfig.retry] 字段，而不是手动 new。
///   ],
///   retry: const RetryConfig(maxRetries: 5, baseDelay: Duration(milliseconds: 200)),
/// )
/// ```
///
/// 想完全自定义 retry 谓词：传 [shouldRetry] 函数。返回 `true` 视为可重试。
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 5),
    this.jitterRatio = 0.2,
    Set<String>? idempotentMethods,
    this.shouldRetry,
    this.logger,
    math.Random? random,
  })  : _idempotent = idempotentMethods ??
            const {'GET', 'HEAD', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'},
        _random = random ?? math.Random();

  /// 用于重发请求的 Dio 实例（一般是 [DioHttpClient] 内部那个）。
  final Dio dio;

  /// 单次请求最多重试次数。0 = 关闭。
  final int maxRetries;

  /// 第一次失败后等多久重试。后续按 `pow(2, n) * base` 增长，封顶 [maxDelay]。
  final Duration baseDelay;
  final Duration maxDelay;

  /// 抖动比例 0~1。0.2 = ±20% 抖动，避免雪崩。
  final double jitterRatio;

  /// 视作"幂等"的方法名集合（大写）。POST 默认不在内。
  final Set<String> _idempotent;

  /// 自定义 retry 谓词。返回 `true` = 视为可重试；返回 `false` = 直接抛错。
  /// **优先级最高**——传了它则忽略默认的"幂等性 + 错误类型"判断。
  final bool Function(DioException error, RequestOptions options)? shouldRetry;

  /// 可选：日志（debug 输出"第 n 次重试，等 m ms"）。
  final AppLogger? logger;

  final math.Random _random;

  /// 业务端在 `Options.extra` 中塞这个 key=true 可强制把 POST 等也按幂等处理。
  static const forceIdempotentExtraKey =
      'flutter_core_retry_force_idempotent';

  /// 内部记录次数用，避免无限循环。
  static const _retryCountKey = '_flutter_spine_http_retry_count';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final opts = err.requestOptions;
    final count = (opts.extra[_retryCountKey] as int?) ?? 0;

    if (count >= maxRetries) {
      handler.next(err);
      return;
    }

    if (!_canRetry(err, opts)) {
      handler.next(err);
      return;
    }

    final delay = _computeDelay(count);
    logger?.debug(
      '[retry] ${opts.method} ${opts.path} '
      '(attempt ${count + 1}/$maxRetries) after ${delay.inMilliseconds}ms — '
      '${err.type.name}${err.response?.statusCode == null ? '' : ' ${err.response!.statusCode}'}',
    );
    await Future<void>.delayed(delay);

    if (opts.cancelToken?.isCancelled ?? false) {
      handler.next(err);
      return;
    }

    final newOpts = opts.copyWith(
      // copyWith 会深复制 extra，所以这里改是安全的。
      extra: {...opts.extra, _retryCountKey: count + 1},
    );

    try {
      final response = await dio.fetch<dynamic>(newOpts);
      handler.resolve(response);
    } on DioException catch (e) {
      // 让重试链继续走（再次 onError）。
      handler.next(e);
    }
  }

  bool _canRetry(DioException err, RequestOptions opts) {
    if (shouldRetry != null) return shouldRetry!(err, opts);

    if (err.type == DioExceptionType.cancel) return false;

    final method = opts.method.toUpperCase();
    final forceIdempotent =
        (opts.extra[forceIdempotentExtraKey] as bool?) ?? false;
    if (!forceIdempotent && !_idempotent.contains(method)) return false;

    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      DioExceptionType.badResponse =>
        (err.response?.statusCode ?? 0) >= 500,
      DioExceptionType.badCertificate => false,
      DioExceptionType.unknown => _looksLikeNetworkError(err),
      DioExceptionType.cancel => false,
    };
  }

  bool _looksLikeNetworkError(DioException err) {
    final msg = (err.error?.toString() ?? err.message ?? '').toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('failed host lookup');
  }

  Duration _computeDelay(int retryIndex) {
    final base = baseDelay.inMilliseconds * math.pow(2, retryIndex).toInt();
    final cap = maxDelay.inMilliseconds;
    final raw = math.min(base, cap);
    if (jitterRatio <= 0) return Duration(milliseconds: raw);
    final spread = (raw * jitterRatio).round();
    final delta = _random.nextInt(spread * 2 + 1) - spread;
    return Duration(milliseconds: math.max(0, raw + delta));
  }
}

/// 给 [DioHttpConfig.retry] 用的"声明式"配置——
/// [DioHttpClient.fromConfig] 拿到它后用本 dio 实例创建 [RetryInterceptor] 并注册。
class RetryConfig {
  const RetryConfig({
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 5),
    this.jitterRatio = 0.2,
    this.idempotentMethods,
    this.shouldRetry,
    this.logger,
  });

  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  final double jitterRatio;
  final Set<String>? idempotentMethods;
  final bool Function(DioException error, RequestOptions options)? shouldRetry;
  final AppLogger? logger;
}
