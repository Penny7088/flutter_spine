import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用 Dio 自带的 HttpClientAdapter 接口手写一个 fake，避免真实网络。
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      await handler(options);
}

ResponseBody _jsonBody(Map<String, dynamic> json, [int status = 200]) {
  final bytes = utf8.encode(jsonEncode(json));
  return ResponseBody.fromBytes(
    bytes,
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );
}

void main() {
  group('DioHttpClient — happy path', () {
    test('GET decode 到业务模型', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(
          (o) => _jsonBody({'id': 1, 'name': 'Alice'}),
        );
      final client = DioHttpClient.fromDio(dio);

      final user = await client.get<_User>(
        '/users/1',
        decoder: (j) => _User.fromJson(j! as Map<String, dynamic>),
      );

      expect(user.id, 1);
      expect(user.name, 'Alice');
    });

    test('POST 把 body 编码成 JSON 发出', () async {
      Object? capturedBody;
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((o) {
          capturedBody = o.data;
          return _jsonBody({'ok': true});
        });
      final client = DioHttpClient.fromDio(dio);

      await client.post<Map<String, dynamic>>(
        '/orders',
        body: {'sku': 'a', 'qty': 2},
        decoder: (j) => j! as Map<String, dynamic>,
      );

      expect(capturedBody, {'sku': 'a', 'qty': 2});
    });

    test('requestRaw 暴露 status / headers', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((o) => _jsonBody({'k': 'v'}, 201));
      final client = DioHttpClient.fromDio(dio);

      final res = await client.requestRaw<Map<String, dynamic>>(
        method: HttpMethod.get,
        path: '/x',
        decoder: (j) => j! as Map<String, dynamic>,
      );

      expect(res.statusCode, 201);
      expect(res.isSuccess, isTrue);
      expect(res.header('content-type'), contains('json'));
    });
  });

  group('DioHttpClient — 错误归一', () {
    test('401 → UnauthorizedException + 抽 server message', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(
          (o) => _jsonBody({'message': 'token expired'}, 401),
        );
      final client = DioHttpClient.fromDio(dio);

      await expectLater(
        () => client.get('/me'),
        throwsA(
          isA<UnauthorizedException>()
              .having((e) => e.code, 'code', 401)
              .having((e) => e.message, 'message', 'token expired'),
        ),
      );
    });

    test('403 → ForbiddenException', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(
          (o) => _jsonBody({'message': 'no'}, 403),
        );
      final client = DioHttpClient.fromDio(dio);

      await expectLater(
        () => client.get('/x'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('404 → NotFoundException', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((o) => _jsonBody({}, 404));
      final client = DioHttpClient.fromDio(dio);

      await expectLater(
        () => client.get('/missing'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('500 → ServerException(code: 500)', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(
          (o) => _jsonBody({'message': 'boom'}, 500),
        );
      final client = DioHttpClient.fromDio(dio);

      await expectLater(
        () => client.get('/x'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.code, 'code', 500)
              .having((e) => e.message, 'message', 'boom'),
        ),
      );
    });

    test('已取消的 token → CancelledException', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((o) => _jsonBody({}));
      final client = DioHttpClient.fromDio(dio);
      final ct = client.createCancelToken()..cancel('manual');

      await expectLater(
        () => client.get('/x', cancelToken: ct),
        throwsA(isA<CancelledException>()),
      );
    });

    test('extractServerMessage 兼容 {error: {message: ...}} 嵌套', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(
          (o) => _jsonBody(
              {'error': {'message': 'nested fail'}}, 422),
        );
      final client = DioHttpClient.fromDio(dio);

      await expectLater(
        () => client.get('/x'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'nested fail'),
        ),
      );
    });
  });

  group('AuthTokenInterceptor', () {
    test('注入 Authorization 头（默认 Bearer）', () async {
      String? captured;
      final dio = Dio()
        ..interceptors.add(
          AuthTokenInterceptor(tokenProvider: () => 'abc123'),
        )
        ..httpClientAdapter = _FakeAdapter((o) {
          captured = o.headers['Authorization']?.toString();
          return _jsonBody({});
        });
      final client = DioHttpClient.fromDio(dio);

      await client.get('/me', decoder: (_) => null);
      expect(captured, 'Bearer abc123');
    });

    test('skipPaths 跳过指定前缀', () async {
      String? captured;
      final dio = Dio()
        ..interceptors.add(
          AuthTokenInterceptor(
            tokenProvider: () => 'abc',
            skipPaths: ['/auth/'],
          ),
        )
        ..httpClientAdapter = _FakeAdapter((o) {
          captured = o.headers['Authorization']?.toString();
          return _jsonBody({});
        });
      final client = DioHttpClient.fromDio(dio);

      await client.get('/auth/login', decoder: (_) => null);
      expect(captured, isNull);
    });

    test('token 为 null 时不加头', () async {
      String? captured = 'pre';
      final dio = Dio()
        ..interceptors.add(
          AuthTokenInterceptor(tokenProvider: () => null),
        )
        ..httpClientAdapter = _FakeAdapter((o) {
          captured = o.headers['Authorization']?.toString();
          return _jsonBody({});
        });
      final client = DioHttpClient.fromDio(dio);

      await client.get('/x', decoder: (_) => null);
      expect(captured, isNull);
    });
  });

  group('EnvelopeUnwrapInterceptor', () {
    test('code=0 → unwrap data 字段', () async {
      final dio = Dio()
        ..interceptors.add(const EnvelopeUnwrapInterceptor())
        ..httpClientAdapter = _FakeAdapter(
          (o) => _jsonBody({'code': 0, 'data': {'name': 'x'}}),
        );
      final client = DioHttpClient.fromDio(dio);

      final res = await client.get<Map<String, dynamic>>(
        '/x',
        decoder: (j) => j! as Map<String, dynamic>,
      );
      expect(res, {'name': 'x'});
    });

    test('code!=0 → ServerException(code = 业务码)', () async {
      final dio = Dio()
        ..interceptors.add(const EnvelopeUnwrapInterceptor())
        ..httpClientAdapter = _FakeAdapter(
          (o) =>
              _jsonBody({'code': 45001, 'message': 'no balance', 'data': null}),
        );
      final client = DioHttpClient.fromDio(dio);

      await expectLater(
        () => client.get('/buy'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.code, 'code', 45001)
              .having((e) => e.message, 'message', 'no balance'),
        ),
      );
    });
  });
}

class _User {
  _User({required this.id, required this.name});
  factory _User.fromJson(Map<String, dynamic> j) =>
      _User(id: j['id'] as int, name: j['name'] as String);
  final int id;
  final String name;
}
