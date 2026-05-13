/// 分页列表页（无参版本，复杂场景请基于此再加 `family` / filter）。
const pagedListItemTemplate = r'''
import 'package:flutter/foundation.dart';

@immutable
class {{Name}}Item {
  const {{Name}}Item({required this.id, required this.title});

  final String id;
  final String title;
}
''';

const pagedListVmTemplate = r'''
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '{{name_snake}}_item.dart';

final {{name}}VmProvider = AsyncNotifierProvider.autoDispose<
    {{Name}}Vm, PagedState<{{Name}}Item>>({{Name}}Vm.new);

class {{Name}}Vm extends AutoDisposeAsyncNotifier<PagedState<{{Name}}Item>>
    with PagedNotifierMixinNoArg<{{Name}}Item> {
  @override
  int get pageSize => 20;

  @override
  Future<List<{{Name}}Item>> fetchPage(int page, int size) async {
    // TODO: 改成 ref.read(xxxRepositoryProvider).list(page: page, size: size)
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (page > 3) return const [];
    return List.generate(
      size,
      (i) => {{Name}}Item(
        id: 'p${page}_i$i',
        title: '{{Title}} #$page-$i',
      ),
    );
  }
}
''';

const pagedListPageTemplate = r'''
import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';

import '{{name_snake}}_item.dart';
import '{{name_snake}}_vm.dart';

class {{Name}}Page extends StatelessWidget {
  const {{Name}}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return AppListPageScaffold<{{Name}}Item>(
      title: '{{Title}}',
      provider: {{name}}VmProvider,
      controllerProvider: {{name}}VmProvider.notifier,
      itemBuilder: (context, item, index) => ListTile(
        title: Text(item.title),
        subtitle: Text(item.id),
      ),
      separatorBuilder: (_, __) => const Divider(height: 0),
    );
  }
}
''';

const pagedListVmTestTemplate = r'''
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_core_test/flutter_core_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:{{pkg}}/features/{{name_snake}}/{{name_snake}}_vm.dart';

void main() {
  test('{{Name}}Vm 首屏返回 pageSize 条', () async {
    final h = createVmTestHarness();
    final state = await h.read({{name}}VmProvider.future);
    expect(state, isA<PagedState>());
    expect(state.items.length, 20);
    expect(state.hasMore, isTrue);
  });

  test('{{Name}}Vm loadMore 追加下一页', () async {
    final h = createVmTestHarness();
    h.keepAlive({{name}}VmProvider);
    await h.read({{name}}VmProvider.future);
    final ok = await h.read({{name}}VmProvider.notifier).loadMore();
    expect(ok, isTrue);
    expect(h.read({{name}}VmProvider).value!.items.length, 40);
  });
}
''';
