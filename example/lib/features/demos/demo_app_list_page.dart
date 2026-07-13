import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Fake data ────────────────────────────────────────────────────────────────

class _DemoItem2 {
  _DemoItem2(this.id, this.title, this.color);
  final int id;
  final String title;
  final Color color;
}

// ── Fake repository ──────────────────────────────────────────────────────────

class _DemoRepository2 {
  static const _total = 50;

  Future<List<_DemoItem2>> list({required int page, required int size}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final start = (page - 1) * size;
    if (start >= _total) return [];
    final rng = Random(start);
    return List.generate(
      min(size, _total - start),
      (i) => _DemoItem2(
        start + i,
        'Item #${start + i + 1}',
        Colors.primaries[rng.nextInt(Colors.primaries.length)],
      ),
    );
  }
}

final _repo2Provider = Provider<_DemoRepository2>((_) => _DemoRepository2());

// ── ViewModel ─────────────────────────────────────────────────────────────────

class _Vm2 extends AutoDisposeAsyncNotifier<PagedState<_DemoItem2>>
    with PagedNotifierMixinNoArg<_DemoItem2> {
  @override
  int get pageSize => 10;

  @override
  Future<List<_DemoItem2>> fetchPage(int page, int size) =>
      ref.read(_repo2Provider).list(page: page, size: size);
}

final _provider2 =
    AutoDisposeAsyncNotifierProvider<_Vm2, PagedState<_DemoItem2>>(_Vm2.new);

// ── Page ──────────────────────────────────────────────────────────────────────

class DemoAppListPage extends ConsumerStatefulWidget {
  const DemoAppListPage({super.key});

  @override
  ConsumerState<DemoAppListPage> createState() => _DemoAppListPageState();
}

class _DemoAppListPageState extends ConsumerState<DemoAppListPage> {
  bool _loadMore = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppListPageScaffold<_DemoItem2>(
      title: 'AppListPageScaffold',
      actions: [
        Switch(value: _loadMore, onChanged: (v) => setState(() => _loadMore = v)),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            _loadMore ? 'LoadMore ON' : 'LoadMore OFF',
            style: theme.textTheme.labelSmall,
          ),
        ),
      ],
      provider: _provider2,
      controllerProvider: _provider2.notifier,
      enableLoadMore: _loadMore,
      firstLoading: const SkeletonList(),
      scrollViewBuilder: (ctx, physics, sliverChild) => CustomScrollView(
        physics: physics,
        slivers: [
          SliverAppBar(
            title: const Text('Pinned Header'),
            pinned: true,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                _loadMore
                    ? 'Pull down ↑  Pull up ↓'
                    : 'Pull down ↑  (load more disabled)',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          sliverChild,
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.primaryContainer,
              child: Text(
                'Extra sliver after list',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
      itemBuilder: (ctx, item, _) => ListTile(
        leading: CircleAvatar(
          backgroundColor: item.color,
          child: Text('${item.id}', style: const TextStyle(fontSize: 12)),
        ),
        title: Text(item.title),
      ),
    );
  }
}
