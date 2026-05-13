import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      defaultEffectHandlerProvider
          .overrideWithValue(const NoopDefaultEffectHandler()),
    ],
    child: MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  group('AppBottomSheetScaffold', () {
    testWidgets('默认展示 drag handle，渲染 title 与 body', (tester) async {
      await tester.pumpWidget(_wrap(const AppBottomSheetScaffold(
        title: 'Pick one',
        body: Text('body', key: ValueKey('b')),
      )));

      expect(find.text('Pick one'), findsOneWidget);
      expect(find.byKey(const ValueKey('b')), findsOneWidget);
    });

    test('title 与 titleWidget 同时传触发断言', () {
      expect(
        () => AppBottomSheetScaffold(
          title: 'a',
          titleWidget: const Text('b'),
          body: const SizedBox.shrink(),
        ),
        throwsAssertionError,
      );
    });

    testWidgets('showDragHandle=false 时不渲染 handle', (tester) async {
      await tester.pumpWidget(_wrap(const AppBottomSheetScaffold(
        title: 't',
        showDragHandle: false,
        body: SizedBox.shrink(),
      )));

      // drag handle 是一个固定 36x4 的 Container，没有公开 key，
      // 用父 Column 子节点计数间接断言：
      final col = tester.widget<Column>(find.byType(Column).first);
      // children: [ header, Flexible(body) ] —— 没有 drag handle
      expect(col.children.length, 2);
    });

    testWidgets('showCloseButton=true 时渲染 ✕ 按钮', (tester) async {
      var closed = 0;
      await tester.pumpWidget(_wrap(AppBottomSheetScaffold(
        title: 't',
        showCloseButton: true,
        onClose: () => closed++,
        body: const SizedBox.shrink(),
      )));

      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(closed, 1);
    });

    testWidgets('actions 渲染在 header', (tester) async {
      await tester.pumpWidget(_wrap(AppBottomSheetScaffold(
        title: 't',
        actions: [
          IconButton(
            key: const ValueKey('act'),
            icon: const Icon(Icons.refresh),
            onPressed: () {},
          ),
        ],
        body: const SizedBox.shrink(),
      )));
      expect(find.byKey(const ValueKey('act')), findsOneWidget);
    });
  });
}
