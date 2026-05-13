import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../util/file_writer.dart';
import '../util/naming.dart';
import '../util/template_engine.dart';

/// 所有 `flutter_spine:new` 子命令的共用基类。
///
/// * 统一注册 `--path` / `--with-test` / `--dry-run` / `--force`
/// * 提供 [naming] / [writer] / [render] 等便捷方法
/// * 子类只需重写 [run] 并调 [render] + [writer.writeFile]
abstract class FlutterSpineCommand extends Command<int> {
  FlutterSpineCommand() {
    argParser
      ..addOption(
        'path',
        help: '输出目录（相对于 cwd）。'
            '默认：lib/features/<name_snake>。',
      )
      ..addFlag(
        'with-test',
        help: '同时在 test/ 下生成对应的测试文件。',
        defaultsTo: false,
      )
      ..addFlag(
        'dry-run',
        help: '只打印将要写的文件，不真正落盘。',
        negatable: false,
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: '已存在文件时覆盖（默认会跳过）。',
        negatable: false,
      )
      ..addFlag(
        'gen',
        help: '使用 riverpod_generator 风格模板（@riverpod 注解 + part 文件）。'
            '工程需先有 build_runner / riverpod_generator dev_dependency——'
            '可用 `flutter_spine:new bootstrap --gen` 一次配齐。',
        negatable: false,
      );
  }

  /// 业务输入名（位置参数 0），延迟解析。
  String get rawName {
    final rest = argResults?.rest ?? const [];
    if (rest.isEmpty) {
      usageException('missing <name> argument.');
    }
    if (rest.length > 1) {
      usageException('too many positional args; expected exactly one <name>.');
    }
    return rest.first;
  }

  Naming get naming => Naming.parse(rawName);

  bool get dryRun => argResults!['dry-run'] as bool;
  bool get force => argResults!['force'] as bool;
  bool get withTest => argResults!['with-test'] as bool;
  bool get gen => argResults!['gen'] as bool;

  /// 默认输出目录：`<cwd>/lib/features/<name_snake>`，可被 `--path` 覆盖。
  String get outputDir {
    final cwd = Directory.current.path;
    final pathOpt = argResults!['path'] as String?;
    if (pathOpt != null && pathOpt.isNotEmpty) {
      return p.normalize(p.join(cwd, pathOpt));
    }
    return p.normalize(p.join(cwd, 'lib', 'features', naming.snake));
  }

  /// 测试目录：`<cwd>/test/features/<name_snake>`。
  String get testDir => p.normalize(
      p.join(Directory.current.path, 'test', 'features', naming.snake));

  late final FileWriter writer = FileWriter(dryRun: dryRun, force: force);

  /// 模板渲染快捷方法。
  String render(String template, {Map<String, String> extras = const {}}) =>
      renderTemplate(template, naming, extras: extras);

  /// 从 cwd 的 `pubspec.yaml` 读 package name；找不到时退化成"app"。
  /// 用于 test 模板的 `package:<pkg>/...` import 前缀。
  String detectPackageName() {
    final pubspec = File(p.join(Directory.current.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return 'app';
    final lines = pubspec.readAsLinesSync();
    for (final line in lines) {
      final m = RegExp(r'^name:\s*([a-zA-Z0-9_]+)').firstMatch(line);
      if (m != null) return m.group(1)!;
    }
    return 'app';
  }
}
