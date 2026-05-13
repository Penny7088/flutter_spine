/// 异步 VM + page。State 直接是 `AsyncValue<XxxData>`，配 `AsyncBuilder` 渲染。
const asyncPageDataTemplate = r'''
import 'package:flutter/foundation.dart';

@immutable
class {{Name}}Data {
  const {{Name}}Data({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;
}
''';

const asyncPageVmTemplate = r'''
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '{{name_snake}}_data.dart';

final {{name}}VmProvider =
    AsyncNotifierProvider.autoDispose<{{Name}}Vm, {{Name}}Data>({{Name}}Vm.new);

class {{Name}}Vm extends AsyncViewModelNotifier<{{Name}}Data> {
  @override
  Future<{{Name}}Data> build() async {
    // TODO: 替换成 ref.read(xxxRepositoryProvider).load(...)
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const {{Name}}Data(
      title: '{{Title}}',
      items: ['demo 1', 'demo 2', 'demo 3'],
    );
  }

  Future<void> reload() => refresh();
}
''';

const asyncPagePageTemplate = r'''
import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '{{name_snake}}_data.dart';
import '{{name_snake}}_vm.dart';

class {{Name}}Page extends ConsumerWidget {
  const {{Name}}Page({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPageScaffold(
      title: '{{Title}}',
      body: AsyncBuilder<{{Name}}Data>(
        provider: {{name}}VmProvider,
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.read({{name}}VmProvider.notifier).reload(),
          child: ListView.separated(
            itemCount: d.items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) => ListTile(title: Text(d.items[i])),
          ),
        ),
      ),
    );
  }
}
''';

const asyncPageVmTestTemplate = r'''
import 'package:flutter_core_test/flutter_core_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:{{pkg}}/features/{{name_snake}}/{{name_snake}}_data.dart';
import 'package:{{pkg}}/features/{{name_snake}}/{{name_snake}}_vm.dart';

void main() {
  test('{{Name}}Vm build returns demo data', () async {
    final h = createVmTestHarness();
    final value = await h.read({{name}}VmProvider.future);
    expect(value, isA<{{Name}}Data>());
    expect(value.items, isNotEmpty);
  });
}
''';
