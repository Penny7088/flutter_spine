import 'package:flutter/widgets.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ── 测试桩 ───────────────────────────────────────────────────────────────────

class _VmA {}

class _VmB {}

/// 可配置的 handler：根据 effect 类型决定返回 true / false。
class _FakeHandler extends DefaultEffectHandler {
  const _FakeHandler({this.swallowToast = false});

  /// true → EffectShowToast 会被处理（返回 true，短路业务回调）。
  final bool swallowToast;

  @override
  bool handle(BuildContext ctx, Effect effect) {
    if (effect is EffectShowToast && swallowToast) return true;
    return false;
  }
}

/// 记录 handler 调用的 handler，便于测试 handleDefaults=false 分支。
class _RecordingHandler extends DefaultEffectHandler {
  _RecordingHandler();
  final List<Effect> received = [];

  @override
  bool handle(BuildContext ctx, Effect effect) {
    received.add(effect);
    return false;
  }
}

Widget _wrap({
  required Widget child,
  DefaultEffectHandler handler = const NoopDefaultEffectHandler(),
}) {
  return ProviderScope(
    overrides: [
      defaultEffectHandlerProvider.overrideWithValue(handler),
    ],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: child,
    ),
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('EffectListener', () {
    testWidgets('无 source 过滤时收到全量 effect', (tester) async {
      final received = <Effect>[];
      late EffectBus bus;

      await tester.pumpWidget(_wrap(
        child: Consumer(builder: (ctx, ref, _) {
          bus = ref.read(effectBusProvider);
          return EffectListener(
            onEffect: (_, e) => received.add(e),
            child: const SizedBox.shrink(),
          );
        }),
      ));

      bus.emit(_VmA, const EffectShowToast('a'));
      bus.emit(_VmB, const EffectPop());
      await tester.pump();

      expect(received.length, 2);
      expect(received[0], isA<EffectShowToast>());
      expect(received[1], isA<EffectPop>());
    });

    testWidgets('source 过滤：只收指定 VM 的 effect', (tester) async {
      final received = <Effect>[];
      late EffectBus bus;

      await tester.pumpWidget(_wrap(
        child: Consumer(builder: (ctx, ref, _) {
          bus = ref.read(effectBusProvider);
          return EffectListener(
            source: _VmA,
            onEffect: (_, e) => received.add(e),
            child: const SizedBox.shrink(),
          );
        }),
      ));

      bus.emit(_VmA, const EffectShowToast('from A'));
      bus.emit(_VmB, const EffectShowToast('from B'));
      bus.emit(_VmA, const EffectPop());
      await tester.pump();

      expect(received.length, 2);
      expect((received[0] as EffectShowToast).message, 'from A');
      expect(received[1], isA<EffectPop>());
    });

    testWidgets('handler 返回 true 时短路业务回调', (tester) async {
      final received = <Effect>[];
      late EffectBus bus;

      await tester.pumpWidget(_wrap(
        handler: const _FakeHandler(swallowToast: true),
        child: Consumer(builder: (ctx, ref, _) {
          bus = ref.read(effectBusProvider);
          return EffectListener(
            onEffect: (_, e) => received.add(e),
            child: const SizedBox.shrink(),
          );
        }),
      ));

      bus.emit(_VmA, const EffectShowToast('swallowed'));
      bus.emit(_VmA, const EffectPop());
      await tester.pump();

      // toast 被 handler 吞掉，pop 未处理透传
      expect(received.length, 1);
      expect(received[0], isA<EffectPop>());
    });

    testWidgets('handleDefaults=false 时 handler 不被调用', (tester) async {
      final handler = _RecordingHandler();
      final received = <Effect>[];
      late EffectBus bus;

      await tester.pumpWidget(_wrap(
        handler: handler,
        child: Consumer(builder: (ctx, ref, _) {
          bus = ref.read(effectBusProvider);
          return EffectListener(
            handleDefaults: false,
            onEffect: (_, e) => received.add(e),
            child: const SizedBox.shrink(),
          );
        }),
      ));

      bus.emit(_VmA, const EffectShowToast('x'));
      await tester.pump();

      expect(handler.received, isEmpty);
      expect(received.length, 1);
    });

    testWidgets('widget dispose 后不再回调', (tester) async {
      final received = <Effect>[];
      late EffectBus bus;
      late ProviderContainer container;

      await tester.pumpWidget(_wrap(
        child: Consumer(builder: (ctx, ref, _) {
          bus = ref.read(effectBusProvider);
          container = ProviderScope.containerOf(ctx);
          return EffectListener(
            onEffect: (_, e) => received.add(e),
            child: const SizedBox.shrink(),
          );
        }),
      ));

      bus.emit(_VmA, const EffectShowToast('before'));
      await tester.pump();
      expect(received.length, 1);

      // 卸载 widget，但 bus 还活着（container 还在）
      await tester.pumpWidget(const SizedBox.shrink());
      bus.emit(_VmA, const EffectShowToast('after'));
      await tester.pump();
      expect(received.length, 1, reason: 'dispose 后的 emit 不应进入 onEffect');

      // 手动 dispose container，避免测试残留
      container.dispose();
    });
  });

  group('NoopDefaultEffectHandler', () {
    test('handle 永远返回 false', () {
      const handler = NoopDefaultEffectHandler();
      // BuildContext 参数在 Noop 里不被使用，直接传 _FakeContext 无意义——
      // 这里用一个 throwing 代理确认确实没访问。
      expect(
        handler.handle(_UnusedContext(), const EffectShowToast('x')),
        isFalse,
      );
      expect(
        handler.handle(_UnusedContext(), const EffectPop()),
        isFalse,
      );
    });
  });

  group('defaultEffectHandlerProvider', () {
    test('未 override 时读取抛 UnimplementedError', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(defaultEffectHandlerProvider),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('override 为 NoopDefaultEffectHandler 可正常读取', () {
      final container = ProviderContainer(overrides: [
        defaultEffectHandlerProvider
            .overrideWithValue(const NoopDefaultEffectHandler()),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(defaultEffectHandlerProvider),
        isA<NoopDefaultEffectHandler>(),
      );
    });
  });
}

/// 仅作占位，用于断言 Noop handler 不访问 context。
class _UnusedContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('NoopDefaultEffectHandler 不应访问 BuildContext');
}
