import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ── 测试桩 ───────────────────────────────────────────────────────────────────

class _Profile {
  const _Profile({required this.name, required this.age});
  final String name;
  final int age;
  _Profile copyWith({String? name, int? age}) =>
      _Profile(name: name ?? this.name, age: age ?? this.age);

  @override
  bool operator ==(Object o) =>
      o is _Profile && o.name == name && o.age == age;
  @override
  int get hashCode => Object.hash(name, age);
}

/// 由外部注入"如何加载 Profile"——测试里可以换各种 stub。
final _profileLoaderProvider =
    Provider<Future<_Profile> Function()>((_) => () async => throw UnimplementedError());

/// 由外部注入"如何 rename"——测试里可以换各种 stub。
final _profileRenamerProvider =
    Provider<Future<String> Function(String newName)>(
        (_) => (_) async => throw UnimplementedError());

class _ProfileVm extends AsyncViewModelNotifier<_Profile> {
  @override
  Future<_Profile> build() => ref.read(_profileLoaderProvider)();

  Future<void> applyRename(String name) async {
    await mutate(
      () => ref.read(_profileRenamerProvider)(name),
      applyTo: (curr, result) => curr.copyWith(name: result),
    );
  }

  Future<void> renameNoApply(String name) async {
    await mutate(() => ref.read(_profileRenamerProvider)(name));
  }

  Future<void> renameNoEffect(String name) async {
    await mutate(
      () => ref.read(_profileRenamerProvider)(name),
      applyTo: (curr, r) => curr.copyWith(name: r),
      emitErrorEffect: false,
    );
  }

  void pushToast() => emit(const EffectShowToast('hi'));

  void patchAge(int age) =>
      patch((curr) => curr.copyWith(age: age));
}

final _profileVmProvider =
    AsyncNotifierProvider.autoDispose<_ProfileVm, _Profile>(_ProfileVm.new);

// ── Family 版桩 ──────────────────────────────────────────────────────────────

final _familyLoaderProvider =
    Provider<Future<_Profile> Function(int id)>((_) =>
        (id) async => _Profile(name: 'u$id', age: id));

class _FamilyProfileVm
    extends FamilyAsyncViewModelNotifier<_Profile, int> {
  @override
  Future<_Profile> build(int id) => ref.read(_familyLoaderProvider)(id);

  void pushToast() => emit(const EffectShowToast('family'));

  void patchAge(int age) => patch((curr) => curr.copyWith(age: age));
}

final _familyProfileVmProvider = AsyncNotifierProvider.autoDispose
    .family<_FamilyProfileVm, _Profile, int>(_FamilyProfileVm.new);

// ── Helpers ──────────────────────────────────────────────────────────────────

