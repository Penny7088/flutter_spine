import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.handler});

  final FutureOr<ResponseBody> Function(RequestOptions opts) handler;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return await handler(options);
  }
}

ResponseBody _json(Map<String, dynamic> body, [int status = 200]) {
  return ResponseBody.fromBytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );
}

void main() {
  group('AuthRefreshInterceptor — happy path', () {
    test('401 → refreshToken → 用新 token 重发 → 成功', () async {
      String currentToken = 'old';
      final adapter = _Adapter(
        handler: (opts) {
          final auth = opts.headers['Authorization']?.toString();
          if (auth == 'Bearer old') {
            return _json({'message': 'expired'}, 401);
          }
          if (auth == 'Bearer new') {
            return _json({'data': 'ok'});
          }
          return _json({'message': 'no-auth'}, 401);
        },
      );

      final client = DioHttpClient.fromConfig(
        DioHttpConfig(
          baseUrl: 'http://x',
          interceptors: [
            AuthTokenInterceptor(tokenProvider: () => currentToken),
          ],
          authRefresh: AuthRefreshConfig(
            refreshToken: () async {
              currentToken = 'new';
              return 'new';
            },
          ),
        ),
      )..rawDio.httpClientAdapter = adapter;

      final res = await client.get<String>(
        '/me',
        decoder: (j) => (j! as Map)['data'] as String,
      );
      expect(res, 'ok');
      // 第一次：Bearer old → 401；第二次：Bearer new → 200
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests[0].headers['Authorization'], 'Bearer old');
      expect(adapter.requests[1].headers['Authorization'], 'Bearer new');
    });

    test('refreshToken 返回 null → 原 401 抛 UnauthorizedException', () async {
      final adapter = _Adapter(
        handler: (_) => _json({'message': 'expired'}, 401),
      );

      final client = DioHttpClient.fromConfig(
        DioHttpConfig(
          baseUrl: 'http://x',
          interceptors: [
            AuthTokenInterceptor(tokenProvider: () => 'old'),
          ],
          authRefresh: AuthRefreshConfig(
            refreshToken: () async => null,
          ),
        ),
      )..rawDio.httpClientAdapter = adapter;

      await expectLater(
        () => client.get('/me'),
        throwsA(isA<UnauthorizedException>()),
      );
      // 不应该有重试
      expect(adapter.requests, hasLength(1));
    });

    test('refreshToken 抛异常 → 原 401 抛 UnauthorizedException', () async {
      final adapter = _Adapter(
        handler: (_) => _json({'message': 'expired'}, 401),
      );

      final client = DioHttpClient.fromConfig(
        DioHttpConfig(
          baseUrl: 'http://x',
          interceptors: [
            AuthTokenInterceptor(tokenProvider: () => 'old'),
          ],
          authRefresh: AuthRefreshConfig(
            refreshToken: () async => throw const FormatException('boom'),
          ),
        ),
      )..rawDio.httpClientAdapter = adapter;

      await expectLater(
        () => client.get('/me'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(adapter.requests, hasLength(1));
    });

    test('skipPaths 命中的请求即便 401 也不触发 refresh', () async {
      var refreshCount = 0;
      final adapter = _Adapter(
        handler: (_) => _json({'message': 'bad creds'}, 401),
      );

      final client = DioHttpClient.fromConfig(
        DioHttpConfig(
          baseUrl: 'http://x',
          interceptors: [
            AuthTokenInterceptor(tokenProvider: () => 'old'),
          ],
          authRefresh: AuthRefreshConfig(
            refreshToken: () async {
              refreshCount++;
              return 'new';
            },
            skipPaths: ['/auth/'],
          ),
        ),
      )..rawDio.httpClientAdapter = adapter;

      await expectLater(
        () => client.post('/auth/login', body: {'u': 'a', 'p': 'b'}),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(refreshCount, 0);
      expect(adapter.requests, hasLength(1));
    });

    test('重试请求仍 401 → 不再 refresh，直接抛', () async {
      var refreshCount = 0;
      final adapter = _Adapter(
        handler: (_) => _json({'message': 'still bad'}, 401),
      );

      final client = DioHttpClient.fromConfig(
        DioHttpConfig(
          baseUrl: 'http://x',
          interceptors: [
            AuthTokenInterceptor(tokenProvider: () => 'old'),
          ],
          authRefresh: AuthRefreshConfig(
            refreshToken: () async {
              refreshCount++;
              return 'new';
            },
          ),
        ),
      )..rawDio.httpClientAdapter = adapter;

      await expectLater(
        () => client.get('/me'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(refreshCount, 1);
      // 1 次原始 + 1 次重试 = 2，不会无限循环
      expect(adapter.requests, hasLength(2));
    });
  });

  group('AuthRefreshInterceptor — 单飞', () {
    test('N 个并发 401 只触发一次 refresh，每个请求各自重试', () async {
      var refreshCount = 0;
      final completer = Completer<String>();

      final adapter = _Adapter(
        handler: (opts) async {
          final auth = opts.headers['Authorization']?.toString();
          if (auth == 'Bearer old') {
            return _json({'message': 'expired'}, 401);
          }
          if (auth == 'Bearer new') {
            return _json({'ok': true});
          }
          return _json({}, 401);
        },
      );

      String currentToken = 'old';
      final client = DioHttpClient.fromConfig(
        DioHttpConfig(
          baseUrl: 'http://x',
          interceptors: [
            AuthTokenInterceptor(tokenProvider: () => currentToken),
          ],
          authRefresh: AuthRefreshConfig(
            refreshToken: () async {
              refreshCount++;
              // 模拟 refresh 慢一点，让所有并发 401 都堆到 await 这一步
              final t = await completer.future;
              currentToken = t;
              return t;
            },
          ),
        ),
      )..rawDio.httpClientAdapter = adapter;

      // 并发起 5 个请求
      final futures = List.generate(
        5,
        (_) => client.get<bool>(
          '/me',
          decoder: (j) => ((j! as Map)['ok'] as bool?) ?? false,
        ),
      );

      // 给微任务一点时间到达 onError
      await Future<void>.delayed(const Duration(milliseconds: 20));
      completer.complete('new');

      final results = await Future.wait(futures);
      expect(results, everyElement(isTrue));
      expect(refreshCount, 1);
      // 每个请求 = 1 原始 + 1 重试 = 2，5 个 = 10
      expect(adapter.requests, hasLength(10));
    });
  });
}
