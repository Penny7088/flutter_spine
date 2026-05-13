import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Ok / Err 构造 + isOk / isErr', () {
      const ok = Ok<int>(42);
      const err = Err<int>(UnknownException(message: 'x'));

      expect(ok.isOk, isTrue);
      expect(ok.isErr, isFalse);
      expect(err.isOk, isFalse);
      expect(err.isErr, isTrue);
    });

    test('valueOrNull / errorOrNull', () {
      const ok = Ok<int>(7);
      const err = Err<int>(UnknownException(message: 'e'));

      expect(ok.valueOrNull, 7);
      expect(ok.errorOrNull, isNull);
      expect(err.valueOrNull, isNull);
      expect(err.errorOrNull, isA<UnknownException>());
    });

    test('fold 正确分流', () {
      const ok = Ok<int>(3);
      const err = Err<int>(UnknownException(message: 'boom'));

      expect(ok.fold((v) => 'ok:$v', (e) => 'err'), 'ok:3');
      expect(err.fold((v) => 'ok', (e) => 'err:${e.message}'), 'err:boom');
    });

    test('Ok / Err 相等性', () {
      const a = Ok<int>(1);
      const b = Ok<int>(1);
      const c = Ok<int>(2);
      expect(a, b);
      expect(a == c, isFalse);

      // const 规范化后两个 const AppException 是同一实例，所以 Err 相等。
      const e1 = Err<int>(UnknownException(message: 'x'));
      const e2 = Err<int>(UnknownException(message: 'x'));
      expect(e1, e2);

      // 不同 error 实例（通过不同 message 构造）走 error.== 比较，
      // AppException 没有 override ==，引用不同 → Err 也不等。
      final e3 = Err<int>(UnknownException(message: 'y${DateTime.now()}'));
      expect(e1 == e3, isFalse);
    });
  });

  group('FutureResultX.toResult', () {
    test('成功 → Ok', () async {
      final r = await Future.value(10).toResult();
      expect(r, isA<Ok<int>>());
      expect(r.valueOrNull, 10);
    });

    test('AppException → Err 保留原异常', () async {
      Future<int> failing() async {
        throw const NotFoundException(message: 'no such');
      }

      final r = await failing().toResult();
      expect(r, isA<Err<int>>());
      expect(r.errorOrNull, isA<NotFoundException>());
      expect(r.errorOrNull!.message, 'no such');
    });

    test('非 AppException → Err(UnknownException) 保留 raw + stackTrace', () async {
      Future<int> failing() async {
        throw const FormatException('bad format');
      }

      final r = await failing().toResult();
      expect(r, isA<Err<int>>());
      final err = r.errorOrNull!;
      expect(err, isA<UnknownException>());
      expect(err.raw, isA<FormatException>());
      expect(err.stackTrace, isNotNull);
    });

    test('同步 throw 的 async function 也被捕获', () async {
      Future<int> failing() async {
        // 直接在 async 函数体同步 throw
        throw StateError('sync throw');
      }

      final r = await failing().toResult();
      expect(r, isA<Err<int>>());
      expect(r.errorOrNull, isA<UnknownException>());
    });
  });
}
