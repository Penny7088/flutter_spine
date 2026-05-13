import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NumFormatX.toFixedSafe', () {
    test('integer with fractionDigits=2 appends .00', () {
      expect(1.toFixedSafe(2), '1.00');
    });

    test('truncates (does not round)', () {
      expect(1.23456.toFixedSafe(2), '1.23');
      expect(1.999.toFixedSafe(2), '1.99');
    });

    test('pads short decimals with zeros', () {
      expect(1.1.toFixedSafe(3), '1.100');
    });

    test('fractionDigits=0 removes decimal part', () {
      expect(1.9.toFixedSafe(0), '1');
    });

    test('handles negative numbers', () {
      expect((-1.5).toFixedSafe(2), '-1.50');
    });

    test('handles zero', () {
      expect(0.toFixedSafe(2), '0.00');
    });
  });

  group('NumFormatX.toThousandsSep', () {
    test('1234567.89 → 1,234,567.89', () {
      expect(1234567.89.toThousandsSep(), '1,234,567.89');
    });

    test('1000 → 1,000.00', () {
      expect(1000.toThousandsSep(), '1,000.00');
    });

    test('999 → 999.00 (no separator needed)', () {
      expect(999.toThousandsSep(), '999.00');
    });

    test('fractionDigits=0 omits decimals', () {
      expect(1234.toThousandsSep(fractionDigits: 0), '1,234');
    });
  });

  group('StringNumX', () {
    test('toIntSafe parses valid int', () {
      expect('42'.toIntSafe(), 42);
    });

    test('toIntSafe returns fallback on invalid', () {
      expect('abc'.toIntSafe(99), 99);
    });

    test('toDoubleSafe parses valid double', () {
      expect('3.14'.toDoubleSafe(), closeTo(3.14, 0.001));
    });

    test('toDoubleSafe returns fallback on invalid', () {
      expect('nope'.toDoubleSafe(-1.0), -1.0);
    });
  });
}
