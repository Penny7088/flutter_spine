/// 数值扩展。核心目标：提供**精度安全**的金额格式化，避免 double 乘除带来的精度丢失。
///
/// 现有痛点（flutter_wallet tools_util.dart）：
///   `(double.tryParse(str)! * 100 / 1000000).toInt()` → 精度丢失
///
/// 解决方案：全程操作字符串，不借助 double 乘除。
extension NumFormatX on num {
  /// 截断到 [fractionDigits] 位小数（不四舍五入）。
  ///
  /// 例：`1.23456.toFixedSafe(2)` → `'1.23'`
  ///     `1.toFixedSafe(2)`       → `'1.00'`
  String toFixedSafe(int fractionDigits) {
    assert(fractionDigits >= 0, 'fractionDigits must be >= 0');
    final s = toString();
    final dot = s.indexOf('.');
    if (dot < 0) {
      return fractionDigits == 0 ? s : '$s.${'0' * fractionDigits}';
    }
    final decimals = s.substring(dot + 1);
    if (decimals.length >= fractionDigits) {
      return fractionDigits == 0
          ? s.substring(0, dot)
          : '${s.substring(0, dot)}.${decimals.substring(0, fractionDigits)}';
    }
    return '$s${'0' * (fractionDigits - decimals.length)}';
  }

  /// 千分位分隔符格式，保留 [fractionDigits] 位小数。
  ///
  /// 例：`1234567.89.toThousandsSep()` → `'1,234,567.89'`
  String toThousandsSep({int fractionDigits = 2}) {
    final fixed = toFixedSafe(fractionDigits);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return parts.length == 1 ? intPart : '$intPart.${parts[1]}';
  }
}

extension StringNumX on String {
  /// 字符串安全解析为 int，失败时返回 [fallback]（默认 0）。
  int toIntSafe([int fallback = 0]) => int.tryParse(this) ?? fallback;

  /// 字符串安全解析为 double，失败时返回 [fallback]（默认 0.0）。
  double toDoubleSafe([double fallback = 0.0]) =>
      double.tryParse(this) ?? fallback;
}
