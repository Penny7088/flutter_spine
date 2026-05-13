import 'package:path/path.dart' as p;

import '../templates/generator_templates.dart';
import '../templates/paged_list_template.dart';
import 'base_command.dart';

class PagedListCommand extends FlutterSpineCommand {
  @override
  String get name => 'paged-list';

  @override
  String get description =>
      '生成 PagedNotifierMixin + PagedListView 分页列表（无参版）。';

  @override
  String get invocation =>
      'flutter_spine:new paged-list <name> [--path] [--with-test]';

  @override
  Future<int> run() async {
    final dir = outputDir;
    final snake = naming.snake;

    writer.writeFile(
        p.join(dir, '${snake}_item.dart'), render(pagedListItemTemplate));
    writer.writeFile(
        p.join(dir, '${snake}_vm.dart'),
        render(gen ? pagedListVmTemplateGen : pagedListVmTemplate));
    writer.writeFile(
        p.join(dir, '${snake}_page.dart'), render(pagedListPageTemplate));

    if (withTest) {
      final pkg = detectPackageName();
      writer.writeFile(
        p.join(testDir, '${snake}_vm_test.dart'),
        render(pagedListVmTestTemplate, extras: {'pkg': pkg}),
      );
    }

    writer.summary();
    return 0;
  }
}
