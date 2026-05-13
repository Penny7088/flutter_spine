extension DateTimeX on DateTime {
  /// Unix 秒时间戳（毫秒 ~/ 1000）。
  int get secondsSinceEpoch => millisecondsSinceEpoch ~/ 1000;

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// 判断是否闰年。修复原 utils.dart 中 `year` 被覆盖的逻辑 bug。
  bool get isLeapYear =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  /// 当月天数（正确处理闰年 2 月）。
  int get daysInMonth {
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && isLeapYear) return 29;
    return days[month - 1];
  }

  /// 格式化为 `yyyy-MM-dd`。
  String toDateString() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  /// 格式化为 `yyyy-MM-dd HH:mm:ss`。
  String toDateTimeString() =>
      '${toDateString()} '
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}:'
      '${second.toString().padLeft(2, '0')}';
}
