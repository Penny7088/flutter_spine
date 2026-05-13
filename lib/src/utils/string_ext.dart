extension StringSafeX on String {
  /// 不越界的 substring。start / end 自动 clamp 到合法范围。
  String safeSubstring(int start, [int? end]) {
    if (isEmpty) return '';
    final s = start.clamp(0, length);
    final e = (end ?? length).clamp(s, length);
    return substring(s, e);
  }

  /// 中间打码。修复原 `orderHide()` 在字符串长度 < 5 时的 RangeError。
  ///
  /// 例：`'12345678'.maskMiddle()` → `'12***78'`
  ///     `'ab'.maskMiddle()`      → `'ab'`（太短直接原样返回）
  String maskMiddle({
    int prefix = 2,
    int suffix = 2,
    String mask = '***',
  }) {
    if (length <= prefix + suffix) return this;
    return '${safeSubstring(0, prefix)}$mask${safeSubstring(length - suffix)}';
  }

  /// 如果为空或只有空白，返回 null，否则返回 trim 后的字符串。
  String? get nullIfBlank => trim().isEmpty ? null : trim();

  /// 首字母大写。
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
