import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../templates/bootstrap_template.dart';
import '../util/file_writer.dart';
import '../util/naming.dart';
import '../util/template_engine.dart';

/// `bootstrap` 不接 `<name>` 业务参数，而是给整个 app 起骨架——所以**不**继承 [FlutterSpineCommand]。
class BootstrapCommand extends Command<int> {
  BootstrapCommand() {
    argParser
      ..addOption('app-title',
          help: 'MaterialApp 标题，默认取 pubspec name 转 Title Case。')
      ..addFlag('dry-run', negatable: false)
      ..addFlag('force', abbr: 'f', negatable: false)
      ..addFlag(
        'gen',
        help: '同时为 riverpod_generator 工程做接入：'
            '追加 dev_dependency（riverpod_generator / build_runner / riverpod_annotation 等）'
            '+ 落地 build.yaml，并提示 dart run build_runner build 命令。',
        negatable: false,
      );
  }

  @override
  String get name => 'bootstrap';

  @override
  String get description =>
      '生成 main.dart + app/router.dart 启动骨架（默认用 MaterialDefaultEffectHandler）。'
      ' 加 --gen 可一并配 riverpod_generator 接入。';

  @override
  String get invocation => 'flutter_spine:new bootstrap [--app-title] [--gen]';

  @override
  Future<int> run() async {
    final cwd = Directory.current.path;
    final pkg = _detectPackageName(cwd);
    final naming = Naming.parse(
      (argResults!['app-title'] as String?) ?? pkg,
    );
    final dryRun = argResults!['dry-run'] as bool;
    final force = argResults!['force'] as bool;
    final useGen = argResults!['gen'] as bool;

    final writer = FileWriter(dryRun: dryRun, force: force);

    String render(String t) => renderTemplate(t, naming);

    writer.writeFile(p.join(cwd, 'lib', 'main.dart'),
        render(bootstrapMainTemplate));
    writer.writeFile(p.join(cwd, 'lib', 'app', 'router.dart'),
        render(bootstrapRouterTemplate));

    if (useGen) {
      _ensureGenDeps(cwd, dryRun: dryRun);
      writer.writeFile(p.join(cwd, 'build.yaml'), _buildYaml);
    }

    writer.summary();

    if (useGen) {
      stdout.writeln('');
      stdout.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      stdout.writeln('riverpod_generator 接入完成。下一步请执行：');
      stdout.writeln('');
      stdout.writeln('    flutter pub get');
      stdout.writeln('    dart run build_runner build --delete-conflicting-outputs');
      stdout.writeln('');
      stdout.writeln('之后所有 `dart run flutter_spine:new <cmd> --gen` 生成的');
      stdout.writeln('`@riverpod` 注解类都会被 build_runner 自动转成可用的 provider。');
      stdout.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    return 0;
  }

  String _detectPackageName(String cwd) {
    final pubspec = File(p.join(cwd, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return 'app';
    for (final line in pubspec.readAsLinesSync()) {
      final m = RegExp(r'^name:\s*([a-zA-Z0-9_]+)').firstMatch(line);
      if (m != null) return m.group(1)!;
    }
    return 'app';
  }

  /// 把 riverpod_generator + build_runner + riverpod_annotation 加进
  /// pubspec.yaml。已存在的依赖**保持不动**——零破坏。
  void _ensureGenDeps(String cwd, {required bool dryRun}) {
    final pubspecFile = File(p.join(cwd, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      stderr.writeln('[skip-gen-deps] pubspec.yaml not found at $cwd');
      return;
    }
    var src = pubspecFile.readAsStringSync();

    const ann = 'riverpod_annotation';
    const gen = 'riverpod_generator';
    const br = 'build_runner';
    const lint = 'custom_lint';
    const rlint = 'riverpod_lint';

    final added = <String>[];

    // dependencies: riverpod_annotation
    if (!_hasDep(src, ann)) {
      src = _appendUnderSection(src, 'dependencies', '  $ann: ^2.6.1');
      added.add('dependencies/$ann');
    }
    // dev_dependencies: build_runner / riverpod_generator / custom_lint / riverpod_lint
    for (final dep in [br, gen, lint, rlint]) {
      if (!_hasDep(src, dep)) {
        final version = switch (dep) {
          'build_runner' => '^2.4.13',
          'riverpod_generator' => '^2.6.3',
          'custom_lint' => '^0.7.0',
          'riverpod_lint' => '^2.6.3',
          _ => 'any',
        };
        src = _appendUnderSection(src, 'dev_dependencies', '  $dep: $version');
        added.add('dev_dependencies/$dep');
      }
    }

    if (added.isEmpty) {
      stdout.writeln('[skip-pubspec] all riverpod_generator deps already present.');
      return;
    }

    if (dryRun) {
      stdout.writeln(
          '[dry-run] would PATCH pubspec.yaml (+${added.length} deps: ${added.join(", ")})');
      return;
    }
    pubspecFile.writeAsStringSync(src);
    stdout.writeln('[patch] pubspec.yaml (+${added.length} deps)');
  }

  bool _hasDep(String pubspec, String depName) {
    return RegExp('^\\s{2}$depName:', multiLine: true).hasMatch(pubspec);
  }

  /// 在指定 top-level section（dependencies / dev_dependencies）下追加一行。
  /// 找不到该 section 时整段补在文件末尾。
  String _appendUnderSection(String src, String section, String line) {
    final sectionRe = RegExp('^$section:\\s*\$', multiLine: true);
    final m = sectionRe.firstMatch(src);
    if (m == null) {
      return '$src\n$section:\n$line\n';
    }
    // 找下一个 top-level section 起点（缩进为 0 的 key:）
    final after = src.substring(m.end);
    final nextSectionRe = RegExp(r'^[a-zA-Z_]+:', multiLine: true);
    final nextMatch = nextSectionRe.firstMatch(after);
    final insertPos = nextMatch == null ? src.length : m.end + nextMatch.start;
    final before = src.substring(0, insertPos).trimRight();
    final tail = src.substring(insertPos);
    return '${'$before\n$line\n\n$tail'.trimRight()}\n';
  }

  /// 给 build_runner 一份基础 build.yaml——可保持空，让 riverpod_generator 走默认。
  /// 这里加了一行注释引导业务后续按需扩展（json_serializable / freezed 等）。
  static const _buildYaml = '''# build.yaml — 由 `flutter_spine:new bootstrap --gen` 生成。
# riverpod_generator 走默认配置即可；如需配 json_serializable / freezed 等，
# 在 builders 里追加即可。

targets:
  \$default:
    builders:
      # 例：开 source_gen/combining_builder 的 cache 使重复 build 更快
      source_gen|combining_builder:
        options:
          ignore_for_file:
            - type=lint
''';
}
