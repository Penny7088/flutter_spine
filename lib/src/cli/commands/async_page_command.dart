import 'package:path/path.dart' as p;

import '../templates/async_page_template.dart';
import '../templates/generator_templates.dart';
import 'base_command.dart';

class AsyncPageCommand extends FlutterSpineCommand {
  @override
  String get name => 'async-page';

  @override
  String get description =>
      '生成 AsyncViewModelNotifier + AsyncBuilder 页面（拉接口的常规页面）。';

  @override
  String get invocation =>
      'flutter_spine:new async-page <name> [--path] [--with-test]';

  @override
  Future<int> run() async {
    final dir = outputDir;
    final snake = naming.snake;

    writer.writeFile(
        p.join(dir, '${snake}_data.dart'), render(asyncPageDataTemplate));
    writer.writeFile(
        p.join(dir, '${snake}_vm.dart'),
        render(gen ? asyncPageVmTemplateGen : asyncPageVmTemplate));
    writer.writeFile(
        p.join(dir, '${snake}_page.dart'), render(asyncPagePageTemplate));

    if (withTest) {
      final pkg = detectPackageName();
      writer.writeFile(
        p.join(testDir, '${snake}_vm_test.dart'),
        render(asyncPageVmTestTemplate, extras: {'pkg': pkg}),
      );
    }

    writer.summary();
    return 0;
  }
}
