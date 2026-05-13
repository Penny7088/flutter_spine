import 'package:path/path.dart' as p;

import '../templates/form_template.dart';
import '../templates/generator_templates.dart';
import 'base_command.dart';

class FormCommand extends FlutterSpineCommand {
  @override
  String get name => 'form';

  @override
  String get description =>
      '生成表单页（state + canSubmit 校验 + run 提交 + EffectPop）。';

  @override
  String get invocation =>
      'flutter_spine:new form <name> [--path] [--with-test]';

  @override
  Future<int> run() async {
    final dir = outputDir;
    final snake = naming.snake;

    writer.writeFile(
        p.join(dir, '${snake}_state.dart'), render(formStateTemplate));
    writer.writeFile(
        p.join(dir, '${snake}_vm.dart'),
        render(gen ? formVmTemplateGen : formVmTemplate));
    writer.writeFile(
        p.join(dir, '${snake}_page.dart'), render(formPageTemplate));

    if (withTest) {
      final pkg = detectPackageName();
      writer.writeFile(
        p.join(testDir, '${snake}_vm_test.dart'),
        render(formVmTestTemplate, extras: {'pkg': pkg}),
      );
    }

    writer.summary();
    return 0;
  }
}
