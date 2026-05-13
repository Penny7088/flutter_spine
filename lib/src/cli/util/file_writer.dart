import 'dart:io';

import 'package:path/path.dart' as p;

/// 写文件统一入口——把 dry-run、--force、目录创建、冲突报错全收到这里，
/// 各 command 只关心"我要在哪写什么"。
class FileWriter {
  FileWriter({
    required this.dryRun,
    required this.force,
    StringSink? out,
  }) : _out = out ?? stdout;

  final bool dryRun;
  final bool force;
  final StringSink _out;

  /// 已写入路径（用于命令最后 summary）。
  final List<String> written = [];

  /// 已跳过路径（已存在 + !force）。
  final List<String> skipped = [];

  /// 写一份内容到 [absolutePath]。
  ///
  /// * dry-run → 只打印不写；
  /// * 已存在 + !force → skip 并 warn；
  /// * 否则创建父目录并写入。
  ///
  /// 返回值：true = 实际写入；false = skip / dry-run。
  bool writeFile(String absolutePath, String contents) {
    final rel = p.relative(absolutePath);
    final exists = File(absolutePath).existsSync();

    if (dryRun) {
      _out.writeln(
          '[dry-run] would ${exists ? "OVERWRITE" : "create"}: $rel  '
          '(${contents.length} chars)');
      written.add(rel);
      return false;
    }

    if (exists && !force) {
      _out.writeln('[skip] already exists: $rel  (use --force to overwrite)');
      skipped.add(rel);
      return false;
    }

    final dir = Directory(p.dirname(absolutePath));
    if (!dir.existsSync()) dir.createSync(recursive: true);

    File(absolutePath).writeAsStringSync(contents);
    _out.writeln('${exists ? "[write]" : "[create]"} $rel');
    written.add(rel);
    return true;
  }

  /// 在文件 [absolutePath] 末尾**追加** [snippet]（保持原内容不动）。
  ///
  /// dry-run 同 [writeFile]；文件不存在直接抛 [FileSystemException]——
  /// 调用方应明确知道目标文件存在。
  bool appendToFile(String absolutePath, String snippet) {
    final rel = p.relative(absolutePath);
    final file = File(absolutePath);
    if (!file.existsSync()) {
      throw FileSystemException('appendToFile: target not found', absolutePath);
    }
    if (dryRun) {
      _out.writeln('[dry-run] would APPEND ${snippet.length} chars to: $rel');
      written.add(rel);
      return false;
    }
    file.writeAsStringSync(snippet, mode: FileMode.append);
    _out.writeln('[append] $rel');
    written.add(rel);
    return true;
  }

  void summary() {
    if (written.isNotEmpty) {
      _out.writeln('');
      _out.writeln('done. ${written.length} file(s) '
          '${dryRun ? "would change" : "changed"}'
          '${skipped.isNotEmpty ? ", ${skipped.length} skipped" : ""}.');
    } else if (skipped.isNotEmpty) {
      _out.writeln('');
      _out.writeln(
          'no changes (${skipped.length} skipped — pass --force to overwrite).');
    }
  }
}
