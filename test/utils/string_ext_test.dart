import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StringSafeX.safeSubstring', () {
    test('normal range works', () {
      expect('hello'.safeSubstring(1, 3), 'el');
    });

    test('start > length clamps to end', () {
      expect('hi'.safeSubstring(10), '');
    });

    test('empty string returns empty', () {
      expect(''.safeSubstring(0, 5), '');
    });

    test('end > length clamps to length', () {
      expect('hello'.safeSubstring(0, 100), 'hello');
    });
  });

  group('StringSafeX.maskMiddle', () {
    test('masks middle correctly', () {
      expect('12345678'.maskMiddle(), '12***78');
    });

    test('string too short returns original (no crash)', () {
      expect('ab'.maskMiddle(), 'ab');
    });

    test('exactly prefix+suffix length returns original', () {
      expect('abcd'.maskMiddle(prefix: 2, suffix: 2), 'abcd');
    });

    test('custom mask', () {
      expect('123456'.maskMiddle(prefix: 1, suffix: 1, mask: '##'), '1##6');
    });
  });

  group('StringSafeX.nullIfBlank', () {
    test('blank returns null', () => expect('   '.nullIfBlank, null));
    test('empty returns null', () => expect(''.nullIfBlank, null));
    test('non-blank returns trimmed', () => expect('  hi  '.nullIfBlank, 'hi'));
  });

  group('StringSafeX.capitalized', () {
    test('capitalizes first letter', () => expect('hello'.capitalized, 'Hello'));
    test('empty returns empty', () => expect(''.capitalized, ''));
  });
}
