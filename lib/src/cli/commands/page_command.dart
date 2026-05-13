import 'package:path/path.dart' as p;

import '../templates/generator_templates.dart';
import '../templates/page_template.dart';
import 'base_command.dart';

class PageCommand extends FlutterSpineCommand {
  @override
  String get name => 'page';

  @override
  String get description =>
      '生成同步 ViewModelNotifier + State + Page 三件套（适合简单页面）。';

  @override
  String get invocation => 'flutter_spine:new page <name> [--path] [--with-test]';

  @override
  Future<int> run() async {
    final dir = outputDir;
    final snake = naming.snake;

    writer.writeFile(
        p.join(dir, '${snake}_state.dart'), render(pageStateTemplate));
    writer.writeFile(
        p.join(dir, '${snake}_vm.dart'),
        render(gen ? pageVmTemplateGen : pageVmTemplate));
    writer.writeFile(
        p.join(dir, '${snake}_page.dart'), render(pagePageTemplate));

    if (withTest) {
      final pkg = detectPackageName();
      writer.writeFile(
        p.join(testDir, '${snake}_vm_test.dart'),
        render(pageVmTestTemplate, extras: {'pkg': pkg}),
      );
    }

    writer.summary();
    return 0;
  }
}
