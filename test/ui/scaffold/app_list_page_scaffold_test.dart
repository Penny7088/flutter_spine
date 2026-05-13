// ignore_for_file: avoid_public_notifier_properties
// 测试 fixture notifier 暴露 `pages` / `pageSize` 只是为了注入测试数据，
// 不属于生产 API 设计约束。

import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _IntListNotifier extends AutoDisposeAsyncNotifier<PagedState<int>>
    with PagedNotifierMixinNoArg<int> {
  _IntListNotifier({required this.pages});
  final List<List<int>> pages;

  @override
  int get pageSize => 10;

  @override
  Future<List<int>> fetchPage(int page, int size) async {
    if (page - 1 >= pages.length) return const [];
    return pages[page - 1];
  }
}

class _EmptyNotifier extends AutoDisposeAsyncNotifier<PagedState<int>>
    with PagedNotifierMixinNoArg<int> {
  @override
  Future<List<int>> fetchPage(int page, int size) async => const [];
}

final _listProvider =
    AutoDisposeAsyncNotifierProvider<_IntListNotifier, PagedState<int>>(
  () => _IntListNotifier(pages: [
    [1, 2, 3],
  ]),
);

final _emptyProvider =
    AutoDisposeAsyncNotifierProvider<_EmptyNotifier, PagedState<int>>(
  _EmptyNotifier.new,
);

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
  group('AppListPageScaffold', () {
    testWidgets('基础：渲染 AppBar + items', (tester) async {
      await tester.pumpWidget(_wrap(AppListPageScaffold<int>(
        title: 'Items',
        provider: _listProvider,
        controllerProvider: _listProvider.notifier,
        itemBuilder: (ctx, item, i) => ListTile(
          key: ValueKey('item-$item'),
          title: Text('$item'),
        ),
      )));

      await tester.pumpAndSettle();
      expect(find.text('Items'), findsOneWidget);
      expect(find.byKey(const ValueKey('item-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('item-3')), findsOneWidget);
    });

    testWidgets('空态：走 empty slot', (tester) async {
      await tester.pumpWidget(_wrap(AppListPageScaffold<int>(
        title: 'Items',
        provider: _emptyProvider,
        controllerProvider: _emptyProvider.notifier,
        empty: const Text('nothing here', key: ValueKey('empty')),
        itemBuilder: (ctx, item, i) => Text('$item'),
      )));

      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('empty')), findsOneWidget);
    });
  });
}
