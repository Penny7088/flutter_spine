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
    child: MaterialApp(home: child),
  );
}

void main() {
  group('AppPageScaffold', () {
    testWidgets('title 渲染为默认 AppBar', (tester) async {
      await tester.pumpWidget(_wrap(const AppPageScaffold(
        title: 'Hello',
        body: Text('body'),
      )));
      expect(find.byType(AppDefaultAppBar), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('不传 title/actions/leading 时不渲染 AppBar', (tester) async {
      await tester.pumpWidget(_wrap(const AppPageScaffold(
        body: Text('body'),
      )));
      expect(find.byType(AppDefaultAppBar), findsNothing);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('自定义 appBar 完全覆盖 title', (tester) async {
      await tester.pumpWidget(_wrap(AppPageScaffold(
        appBar: AppBar(title: const Text('custom')),
        body: const Text('body'),
      )));
      expect(find.text('custom'), findsOneWidget);
      expect(find.byType(AppDefaultAppBar), findsNothing);
    });

    test('appBar 与 title 同时传触发断言', () {
      expect(
        () => AppPageScaffold(
          appBar: AppBar(),
          title: 't',
          body: const SizedBox.shrink(),
        ),
        throwsAssertionError,
      );
    });

    testWidgets('bottomBar 渲染到底部', (tester) async {
      await tester.pumpWidget(_wrap(const AppPageScaffold(
        title: 't',
        body: Text('body'),
        bottomBar: Text('submit', key: ValueKey('sub')),
      )));
      expect(find.byKey(const ValueKey('sub')), findsOneWidget);
    });

    testWidgets('bottomBar 与 bottomNavigationBar 同时传触发断言', (tester) async {
      await tester.pumpWidget(_wrap(const AppPageScaffold(
        body: Text('body'),
        bottomBar: SizedBox.shrink(),
        bottomNavigationBar: SizedBox.shrink(),
      )));
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets('点击空白处收起键盘', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_wrap(AppPageScaffold(
        title: 't',
        body: TextField(focusNode: focus, autofocus: true),
      )));
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      // 点 AppBar 附近的空白（body 之外，避免戳到 TextField）
      await tester.tapAt(const Offset(10, 200));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    });

    testWidgets('dismissKeyboardOnTap=false 时不收起键盘', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_wrap(AppPageScaffold(
        title: 't',
        dismissKeyboardOnTap: false,
        body: TextField(focusNode: focus, autofocus: true),
      )));
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      await tester.tapAt(const Offset(10, 200));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('source 过滤：只收本 VM 的 effect', (tester) async {
      final received = <Effect>[];
      late EffectBus bus;
      await tester.pumpWidget(_wrap(Consumer(builder: (ctx, ref, _) {
        bus = ref.read(effectBusProvider);
        return AppPageScaffold(
          title: 't',
          source: _VmA,
          onEffect: (_, e) => received.add(e),
          body: const SizedBox.shrink(),
        );
      })));

      bus.emit(_VmA, const EffectShowToast('a'));
      bus.emit(_VmB, const EffectShowToast('b'));
      await tester.pump();

      expect(received.length, 1);
      expect((received.first as EffectShowToast).message, 'a');
    });
  });
}
