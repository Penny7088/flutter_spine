import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 把 handler 装进一个最小 widget tree，便于测 toast / dialog / pop。
Future<BuildContext> _mountAndGetContext(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }),
  ));
  return ctx;
}

void main() {
  group('MaterialDefaultEffectHandler — toast', () {
    testWidgets('默认走 SnackBar', (tester) async {
      const handler = MaterialDefaultEffectHandler();
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ),
      ));

      final ok = handler.handle(
        ctx,
        const EffectShowToast('hello', level: ToastLevel.info),
      );
      await tester.pump();

      expect(ok, isTrue);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('自定义 toast 命中时 short-circuit SnackBar', (tester) async {
      var customCalled = false;
      final handler = MaterialDefaultEffectHandler(
        toast: (ctx, msg, lvl) {
          customCalled = true;
          return true;
        },
      );
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ),
      ));

      handler.handle(ctx, const EffectShowToast('x'));
      await tester.pump();

      expect(customCalled, isTrue);
      expect(find.text('x'), findsNothing); // 没走 SnackBar
    });

    testWidgets('自定义 toast 返回 false 时回退到 SnackBar', (tester) async {
      final handler = MaterialDefaultEffectHandler(
        toast: (ctx, msg, lvl) => false, // 故意拒绝
      );
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ),
      ));

      handler.handle(ctx, const EffectShowToast('fallback'));
      await tester.pump();

      expect(find.text('fallback'), findsOneWidget);
    });

    testWidgets('EffectShowError → SnackBar with error level', (tester) async {
      const handler = MaterialDefaultEffectHandler();
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ),
      ));

      const err = NetworkException(message: 'oops');
      handler.handle(ctx, const EffectShowError(err));
      await tester.pump();

      expect(find.text(err.displayMessage), findsOneWidget);
    });
  });

  group('MaterialDefaultEffectHandler — dialog', () {
    testWidgets('内置 alert：单按钮', (tester) async {
      const handler = MaterialDefaultEffectHandler();
      final ctx = await _mountAndGetContext(tester);

      handler.handle(
        ctx,
        const EffectShowDialog(
          'alert',
          args: {'title': 'T', 'body': 'B', 'ok': 'OK'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('T'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsNothing);
    });

    testWidgets('内置 confirm：双按钮', (tester) async {
      const handler = MaterialDefaultEffectHandler();
      final ctx = await _mountAndGetContext(tester);

      handler.handle(ctx, const EffectShowDialog('confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('业务自定义 dialog 覆盖内置 alert', (tester) async {
      var called = false;
      final handler = MaterialDefaultEffectHandler(
        dialogs: {
          'alert': (ctx, args) async {
            called = true;
          },
        },
      );
      final ctx = await _mountAndGetContext(tester);

      handler.handle(ctx, const EffectShowDialog('alert'));
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('未注册的 dialogId → 返回 false（透传给 onEffect）', (tester) async {
      const handler = MaterialDefaultEffectHandler();
      final ctx = await _mountAndGetContext(tester);

      final ok = handler.handle(ctx, const EffectShowDialog('unknown'));
      expect(ok, isFalse);
    });
  });

  group('MaterialDefaultEffectHandler — pop', () {
    testWidgets('Navigator 可 pop 时走 Navigator.pop', (tester) async {
      const handler = MaterialDefaultEffectHandler();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('home')),
      ));

      // push 一页才能 pop
      unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (c) => Scaffold(body: Builder(builder: (cc) {
          return TextButton(
            onPressed: () =>
                handler.handle(cc, const EffectPop('hi')),
            child: const Text('go'),
          );
        })),
      )));
      await tester.pumpAndSettle();

      expect(find.text('go'), findsOneWidget);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('栈空时返回 false', (tester) async {
      const handler = MaterialDefaultEffectHandler();
      final ctx = await _mountAndGetContext(tester);
      expect(handler.handle(ctx, const EffectPop()), isFalse);
    });
  });

  group('MaterialDefaultEffectHandler — 业务 effect 透传', () {
    testWidgets('业务自定义 effect 一律返回 false', (tester) async {
      const handler = MaterialDefaultEffectHandler();
      final ctx = await _mountAndGetContext(tester);
      expect(handler.handle(ctx, const _MyBizEffect()), isFalse);
    });
  });
}

class _MyBizEffect extends Effect {
  const _MyBizEffect();
}
