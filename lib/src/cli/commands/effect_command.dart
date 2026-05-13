import 'dart:io';

import 'package:path/path.dart' as p;

import '../templates/effect_template.dart';
import 'base_command.dart';

class EffectCommand extends FlutterSpineCommand {
  @override
  String get name => 'effect';

  @override
  String get description => '生成自定义 Effect 类（业务自有副作用）。';

  @override
  String get invocation => 'flutter_spine:new effect <name> [--path]';

  @override
  String get outputDir {
    final pathOpt = argResults!['path'] as String?;
    if (pathOpt != null && pathOpt.isNotEmpty) {
      return p.normalize(p.join(Directory.current.path, pathOpt));
    }
    return p.normalize(p.join(Directory.current.path, 'lib', 'effects'));
  }

  @override
  Future<int> run() async {
    final snake = naming.snake;
    writer.writeFile(
        p.join(outputDir, '${snake}_effect.dart'), render(effectTemplate));
    writer.summary();
    return 0;
  }
}
