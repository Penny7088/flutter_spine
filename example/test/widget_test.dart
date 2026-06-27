import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/app/router.dart';

void main() {
  testWidgets('App renders and navigates to new task page',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: buildRouter(),
        ),
      ),
    );

    // 首页应该显示 TabBar
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Demos'), findsOneWidget);
  });
}
