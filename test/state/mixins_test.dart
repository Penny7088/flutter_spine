import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验证 [ViewModelMixin] / [AsyncViewModelMixin] 可以**直接**装到原生
/// `AutoDisposeNotifier` / `AutoDisposeAsyncNotifier` 上（不走 `ViewModelNotifier`
/// 基类）——等价于 `riverpod_generator` 生成的 `_$Foo` + `with XxxMixin<T>` 用法。
///
/// 同时反向验证旧 `ViewModelNotifier` 基类 API 不变。

class _GenStyleSyncVm extends AutoDisposeNotifier<int>
    with ViewModelMixin<int> {
  @override
  int build() => 0;

  Future<void> doStuff() async {
    update((s) => s + 1);
    emit(const EffectShowToast('hi'));
    await run<String>(
      () async => 'ok',
      onSuccess: (s, v) => s + 10,
    );
  }
}

class _GenStyleAsyncVm extends AutoDisposeAsyncNotifier<int>
    with AsyncViewModelMixin<int> {
  @override
  Future<int> build() async => 100;

  Future<void> bump() async {
    patch((c) => c + 1);
    emit(const EffectShowToast('bumped'));
    await mutate<String>(
      () async => 'ok',
      applyTo: (curr, _) => curr + 10,
    );
  }
}

class _OldStyleVm extends ViewModelNotifier<int> {
  @override
  int build() => 0;

  void bump() {
    update((s) => s + 1);
    emit(const EffectShowToast('old'));
  }
}

final _genSyncProvider =
    NotifierProvider.autoDispose<_GenStyleSyncVm, int>(_GenStyleSyncVm.new);
final _genAsyncProvider =
    AsyncNotifierProvider.autoDispose<_GenStyleAsyncVm, int>(_GenStyleAsyncVm.new);
final _oldProvider =
    NotifierProvider.autoDispose<_OldStyleVm, int>(_OldStyleVm.new);

ProviderContainer _container() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

/// 把 EffectBus 的事件抓出来。
List<Effect> _captureEffects(ProviderContainer c) {
  final out = <Effect>[];
  final sub = c.read(effectBusProvider).stream.listen((e) => out.add(e.payload));
  addTearDown(sub.cancel);
  return out;
}

void main() {
  group('ViewModelMixin（generator-style class）', () {
    test('update / emit / run 完整通路', () async {
      final c = _container();
      final effects = _captureEffects(c);
      c.listen(_genSyncProvider, (_, __) {}); // keep alive
      expect(c.read(_genSyncProvider), 0);

      await c.read(_genSyncProvider.notifier).doStuff();
      await Future<void>.delayed(Duration.zero);

      // 0 → update +1 → 1 → run.onSuccess (1+10) → 11
      expect(c.read(_genSyncProvider), 11);
      expect(effects, hasLength(1));
      expect(effects.first, isA<EffectShowToast>());
      expect((effects.first as EffectShowToast).message, 'hi');
    });
  });

  group('AsyncViewModelMixin（generator-style class）', () {
    test('patch / emit / mutate 完整通路', () async {
      final c = _container();
      final effects = _captureEffects(c);
      c.listen(_genAsyncProvider, (_, __) {});

      await c.read(_genAsyncProvider.notifier).future;
      expect(c.read(_genAsyncProvider).value, 100);

      await c.read(_genAsyncProvider.notifier).bump();
      await Future<void>.delayed(Duration.zero);

      // 100 → patch +1 → 101 → mutate.applyTo (101+10) → 111
      expect(c.read(_genAsyncProvider).value, 111);
      expect(effects, hasLength(1));
      expect((effects.first as EffectShowToast).message, 'bumped');
    });
  });

  group('ViewModelNotifier 旧基类（API 100% 兼容）', () {
    test('extends ViewModelNotifier 仍然完全工作', () async {
      final c = _container();
      final effects = _captureEffects(c);
      c.listen(_oldProvider, (_, __) {});
      c.read(_oldProvider.notifier).bump();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(_oldProvider), 1);
      expect(effects, hasLength(1));
      expect((effects.single as EffectShowToast).message, 'old');
    });
  });
}
