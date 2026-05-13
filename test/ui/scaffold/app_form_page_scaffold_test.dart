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
    child: MaterialApp(home: child),
  );
}

void main() {
  group('AppFormPageScaffold', () {
    testWidgets('渲染 body + bottomAction', (tester) async {
      var submitted = 0;
      await tester.pumpWidget(_wrap(AppFormPageScaffold(
        title: 'Edit',
        body: const Text('form-body', key: ValueKey('body')),
        bottomAction: FilledButton(
          key: const ValueKey('submit'),
          onPressed: () => submitted++,
          child: const Text('Save'),
        ),
      )));

      expect(find.byKey(const ValueKey('body')), findsOneWidget);
      expect(find.byKey(const ValueKey('submit')), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('submit')));
      await tester.pump();
      expect(submitted, 1);
    });

    testWidgets('scrollable=true 时 body 被 SingleChildScrollView 托住',
        (tester) async {
      await tester.pumpWidget(_wrap(const AppFormPageScaffold(
        title: 't',
        body: Text('b'),
        bottomAction: SizedBox(),
      )));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('scrollable=false 时不套 SingleChildScrollView',
        (tester) async {
      await tester.pumpWidget(_wrap(const AppFormPageScaffold(
        title: 't',
        scrollable: false,
        body: Text('b'),
        bottomAction: SizedBox(),
      )));
      expect(find.byType(SingleChildScrollView), findsNothing);
    });
  });
}