/// 订阅一次 provider，阻止 autoDispose 在 await 期间把 VM 回收掉。
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
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return envs;
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('AsyncViewModelNotifier', () {
    test('build 成功 → state = AsyncData', () async {
      final container = ProviderContainer(overrides: [
        _profileLoaderProvider
            .overrideWithValue(() async => const _Profile(name: 'a', age: 1)),
      ]);
      addTearDown(container.dispose);

      final v = await container.read(_profileVmProvider.future);
      expect(v, const _Profile(name: 'a', age: 1));
      expect(container.read(_profileVmProvider).hasValue, isTrue);
    });

    test('build 抛 AppException → state = AsyncError', () async {
      final container = ProviderContainer(overrides: [
        _profileLoaderProvider.overrideWithValue(
          () async => throw const NotFoundException(message: 'no user'),
        ),
      ]);
      addTearDown(container.dispose);

      // 主动触发 build
      await expectLater(
        container.read(_profileVmProvider.future),
        throwsA(isA<NotFoundException>()),
      );
      expect(container.read(_profileVmProvider).hasError, isTrue);
    });

    test('patch 在有数据时更新 state', () async {
      final container = ProviderContainer(overrides: [
        _profileLoaderProvider
            .overrideWithValue(() async => const _Profile(name: 'a', age: 1)),
      ]);
      addTearDown(container.dispose);

      await container.read(_profileVmProvider.future);
      container.read(_profileVmProvider.notifier).patchAge(99);

      expect(container.read(_profileVmProvider).valueOrNull!.age, 99);
      expect(container.read(_profileVmProvider).valueOrNull!.name, 'a');
    });

    test('patch 在无数据时 no-op（loading/error 中）', () async {
      // 用 Completer 模拟"永远 loading"
      final container = ProviderContainer(overrides: [
        _profileLoaderProvider.overrideWithValue(() async {
          await Future<void>.delayed(const Duration(hours: 1));
          return const _Profile(name: 'x', age: 0);
        }),
      ]);
      addTearDown(container.dispose);

      container.read(_profileVmProvider); // 触发 build
      // 此时 state 是 AsyncLoading，没有 value
      expect(container.read(_profileVmProvider).valueOrNull, isNull);

      // patch 不应该崩溃
      expect(
        () => container.read(_profileVmProvider.notifier).patchAge(42),
        returnsNormally,
      );
      expect(container.read(_profileVmProvider).valueOrNull, isNull);
    });

    test('mutate 成功 + applyTo → patch 到 state', () async {
      final container = ProviderContainer(overrides: [
        _profileLoaderProvider
            .overrideWithValue(() async => const _Profile(name: 'old', age: 30)),
        _profileRenamerProvider.overrideWithValue((name) async => name),
      ]);
      addTearDown(container.dispose);

      await container.read(_profileVmProvider.future);
      await container.read(_profileVmProvider.notifier).applyRename('new');

      expect(container.read(_profileVmProvider).valueOrNull!.name, 'new');
      expect(container.read(_profileVmProvider).valueOrNull!.age, 30);
    });

    test('mutate 成功 + 无 applyTo → state 不变', () async {
      final container = ProviderContainer(overrides: [
        _profileLoaderProvider
            .overrideWithValue(() async => const _Profile(name: 'x', age: 1)),
        _profileRenamerProvider.overrideWithValue((_) async => 'ignored'),
      ]);
      addTearDown(container.dispose);

      await container.read(_profileVmProvider.future);
      final before = container.read(_profileVmProvider).valueOrNull;
      await container.read(_profileVmProvider.notifier).renameNoApply('y');

      expect(container.read(_profileVmProvider).valueOrNull, before);
    });

    test('mutate 失败：默认发 EffectShowError + state 不变', () async {
      final container = ProviderContainer(overrides: [
        _profileLoaderProvider
            .overrideWithValue(() async => const _Profile(name: 'a', age: 1)),
        _profileRenamerProvider.overrideWithValue(
          (_) async => throw const ForbiddenException(message: 'no perm'),
        ),
      ]);
      addTearDown(container.dispose);
      _keepAlive(container, _profileVmProvider);

      await container.read(_profileVmProvider.future);
      final before = container.read(_profileVmProvider).valueOrNull;

      final effects = await _collectEffects(container, () async {
        await container.read(_profileVmProvider.notifier).applyRename('z');
      });

      expect(container.read(_profileVmProvider).valueOrNull, before,
          reason: '失败时不应 patch');
      expect(effects.length, 1);
      expect(effects.first.source, _ProfileVm);
      expect(effects.first.payload, isA<EffectShowError>());
    });

    test('mutate 失败 + emitErrorEffect=false → 不发 effect', () async {
      final container = ProviderContainer(overrides: [
        _profileLoaderProvider
            .overrideWithValue(() async => const _Profile(name: 'a', age: 1)),
        _profileRenamerProvider.overrideWithValue(
          (_) async => throw const ForbiddenException(message: 'no'),
        ),
      ]);
      addTearDown(container.dispose);

      await container.read(_profileVmProvider.future);

      final effects = await _collectEffects(container, () async {
        await container.read(_profileVmProvider.notifier).renameNoEffect('z');
      });

      expect(effects, isEmpty);
    });

    test('refresh 触发重新 build', () async {
      var callCount = 0;
      final container = ProviderContainer(overrides: [
        _profileLoaderProvider.overrideWithValue(() async {
          callCount++;
          return _Profile(name: 'a$callCount', age: callCount);
        }),
      ]);
      addTearDown(container.dispose);

      final v1 = await container.read(_profileVmProvider.future);
      expect(v1.name, 'a1');

      await container.read(_profileVmProvider.notifier).refresh();
      expect(callCount, 2);
      expect(container.read(_profileVmProvider).valueOrNull!.name, 'a2');
    });

    test('emit source = _ProfileVm', () async {
      final container = ProviderContainer(overrides: [
        _profileLoaderProvider
            .overrideWithValue(() async => const _Profile(name: 'a', age: 1)),
      ]);
      addTearDown(container.dispose);

      await container.read(_profileVmProvider.future);

      final effects = await _collectEffects(container, () async {
        container.read(_profileVmProvider.notifier).pushToast();
      });

      expect(effects.single.source, _ProfileVm);
      expect(effects.single.payload, isA<EffectShowToast>());
    });
  });

  group('FamilyAsyncViewModelNotifier', () {
    test('build(arg) 使用 family 参数', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final v1 = await container.read(_familyProfileVmProvider(7).future);
      final v2 = await container.read(_familyProfileVmProvider(8).future);
      expect(v1.age, 7);
      expect(v2.age, 8);
    });

    test('patch 隔离在各 family 实例之间', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(_familyProfileVmProvider(1).future);
      await container.read(_familyProfileVmProvider(2).future);

      container.read(_familyProfileVmProvider(1).notifier).patchAge(999);

      expect(
        container.read(_familyProfileVmProvider(1)).valueOrNull!.age,
        999,
      );
      expect(
        container.read(_familyProfileVmProvider(2)).valueOrNull!.age,
        2,
        reason: 'family(2) 不应被 family(1) 的 patch 污染',
      );
    });

    test('emit source = _FamilyProfileVm', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(_familyProfileVmProvider(5).future);

      final effects = await _collectEffects(container, () async {
        container.read(_familyProfileVmProvider(5).notifier).pushToast();
      });
      expect(effects.single.source, _FamilyProfileVm);
    });
  });
}
