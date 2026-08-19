import 'dart:io';

import 'package:path/path.dart' as p;

import '../templates/async_page_template.dart';
import '../templates/form_template.dart';
import '../templates/generator_templates.dart';
import '../templates/page_template.dart';
import '../templates/repo_template.dart';
import 'base_command.dart';

/// 一个命令把"页面 + 可选 repo + 可选路由 + 可选测试"全生成完，
/// 适合启动新功能时一次落齐所有骨架。
class FeatureCommand extends FlutterSpineCommand {
  FeatureCommand() {
    argParser
      ..addOption(
        'variant',
        allowed: const ['page', 'async', 'form'],
        defaultsTo: 'async',
        help: '页面变体：'
            'page=同步 VM；async=AsyncViewModelNotifier+AsyncBuilder；'
            'form=表单。',
      )
      ..addFlag('with-repo',
          help: '同时生成 Repository 三件套（放 lib/data/<name>/）。',
          defaultsTo: false)
      ..addFlag('with-route',
          help: '尝试把新 page 的 GoRoute 追加到 lib/app/router.dart。',
          defaultsTo: false);
  }

  @override
  String get name => 'feature';

  @override
  String get description =>
      '一键生成完整 feature：page（含变体）+ 可选 repo / 路由 / 测试。';

  @override
  String get invocation =>
      'flutter_spine:new feature <name> [--variant=async|page|form] '
      '[--with-repo] [--with-route] [--with-test]';

  @override
  Future<int> run() async {
    final variant = argResults!['variant'] as String;
    final withRepo = argResults!['with-repo'] as bool;
    final withRoute = argResults!['with-route'] as bool;
    final dir = outputDir;
    final snake = naming.snake;

    _generatePage(variant, dir, snake);

    if (withRepo) _generateRepo();

    if (withTest) _generateTest(variant);

    if (withRoute) _patchRouter(variant);

    writer.summary();
    return 0;
  }

  // ── page 变体 ─────────────────────────────────────────────────────────────

  void _generatePage(String variant, String dir, String snake) {
    switch (variant) {
      case 'page':
        writer.writeFile(
            p.join(dir, '${snake}_state.dart'), render(pageStateTemplate));
        writer.writeFile(p.join(dir, '${snake}_vm.dart'),
            render(gen ? pageVmTemplateGen : pageVmTemplate));
        writer.writeFile(
            p.join(dir, '${snake}_page.dart'), render(pagePageTemplate));
      case 'async':
        writer.writeFile(
            p.join(dir, '${snake}_data.dart'), render(asyncPageDataTemplate));
        writer.writeFile(p.join(dir, '${snake}_vm.dart'),
            render(gen ? asyncPageVmTemplateGen : asyncPageVmTemplate));
        writer.writeFile(
            p.join(dir, '${snake}_page.dart'), render(asyncPagePageTemplate));
      case 'form':
        writer.writeFile(
            p.join(dir, '${snake}_state.dart'), render(formStateTemplate));
        writer.writeFile(p.join(dir, '${snake}_vm.dart'),
            render(gen ? formVmTemplateGen : formVmTemplate));
        writer.writeFile(
            p.join(dir, '${snake}_page.dart'), render(formPageTemplate));
    }
  }

  // ── repo ─────────────────────────────────────────────────────────────────

  void _generateRepo() {
    final dir = p.join(Directory.current.path, 'lib', 'data', naming.snake);
    final snake = naming.snake;
    writer.writeFile(
        p.join(dir, '${snake}_repository.dart'), render(repoAbstractTemplate));
    writer.writeFile(
        p.join(dir, '${snake}_repository_impl.dart'), render(repoImplTemplate));
    writer.writeFile(p.join(dir, '${snake}_repository_provider.dart'),
        render(gen ? repoProviderTemplateGen : repoProviderTemplate));
  }

  // ── test ─────────────────────────────────────────────────────────────────

  void _generateTest(String variant) {
    final pkg = detectPackageName();
    final snake = naming.snake;
    final extras = {'pkg': pkg};

    final tpl = switch (variant) {
      'page' => pageVmTestTemplate,
      'async' => asyncPageVmTestTemplate,
      'form' => formVmTestTemplate,
      _ => null,
    };
    if (tpl == null) return;
    writer.writeFile(
      p.join(testDir, '${snake}_vm_test.dart'),
      render(tpl, extras: extras),
    );
  }

  // ── router 自动追加 ──────────────────────────────────────────────────────

  void _patchRouter(String variant) {
    final routerPath =
        p.join(Directory.current.path, 'lib', 'app', 'router.dart');
    final file = File(routerPath);
    if (!file.existsSync()) {
      stderr.writeln(
          '[skip] --with-route: lib/app/router.dart not found. '
          '先跑 `flutter_spine:new bootstrap` 生成骨架。');
      return;
    }

    final pkg = detectPackageName();
    final snake = naming.snake;
    final pageImport =
        "import 'package:$pkg/features/$snake/${snake}_page.dart';";
    final routeEntry = '''
      GoRoute(
        path: '/$snake',
        builder: (ctx, state) => const ${naming.pascal}Page(),
      ),''';

    final original = file.readAsStringSync();
    if (original.contains(pageImport) || original.contains("path: '/$snake'")) {
      stdout.writeln('[skip-router] $snake route already present.');
      return;
    }

    // 1) 在 import 段尾加 import；找不到 import 行就在文件开头加
    var patched = _insertImport(original, pageImport);

    // 2) 在 `routes: [` 后插入 GoRoute
    patched = _insertRouteEntry(patched, routeEntry);

    if (patched == original) {
      stderr.writeln(
          '[skip-router] could not find `routes: [` block in router.dart — '
          '请手动追加：\n$routeEntry');
      return;
    }

    if (writer.dryRun) {
      stdout.writeln(
          '[dry-run] would PATCH lib/app/router.dart (+1 import, +1 GoRoute)');
      return;
    }
    file.writeAsStringSync(patched);
    stdout.writeln('[patch] lib/app/router.dart (+1 import, +1 GoRoute)');
  }

  String _insertImport(String src, String importLine) {
    final importRe = RegExp(r"^import .+;$", multiLine: true);
    final matches = importRe.allMatches(src).toList();
    if (matches.isEmpty) {
      return '$importLine\n$src';
    }
    final last = matches.last;
    return '${src.substring(0, last.end)}\n$importLine${src.substring(last.end)}';
  }

  String _insertRouteEntry(String src, String entry) {
    final m = RegExp(r'routes:\s*\[').firstMatch(src);
    if (m == null) return src;
    return '${src.substring(0, m.end)}\n$entry${src.substring(m.end)}';
  }
}
