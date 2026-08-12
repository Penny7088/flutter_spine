import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._steps);

  final List<_Step> _steps;
  int hits = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final step = _steps[math.min(hits, _steps.length - 1)];
    hits++;
    if (step.throwError != null) {
      // 把 SocketException 风格抛进 dio.unknown
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        error: step.throwError,
      );
    }
    return ResponseBody.fromBytes(
      utf8.encode(step.body ?? '{}'),
      step.status ?? 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _Step {
  _Step.ok([this.body = '{"ok":true}'])
      : status = 200,
        throwError = null;
  _Step.status(this.status)
      : body = '{"message":"err"}',
        throwError = null;
  _Step.throwSocket()
      : status = null,
        body = null,
        throwError = const SocketLikeException();

  final int? status;
  final String? body;
  final Object? throwError;
}

class SocketLikeException implements Exception {
  const SocketLikeException();
  @override
  String toString() => 'SocketException: Connection refused';
}

DioHttpClient _build(_ScriptedAdapter adapter, RetryConfig retry) {
  final dio = Dio(BaseOptions(baseUrl: 'http://x'));
  dio.interceptors.add(
    RetryInterceptor(
      dio: dio,
      maxRetries: retry.maxRetries,
      baseDelay: retry.baseDelay,
      maxDelay: retry.maxDelay,
      jitterRatio: retry.jitterRatio,
      idempotentMethods: retry.idempotentMethods,
    ),
  );
  dio.httpClientAdapter = adapter;
  return DioHttpClient.fromDio(dio);
}

void main() {
  group('RetryInterceptor — happy path', () {
    test('GET 500 → 重试 → 200 成功', () async {
      final adapter = _ScriptedAdapter([
        _Step.status(500),
        _Step.status(503),
        _Step.ok('{"data":"hi"}'),
      ]);
      final client = _build(
        adapter,
        const RetryConfig(
          maxRetries: 3,
          baseDelay: Duration(milliseconds: 1),
          jitterRatio: 0,
        ),
      );

      final res = await client.get<String>(
        '/x',
        decoder: (j) => (j! as Map)['data'] as String,
      );

      expect(res, 'hi');
      expect(adapter.hits, 3);
    });

    test('GET 网络错误 → 重试 → 200 成功', () async {
      final adapter = _ScriptedAdapter([
        _Step.throwSocket(),
        _Step.ok(),
      ]);
      final client = _build(
        adapter,
        const RetryConfig(
          maxRetries: 2,
          baseDelay: Duration(milliseconds: 1),
          jitterRatio: 0,
        ),
      );

      await client.get('/x', decoder: (_) => null);
      expect(adapter.hits, 2);
    });

    test('达到 maxRetries 仍失败 → 抛 ServerException', () async {
      final adapter = _ScriptedAdapter([
        _Step.status(502),
        _Step.status(502),
        _Step.status(502),
        _Step.status(502),
      ]);
      final client = _build(
        adapter,
        const RetryConfig(
          maxRetries: 2,
          baseDelay: Duration(milliseconds: 1),
          jitterRatio: 0,
        ),
      );

      await expectLater(
        () => client.get('/x'),
        throwsA(isA<ServerException>().having((e) => e.code, 'code', 502)),
      );
      // 1 次原始 + 2 次重试 = 3 次
      expect(adapter.hits, 3);
    });
  });

  group('RetryInterceptor — 不重试场景', () {
    test('POST 500 → 默认非幂等，不重试', () async {
      final adapter = _ScriptedAdapter([
        _Step.status(500),
      ]);
      final client = _build(
        adapter,
        const RetryConfig(
          maxRetries: 3,
          baseDelay: Duration(milliseconds: 1),
          jitterRatio: 0,
        ),
      );

      await expectLater(
        () => client.post('/x'),
        throwsA(isA<ServerException>()),
      );
      expect(adapter.hits, 1);
    });

    test('GET 401 → 业务错误不重试', () async {
      final adapter = _ScriptedAdapter([
        _Step.status(401),
      ]);
      final client = _build(
        adapter,
        const RetryConfig(
          maxRetries: 3,
          baseDelay: Duration(milliseconds: 1),
          jitterRatio: 0,
        ),
      );

      await expectLater(
        () => client.get('/x'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(adapter.hits, 1);
    });

    test('GET 404 → 不重试', () async {
      final adapter = _ScriptedAdapter([
        _Step.status(404),
      ]);
      final client = _build(
        adapter,
        const RetryConfig(maxRetries: 3, baseDelay: Duration(milliseconds: 1)),
      );

      await expectLater(
        () => client.get('/x'),
        throwsA(isA<NotFoundException>()),
      );
      expect(adapter.hits, 1);
    });
  });

  group('RetryInterceptor — 高级配置', () {
    test('forceIdempotentExtraKey → POST 也走重试', () async {
      final adapter = _ScriptedAdapter([
        _Step.status(500),
        _Step.ok(),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(
        RetryInterceptor(
          dio: dio,
          maxRetries: 2,
          baseDelay: const Duration(milliseconds: 1),
          jitterRatio: 0,
        ),
      );

      // 直接走 dio 接口附带 extra，模拟业务"明知不安全但需要重试 POST"的场景
      final res = await dio.request<dynamic>(
        '/y',
        options: Options(
          method: 'POST',
          extra: const {RetryInterceptor.forceIdempotentExtraKey: true},
        ),
      );
      expect(res.statusCode, 200);
      expect(adapter.hits, 2);
    });

    test('shouldRetry 自定义谓词覆盖默认行为', () async {
      final adapter = _ScriptedAdapter([
        _Step.status(404),
        _Step.ok(),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(
        RetryInterceptor(
          dio: dio,
          maxRetries: 2,
          baseDelay: const Duration(milliseconds: 1),
          jitterRatio: 0,
          // 把 404 也视为可重试（给业务一些奇葩后端用）
          shouldRetry: (e, _) => e.response?.statusCode == 404,
        ),
      );
      final client = DioHttpClient.fromDio(dio);

      await client.get('/x', decoder: (_) => null);
      expect(adapter.hits, 2);
    });

    test('cancelToken 已取消 → 等待后立即放弃重试', () async {
      final adapter = _ScriptedAdapter([
        _Step.status(500),
        _Step.ok(),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(
        RetryInterceptor(
          dio: dio,
          maxRetries: 2,
          baseDelay: const Duration(milliseconds: 50),
          jitterRatio: 0,
        ),
      );
      final client = DioHttpClient.fromDio(dio);

      final ct = client.createCancelToken();
      // 30ms 后取消 —— retry 等 50ms 醒来发现已 cancel，跳过
      Timer(const Duration(milliseconds: 30), () => ct.cancel('user'));

      await expectLater(
        () => client.get('/x', cancelToken: ct),
        throwsA(anyOf(
          isA<ServerException>(),
          isA<CancelledException>(),
        )),
      );
      expect(adapter.hits, 1);
    });
  });
}
