import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ── 测试桩 ───────────────────────────────────────────────────────────────────

class _Counter {
  const _Counter({
    this.value = 0,
    this.status = ViewStatus.idle,
    this.error,
  });
  final int value;
  final ViewStatus status;
  final AppException? error;

  _Counter copyWith({
    int? value,
    ViewStatus? status,
    AppException? error,
    bool clearError = false,
  }) =>
      _Counter(
        value: value ?? this.value,
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  bool operator ==(Object o) =>
      o is _Counter &&
      o.value == value &&
      o.status == status &&
      o.error == error;

  @override
  int get hashCode => Object.hash(value, status, error);
}

/// 公开 run / update / emit 给测试调用（它们在基类里是 @protected）。
class _CounterVm extends ViewModelNotifier<_Counter> {
  @override
  _Counter build() => const _Counter();

  void bump() => update((s) => s.copyWith(value: s.value + 1));

  void bumpReturnSame() =>
      update((s) => s); // identical，应短路不 rebuild

  Future<Result<int>> loadValue(Future<int> Function() action) => run(
        action,
        onStart: (s) =>
            s.copyWith(status: ViewStatus.loading, clearError: true),
        onSuccess: (s, v) => s.copyWith(value: v, status: ViewStatus.ok),
        onFailure: (s, e) => s.copyWith(status: ViewStatus.error, error: e),
      );

  Future<Result<int>> loadValueNoEffect(Future<int> Function() action) => run(
        action,
        onFailure: (s, e) => s.copyWith(status: ViewStatus.error, error: e),
        emitErrorEffect: false,
      );

  void pushToast() => emit(const EffectShowToast('toast'));
}

final _counterVmProvider =
    NotifierProvider.autoDispose<_CounterVm, _Counter>(_CounterVm.new);

// ── Family 版 ────────────────────────────────────────────────────────────────

class _FamilyVm extends FamilyViewModelNotifier<_Counter, int> {
  @override
  _Counter build(int seed) => _Counter(value: seed);

  void bump() => update((s) => s.copyWith(value: s.value + 1));
  void pushToast() => emit(const EffectShowToast('family toast'));
}

final _familyVmProvider =
    NotifierProvider.autoDispose.family<_FamilyVm, _Counter, int>(_FamilyVm.new);

// ── Helpers ──────────────────────────────────────────────────────────────────

/// 订阅一次 provider，阻止 autoDispose 在 await 期间把 VM 回收掉。
/// 测试里凡是有 await（run/mutate）都要先调一次这个。
void _keepAlive<T>(ProviderContainer c, ProviderListenable<T> p) {
  c.listen(p, (_, __) {});
}

Future<List<EffectEnvelope>> _collectEffects(
  ProviderContainer container,
  Future<void> Function() run,
) async {
  final envs = <EffectEnvelope>[];
  final sub = container.read(effectBusProvider).stream.listen(envs.add);
  await run();
  // 让 stream 有机会派发
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return envs;
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('ViewModelNotifier', () {
    test('build 返回初始 state', () {
      expect(container.read(_counterVmProvider), const _Counter());
    });

    test('update 应用 reducer 修改 state', () {
      final vm = container.read(_counterVmProvider.notifier);
      vm.bump();
      vm.bump();
      expect(container.read(_counterVmProvider).value, 2);
    });

    test('update 返回相同实例时短路（不触发 listener）', () {
      var rebuildCount = 0;
      container.listen(
        _counterVmProvider,
        (_, __) => rebuildCount++,
        fireImmediately: false,
      );

      final vm = container.read(_counterVmProvider.notifier);
      vm.bumpReturnSame();
      vm.bumpReturnSame();
      expect(rebuildCount, 0);

      vm.bump();
      expect(rebuildCount, 1);
    });

    test('run 成功：onStart → onSuccess 两次 update', () async {
      final vm = container.read(_counterVmProvider.notifier);

      final statuses = <ViewStatus>[];
      container.listen(
        _counterVmProvider,
        (_, next) => statuses.add(next.status),
        fireImmediately: false,
      );

      final r = await vm.loadValue(() async => 42);
      expect(r, isA<Ok<int>>());
      expect(r.valueOrNull, 42);
      expect(container.read(_counterVmProvider).value, 42);
      expect(container.read(_counterVmProvider).status, ViewStatus.ok);
      expect(statuses, [ViewStatus.loading, ViewStatus.ok]);
    });

    test('run 失败：onStart → onFailure + 默认 emit EffectShowError', () async {
      _keepAlive(container, _counterVmProvider);
      final vm = container.read(_counterVmProvider.notifier);

      final effects = await _collectEffects(container, () async {
        final r = await vm.loadValue(() async {
          throw const NotFoundException(message: 'boom');
        });
        expect(r, isA<Err<int>>());
      });

      expect(container.read(_counterVmProvider).status, ViewStatus.error);
      expect(container.read(_counterVmProvider).error, isA<NotFoundException>());
      expect(effects.length, 1);
      expect(effects.first.source, _CounterVm);
      expect(effects.first.payload, isA<EffectShowError>());
      expect(
        (effects.first.payload as EffectShowError).error,
        isA<NotFoundException>(),
      );
    });

    test('run 失败 + emitErrorEffect=false → 不发 effect', () async {
      _keepAlive(container, _counterVmProvider);
      final vm = container.read(_counterVmProvider.notifier);

      final effects = await _collectEffects(container, () async {
        await vm.loadValueNoEffect(() async {
          throw const NotFoundException(message: 'quiet');
        });
      });

      expect(effects, isEmpty);
      expect(container.read(_counterVmProvider).status, ViewStatus.error);
    });

    test('emit 写入全局 bus（source = 具体 VM runtimeType）', () async {
      _keepAlive(container, _counterVmProvider);
      final vm = container.read(_counterVmProvider.notifier);

      final effects = await _collectEffects(container, () async {
        vm.pushToast();
      });

      expect(effects.length, 1);
      expect(effects.first.source, _CounterVm);
      expect(effects.first.payload, isA<EffectShowToast>());
    });
  });

  group('FamilyViewModelNotifier', () {
    test('build(arg) 接收 family 参数作为种子', () {
      expect(container.read(_familyVmProvider(10)).value, 10);
      expect(container.read(_familyVmProvider(20)).value, 20);
    });

    test('update 隔离在各 family 实例之间', () {
      container.read(_familyVmProvider(0).notifier).bump();
      expect(container.read(_familyVmProvider(0)).value, 1);
      expect(container.read(_familyVmProvider(100)).value, 100,
          reason: 'family(100) 的 state 不应被 family(0) 的 update 污染');
    });

    test('emit source = _FamilyVm', () async {
      final vm = container.read(_familyVmProvider(5).notifier);
      final effects = await _collectEffects(container, () async {
        vm.pushToast();
      });
      expect(effects.single.source, _FamilyVm);
    });
  });
}
