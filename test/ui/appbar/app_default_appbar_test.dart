import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _mat(Widget appBar, {Widget body = const SizedBox.shrink()}) {
  return MaterialApp(
    home: Scaffold(
      appBar: appBar as PreferredSizeWidget,
      body: body,
    ),
  );
}

void main() {
  group('AppDefaultAppBar', () {
    testWidgets('title 文字渲染', (tester) async {
      await tester.pumpWidget(_mat(const AppDefaultAppBar(title: 'Hello')));
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('titleWidget 直接渲染', (tester) async {
      await tester.pumpWidget(_mat(
        const AppDefaultAppBar(
          titleWidget: Text('custom', key: ValueKey('tw')),
        ),
      ));
      expect(find.byKey(const ValueKey('tw')), findsOneWidget);
    });

    test('title 与 titleWidget 同时传会断言失败', () {
      expect(
        () => AppDefaultAppBar(title: 'a', titleWidget: const Text('b')),
        throwsAssertionError,
      );
    });

    testWidgets('actions 渲染', (tester) async {
      await tester.pumpWidget(_mat(AppDefaultAppBar(
        title: 't',
        actions: [
          IconButton(
            key: const ValueKey('act'),
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      )));
      expect(find.byKey(const ValueKey('act')), findsOneWidget);
    });

    testWidgets('onBack 会覆盖默认 leading 并被触发', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_mat(AppDefaultAppBar(
        title: 't',
        onBack: () => tapped++,
      )));
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('显式 leading 优先于 onBack', (tester) async {
      await tester.pumpWidget(_mat(AppDefaultAppBar(
        title: 't',
        leading: const SizedBox(key: ValueKey('leading')),
        onBack: () {},
      )));
      expect(find.byKey(const ValueKey('leading')), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('preferredSize 包含 bottom 的高度', (tester) async {
      const bottom = PreferredSize(
        preferredSize: Size.fromHeight(40),
        child: SizedBox(height: 40),
      );
      const appBar = AppDefaultAppBar(title: 't', bottom: bottom);
      expect(appBar.preferredSize.height, kToolbarHeight + 40);
    });
  });
}
