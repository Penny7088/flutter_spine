// `--gen` 模式专用的 vm / provider 模板（riverpod_generator 风格）。
//
// 设计原则：
// * state/data/item/page/test 模板共享——文件结构一样，只有 vm 不同。
// * generator 默认生成的 provider 名 = `<className>Provider`（首字母小写），
//   恰好与本 CLI 手写模板里的 `{{name}}VmProvider` 命名一致——
//   page / test 文件无需任何改动。
// * 业务工程需要先有 `riverpod_annotation` + `build_runner` + `riverpod_generator`
//   的依赖。`flutter_spine:new bootstrap --gen` 可以一次配齐。

const pageVmTemplateGen = r'''
import 'package:flutter_spine/flutter_spine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '{{name_snake}}_state.dart';

part '{{name_snake}}_vm.g.dart';

@riverpod
class {{Name}}Vm extends _${{Name}}Vm with ViewModelMixin<{{Name}}State> {
  @override
  {{Name}}State build() => const {{Name}}State();

  void increment() => update((s) => s.copyWith(counter: s.counter + 1));

  void decrement() => update((s) => s.copyWith(counter: s.counter - 1));

  Future<void> resetWithToast() async {
    update((s) => s.copyWith(counter: 0));
    emit(const EffectShowToast('Reset done', level: ToastLevel.success));
  }
}
''';

const asyncPageVmTemplateGen = r'''
import 'package:flutter_spine/flutter_spine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '{{name_snake}}_data.dart';

part '{{name_snake}}_vm.g.dart';

@riverpod
class {{Name}}Vm extends _${{Name}}Vm with AsyncViewModelMixin<{{Name}}Data> {
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

const pagedListVmTemplateGen = r'''
import 'package:flutter_spine/flutter_spine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '{{name_snake}}_item.dart';

part '{{name_snake}}_vm.g.dart';

@riverpod
class {{Name}}Vm extends _${{Name}}Vm
    with PagedNotifierMixinNoArg<{{Name}}Item> {
  // riverpod_generator 静态扫描 class 必须能看到 build()——
  // 这里转发给 PagedNotifierMixinNoArg 的 default 实现。
  @override
  Future<PagedState<{{Name}}Item>> build() => // ignore: unnecessary_overrides
      super.build();

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

const formVmTemplateGen = r'''
import 'package:flutter_spine/flutter_spine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '{{name_snake}}_state.dart';

part '{{name_snake}}_vm.g.dart';

@riverpod
class {{Name}}Vm extends _${{Name}}Vm with ViewModelMixin<{{Name}}State> {
  @override
  {{Name}}State build() => const {{Name}}State();

  void setUsername(String v) =>
      update((s) => s.copyWith(username: v, errorMsg: null));

  void setPassword(String v) =>
      update((s) => s.copyWith(password: v, errorMsg: null));

  Future<void> submit() async {
    if (!state.canSubmit) return;
    await run<void>(
      () async {
        // TODO: 替换成 ref.read(authRepositoryProvider).login(...)
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      onStart: (s) => s.copyWith(submitting: true, errorMsg: null),
      onSuccess: (s, _) {
        emit(const EffectShowToast('Done', level: ToastLevel.success));
        emit(const EffectPop(true));
        return s.copyWith(submitting: false);
      },
      onFailure: (s, err) => s.copyWith(
        submitting: false,
        errorMsg: err.message,
      ),
    );
  }
}
''';

/// repo 的 provider 用 generator 函数风格——比 class 注解简洁，且与 Provider 语义对得上。
const repoProviderTemplateGen = r'''
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '{{name_snake}}_repository.dart';
import '{{name_snake}}_repository_impl.dart';

part '{{name_snake}}_repository_provider.g.dart';

@Riverpod(keepAlive: true)
{{Name}}Repository {{name}}Repository(Ref ref) {
  return Http{{Name}}Repository(ref.watch(httpClientProvider));
}
''';
