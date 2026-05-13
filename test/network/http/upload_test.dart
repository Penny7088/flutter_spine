import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter();

  String? lastContentType;
  Uint8List? lastBodyBytes;
  RequestOptions? lastOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    lastContentType = options.headers[Headers.contentTypeHeader]?.toString() ??
        options.contentType;

    if (requestStream != null) {
      final builder = BytesBuilder();
      await for (final chunk in requestStream) {
        builder.add(chunk);
      }
      lastBodyBytes = builder.takeBytes();
    }

    final json = utf8.encode(jsonEncode({'ok': true, 'url': '/u'}));
    return ResponseBody.fromBytes(
      json,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }
}

void main() {
  group('DioHttpClient.upload — multipart', () {
    test('fromBytes 上传：body 含 multipart 边界 + 文件名 + 字段', () async {
      final adapter = _CapturingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = DioHttpClient.fromDio(dio);

      final result = await client.upload<Map<String, dynamic>>(
        '/upload',
        files: [
          MultipartFilePart.fromBytes(
            field: 'avatar',
            bytes: utf8.encode('hello image bytes'),
            filename: 'me.png',
            contentType: 'image/png',
          ),
        ],
        fields: {'tag': 'avatar', 'uid': 42},
        decoder: (j) => j! as Map<String, dynamic>,
      );

      expect(result['ok'], true);
      expect(adapter.lastContentType, contains('multipart/form-data'));
      expect(adapter.lastContentType, contains('boundary='));

      final body = utf8.decode(adapter.lastBodyBytes!, allowMalformed: true);
      expect(body, contains('name="avatar"'));
      expect(body, contains('filename="me.png"'));
      expect(body.toLowerCase(), contains('content-type: image/png'));
      expect(body, contains('hello image bytes'));
      expect(body, contains('name="tag"'));
      expect(body, contains('avatar'));
      expect(body, contains('name="uid"'));
      expect(body, contains('42'));
    });

    test('fromStream 上传：流式来源也能正确组装', () async {
      final adapter = _CapturingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = DioHttpClient.fromDio(dio);

      final bytes = utf8.encode('streamed payload data');
      final stream = Stream<List<int>>.fromIterable([bytes]);

      await client.upload(
        '/upload',
        files: [
          MultipartFilePart.fromStream(
            field: 'video',
            stream: stream,
            length: bytes.length,
            filename: 'clip.mp4',
            contentType: 'video/mp4',
          ),
        ],
        decoder: (_) => null,
      );

      final body = utf8.decode(adapter.lastBodyBytes!, allowMalformed: true);
      expect(body, contains('name="video"'));
      expect(body, contains('filename="clip.mp4"'));
      expect(body.toLowerCase(), contains('content-type: video/mp4'));
      expect(body, contains('streamed payload data'));
    });

    test('同一 field 多文件 → 多个 multipart part', () async {
      final adapter = _CapturingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = DioHttpClient.fromDio(dio);

      await client.upload(
        '/upload',
        files: [
          MultipartFilePart.fromBytes(
            field: 'attachments',
            bytes: utf8.encode('payload-A'),
            filename: 'a.txt',
          ),
          MultipartFilePart.fromBytes(
            field: 'attachments',
            bytes: utf8.encode('payload-B'),
            filename: 'b.txt',
          ),
        ],
        decoder: (_) => null,
      );

      final body = utf8.decode(adapter.lastBodyBytes!, allowMalformed: true);
      expect('filename="a.txt"'.allMatches(body).length, 1);
      expect('filename="b.txt"'.allMatches(body).length, 1);
      expect('payload-A'.allMatches(body).length, 1);
      expect('payload-B'.allMatches(body).length, 1);
    });

    test('onSendProgress 至少回调一次（最终 sent == total）', () async {
      final adapter = _CapturingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = DioHttpClient.fromDio(dio);

      final calls = <List<int>>[];
      final big = Uint8List.fromList(List.filled(64 * 1024, 0x41));

      await client.upload(
        '/upload',
        files: [
          MultipartFilePart.fromBytes(
            field: 'file',
            bytes: big,
            filename: 'big.bin',
          ),
        ],
        onSendProgress: (s, t) => calls.add([s, t]),
        decoder: (_) => null,
      );

      expect(calls, isNotEmpty);
      final last = calls.last;
      expect(last[0], greaterThanOrEqualTo(big.length));
      expect(last[1], greaterThanOrEqualTo(big.length));
    });

    test('files 为空 → ArgumentError', () async {
      final dio = Dio()..httpClientAdapter = _CapturingAdapter();
      final client = DioHttpClient.fromDio(dio);

      expect(
        () => client.upload('/upload', files: const [], decoder: (_) => null),
        throwsArgumentError,
      );
    });

    test('错误归一：500 → ServerException（与 request 一致）', () async {
      final dio = Dio()
        ..httpClientAdapter = _ErrAdapter(500, '{"message":"boom"}');
      final client = DioHttpClient.fromDio(dio);

      await expectLater(
        () => client.upload(
          '/upload',
          files: const [
            MultipartFilePart.fromBytes(
              field: 'f',
              bytes: [1, 2, 3],
              filename: 'x.bin',
            ),
          ],
          decoder: (_) => null,
        ),
        throwsA(
          isA<ServerException>()
              .having((e) => e.code, 'code', 500)
              .having((e) => e.message, 'message', 'boom'),
        ),
      );
    });
  });
}

class _ErrAdapter implements HttpClientAdapter {
  _ErrAdapter(this.status, this.body);

  final int status;
  final String body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await for (final _ in requestStream) {
        // drain
      }
    }
    return ResponseBody.fromBytes(
      utf8.encode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
