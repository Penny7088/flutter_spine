import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('safeApiCall', () {
    test('returns value on success', () async {
      final result = await safeApiCall(() async => 42);
      expect(result, 42);
    });

    test('rethrows AppException unchanged', () async {
      const original = NetworkException(message: 'test network');
      expect(
        () => safeApiCall(() async => throw original),
        throwsA(same(original)),
      );
    });

    test('maps PlatformException(401) → UnauthorizedException', () async {
      expect(
        () => safeApiCall(
          () async => throw PlatformException(code: '401', message: 'unauth'),
        ),
        throwsA(isA<UnauthorizedException>().having((e) => e.code, 'code', 401)),
      );
    });

    test('maps PlatformException(403) → ForbiddenException', () async {
      expect(
        () => safeApiCall(
          () async => throw PlatformException(code: '403', message: 'forbidden'),
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('maps PlatformException(404) → NotFoundException', () async {
      expect(
        () => safeApiCall(
          () async => throw PlatformException(code: '404', message: 'not found'),
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('maps PlatformException(-2) → NetworkException', () async {
      expect(
        () => safeApiCall(
          () async => throw PlatformException(code: '-2', message: 'no net'),
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('maps PlatformException(-4) → CancelledException', () async {
      expect(
        () => safeApiCall(
          () async => throw PlatformException(code: '-4', message: 'cancel'),
        ),
        throwsA(isA<CancelledException>()),
      );
    });

    test('maps PlatformException(46100) → ServerException with correct code', () async {
      expect(
        () => safeApiCall(
          () async => throw PlatformException(code: '46100', message: 'biz error'),
        ),
        throwsA(
          isA<ServerException>().having((e) => e.code, 'code', 46100),
        ),
      );
    });

    test('maps TimeoutException → TimeoutAppException', () async {
      expect(
        () => safeApiCall(
          () async => throw TimeoutException('timed out'),
        ),
        throwsA(isA<TimeoutAppException>()),
      );
    });

    test('maps unknown Exception → UnknownException', () async {
      expect(
        () => safeApiCall(() async => throw Exception('something')),
        throwsA(isA<UnknownException>()),
      );
    });

    test('preserves stackTrace in mapped exception', () async {
      AppException? caught;
      try {
        await safeApiCall(
          () async => throw PlatformException(code: '500', message: 'err'),
        );
      } on AppException catch (e) {
        caught = e;
      }
      expect(caught.stackTrace, isNotNull);
    });
  });
}
