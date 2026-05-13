import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _VmA {}

class _VmB {}

void main() {
  group('EffectBus', () {
    late EffectBus bus;

    setUp(() => bus = EffectBus());
    tearDown(() => bus.close());

    test('emit 推送 EffectEnvelope 到 stream', () async {
      final future = bus.stream.first;
      bus.emit(_VmA, const EffectShowToast('hi'));

      final env = await future;
      expect(env.source, _VmA);
      expect(env.payload, isA<EffectShowToast>());
      expect((env.payload as EffectShowToast).message, 'hi');
    });

    test('broadcast 支持多订阅者', () async {
      final a = <EffectEnvelope>[];
      final b = <EffectEnvelope>[];
      final subA = bus.stream.listen(a.add);
      final subB = bus.stream.listen(b.add);

      bus.emit(_VmA, const EffectShowToast('first'));
      bus.emit(_VmB, const EffectPop());
      await Future<void>.delayed(Duration.zero);

      expect(a.length, 2);
      expect(b.length, 2);
      expect(a[0].source, _VmA);
      expect(a[1].source, _VmB);

      await subA.cancel();
      await subB.cancel();
    });

    test('close 后 emit 静默忽略', () async {
      await bus.close();
      expect(bus.isClosed, isTrue);

      expect(() => bus.emit(_VmA, const EffectPop()), returnsNormally);
    });

    test('close 可安全重复调用', () async {
      await bus.close();
      await bus.close();
      expect(bus.isClosed, isTrue);
    });
  });

  group('effectBusProvider', () {
    test('容器内返回稳定单例', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bus1 = container.read(effectBusProvider);
      final bus2 = container.read(effectBusProvider);
      expect(identical(bus1, bus2), isTrue);
    });

    test('container 销毁时 bus 自动关闭', () async {
      final container = ProviderContainer();
      final bus = container.read(effectBusProvider);
      expect(bus.isClosed, isFalse);

      container.dispose();
      // onDispose 是异步触发 close()，等一帧
      await Future<void>.delayed(Duration.zero);
      expect(bus.isClosed, isTrue);
    });
  });

  group('EffectEnvelope', () {
    test('携带 source 与 payload', () {
      const payload = EffectShowToast('x', level: ToastLevel.warn);
      const env = EffectEnvelope(source: _VmA, payload: payload);
      expect(env.source, _VmA);
      expect(env.payload, payload);
    });

    test('toString 包含 source 与 payload', () {
      const env = EffectEnvelope(
        source: _VmA,
        payload: EffectShowToast('hello'),
      );
      final s = env.toString();
      expect(s, contains('_VmA'));
      expect(s, contains('hello'));
    });
  });
}
