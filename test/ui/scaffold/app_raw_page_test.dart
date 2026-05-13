import 'package:flutter/widgets.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _VmA {}

class _VmB {}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      defaultEffectHandlerProvider
          .overrideWithValue(const NoopDefaultEffectHandler()),
    ],
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );
}

void main() {
  group('AppRawPage', () {
    testWidgets('child 被渲染', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppRawPage(child: Text('body', key: ValueKey('b'))),
      ));
      expect(find.byKey(const ValueKey('b')), findsOneWidget);
    });

    testWidgets('订阅 bus + source 过滤透传 onEffect', (tester) async {
      final received = <Effect>[];
      late EffectBus bus;
      await tester.pumpWidget(_wrap(Consumer(builder: (ctx, ref, _) {
        bus = ref.read(effectBusProvider);
        return AppRawPage(
          source: _VmA,
          onEffect: (_, e) => received.add(e),
          child: const SizedBox.shrink(),
        );
      })));

      bus.emit(_VmA, const EffectShowToast('a'));
      bus.emit(_VmB, const EffectShowToast('b'));
      await tester.pump();

      expect(received.length, 1);
      expect((received.first as EffectShowToast).message, 'a');
    });

    testWidgets('handleDefaultEffects=false 时 handler 不生效', (tester) async {
      final received = <Effect>[];
      late EffectBus bus;
      await tester.pumpWidget(_wrap(Consumer(builder: (ctx, ref, _) {
        bus = ref.read(effectBusProvider);
        return AppRawPage(
          handleDefaultEffects: false,
          onEffect: (_, e) => received.add(e),
          child: const SizedBox.shrink(),
        );
      })));

      bus.emit(_VmA, const EffectShowToast('x'));
      await tester.pump();
      expect(received.length, 1);
    });
  });
}
