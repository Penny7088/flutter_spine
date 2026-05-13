import 'package:flutter/material.dart';
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
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('AppTabChildScaffold', () {
    testWidgets('child 被渲染', (tester) async {
      await tester.pumpWidget(_wrap(const AppTabChildScaffold(
        child: Text('tab-body', key: ValueKey('b')),
      )));
      expect(find.byKey(const ValueKey('b')), findsOneWidget);
    });

    testWidgets('source 过滤透传 effect', (tester) async {
      final received = <Effect>[];
      late EffectBus bus;
      await tester.pumpWidget(_wrap(Consumer(builder: (ctx, ref, _) {
        bus = ref.read(effectBusProvider);
        return AppTabChildScaffold(
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

    testWidgets('keepAlive=true 时切走再切回保留 StatefulWidget state',
        (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(SizedBox(
        height: 400,
        child: PageView(
          controller: controller,
          children: const [
            AppTabChildScaffold(child: _Counter(key: ValueKey('counter'))),
            AppTabChildScaffold(child: Text('page-2')),
          ],
        ),
      )));

      // 初始 count=0，点一下变 1
      await tester.tap(find.byKey(const ValueKey('counter')));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      // 翻到第 2 页
      controller.jumpToPage(1);
      await tester.pumpAndSettle();
      expect(find.text('page-2'), findsOneWidget);

      // 翻回来，count 仍是 1（被 KeepAlive 保留）
      controller.jumpToPage(0);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => n++),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 200,
        height: 200,
        child: Center(child: Text('$n')),
      ),
    );
  }
}
