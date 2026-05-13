/// 名称转换工具：在 CLI 里业务只输入一种"自然名"，模板里用各种 case 占位符。
///
/// 支持的输入：
/// * `user_profile` (snake_case)
/// * `userProfile` (camelCase)
/// * `UserProfile` (PascalCase)
/// * `user-profile` (kebab-case)
/// * `User Profile` (空格分词)
///
/// 全部正则化为词数组，再按需输出。
class Naming {
  Naming._(this.words);

  factory Naming.parse(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      throw ArgumentError('name must not be empty');
    }
    // 分词逻辑：先按非字母数字拆，再处理 PascalCase/camelCase 内的大写边界。
    final separated = raw.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m[1]}_${m[2]}',
    );
    final words = separated
        .split(RegExp(r'[_\-\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.toLowerCase())
        .toList();
    if (words.isEmpty) {
      throw ArgumentError('name has no alphabetic content: "$input"');
    }
    return Naming._(words);
  }

  final List<String> words;

  /// `user_profile`
  String get snake => words.join('_');

  /// `user-profile`
  String get kebab => words.join('-');

  /// `userProfile`
  String get camel {
    if (words.length == 1) return words.first;
    return words.first +
        words.skip(1).map(_capitalize).join();
  }

  /// `UserProfile`
  String get pascal => words.map(_capitalize).join();

  /// `User Profile`（标题）
  String get title => words.map(_capitalize).join(' ');

  static String _capitalize(String w) =>
      w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}';
}
