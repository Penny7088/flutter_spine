import 'dart:io';

import 'package:path/path.dart' as p;

import '../templates/generator_templates.dart';
import '../templates/repo_template.dart';
import 'base_command.dart';

class RepoCommand extends FlutterSpineCommand {
  @override
  String get name => 'repo';

  @override
  String get description =>
      '生成 Repository 三件套（abstract / Http 实现 / provider）。';

  @override
  String get invocation =>
      'flutter_spine:new repo <name> [--path]';

  @override
  String get outputDir {
    final pathOpt = argResults!['path'] as String?;
    if (pathOpt != null && pathOpt.isNotEmpty) {
      return p.normalize(p.join(Directory.current.path, pathOpt));
    }
    return p.normalize(p.join(Directory.current.path, 'lib', 'data'));
  }

  @override
  Future<int> run() async {
    final dir = outputDir;
    final snake = naming.snake;

    writer.writeFile(
        p.join(dir, '${snake}_repository.dart'), render(repoAbstractTemplate));
    writer.writeFile(
        p.join(dir, '${snake}_repository_impl.dart'), render(repoImplTemplate));
    writer.writeFile(
        p.join(dir, '${snake}_repository_provider.dart'),
        render(gen ? repoProviderTemplateGen : repoProviderTemplate));

    writer.summary();
    return 0;
  }
}
