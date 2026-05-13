import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateTimeX.isLeapYear', () {
    test('2000 is leap (400 rule)', () => expect(DateTime(2000).isLeapYear, true));
    test('2400 is leap (400 rule)', () => expect(DateTime(2400).isLeapYear, true));
    test('1900 is NOT leap (100 rule)', () => expect(DateTime(1900).isLeapYear, false));
    test('2100 is NOT leap (100 rule)', () => expect(DateTime(2100).isLeapYear, false));
    test('2024 is leap (4 rule)', () => expect(DateTime(2024).isLeapYear, true));
    test('2023 is NOT leap', () => expect(DateTime(2023).isLeapYear, false));
  });

  group('DateTimeX.daysInMonth', () {
    test('Feb 2024 = 29', () => expect(DateTime(2024, 2).daysInMonth, 29));
    test('Feb 2023 = 28', () => expect(DateTime(2023, 2).daysInMonth, 28));
    test('Jan = 31', () => expect(DateTime(2023, 1).daysInMonth, 31));
    test('Apr = 30', () => expect(DateTime(2023, 4).daysInMonth, 30));
  });

  group('DateTimeX.secondsSinceEpoch', () {
    test('consistent with millisecondsSinceEpoch', () {
      final dt = DateTime(2024, 1, 1);
      expect(dt.secondsSinceEpoch, dt.millisecondsSinceEpoch ~/ 1000);
    });
  });

  group('DateTimeX.toDateString', () {
    test('formats correctly', () {
      expect(DateTime(2024, 3, 5).toDateString(), '2024-03-05');
    });
  });

  group('DateTimeX.isSameDay', () {
    test('same day returns true', () {
      expect(
        DateTime(2024, 1, 1, 10).isSameDay(DateTime(2024, 1, 1, 22)),
        true,
      );
    });
    test('different day returns false', () {
      expect(
        DateTime(2024, 1, 1).isSameDay(DateTime(2024, 1, 2)),
        false,
      );
    });
  });
}
