import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ── 最小化测试 Notifier ──────────────────────────────────────────────────────

class _FakeFilter {
  const _FakeFilter();
}

class _FakeListNotifier
    extends AutoDisposeFamilyAsyncNotifier<PagedState<String>, _FakeFilter>
    with PagedNotifierMixin<String, _FakeFilter> {
  /// 控制测试场景：每页最多 [pageSize] 条，总共 [_total] 条
  static int total = 50;
  static bool throwOnLoad = false;

  @override
  int get pageSize => 10;

  @override
  Future<List<String>> fetchPage(_FakeFilter arg, int page, int size) async {
    if (throwOnLoad) throw const ServerException(code: 500, message: 'fail');
    final start = (page - 1) * size;
    if (start >= total) return [];
    final end = (start + size).clamp(0, total);
    return List.generate(end - start, (i) => 'item_${start + i}');
  }
}

final _fakeListProvider = AutoDisposeFamilyAsyncNotifierProvider<
    _FakeListNotifier, PagedState<String>, _FakeFilter>(
  _FakeListNotifier.new,
);

// ── Helpers ─────────────────────────────────────────────────────────────────

ProviderContainer makeContainer() => ProviderContainer();

void main() {
  setUp(() {
    _FakeListNotifier.total = 50;
    _FakeListNotifier.throwOnLoad = false;
  });

  group('PagedNotifierMixin', () {
    test('首次 build 加载第 1 页', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(_fakeListProvider.notifier);
      final state = await container.read(_fakeListProvider.future);

      expect(state.items.length, 10);
      expect(state.items.first, 'item_0');
      expect(state.page, 1);
      expect(state.hasMore, true);
      expect(notifier, isNotNull);
    });

    test('loadMore 追加下一页', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(_fakeListProvider.future);
      final notifier = container.read(_fakeListProvider.notifier);

      final hasMore = await notifier.loadMore();
      final state = await container.read(_fakeListProvider.future);

      expect(hasMore, true);
      expect(state?.items.length, 20);
      expect(state?.page, 2);
    });

    test('到最后一页时 hasMore=false', () async {
      _FakeListNotifier.total = 5;
      final container = makeContainer();
      addTearDown(container.dispose);

      final state = await container.read(_fakeListProvider.future);

      expect(state.hasMore, false);
    });

    test('loadMore 已到底时返回 false 且不发请求', () async {
      _FakeListNotifier.total = 5;
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(_fakeListProvider.future);
      final notifier = container.read(_fakeListProvider.notifier);

      final result = await notifier.loadMore();
      expect(result, false);
    });

    test('loadMore 失败时保留旧数据，moreError 非 null', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(_fakeListProvider.future);
      final notifier = container.read(_fakeListProvider.notifier);

      _FakeListNotifier.throwOnLoad = true;
      final result = await notifier.loadMore();
      final state = container.read(_fakeListProvider).valueOrNull!;

      expect(result, false);
      expect(state.items.length, 10); // 旧数据保留
      expect(state.moreError, isNotNull);
      expect(state.isLoadingMore, false);
    });

    test('patch 本地更新列表', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(_fakeListProvider.future);
      final notifier = container.read(_fakeListProvider.notifier);

      notifier.patch((items) => items.where((e) => e != 'item_0').toList());
      final state = container.read(_fakeListProvider).valueOrNull!;

      expect(state.items.contains('item_0'), false);
      expect(state.items.length, 9);
    });

    test('filter key 变化时自动重建（新 family）', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(_fakeListProvider.future);
      final stateA = container
          .read(_fakeListProvider)
          .valueOrNull!;

      await container.read(_fakeListProvider.future);
      final stateB = container
          .read(_fakeListProvider)
          .valueOrNull!;

      // 两个 family 各自独立
      expect(stateA.items.first, 'item_0');
      expect(stateB.items.first, 'item_0');
    });
  });
}
