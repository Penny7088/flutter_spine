import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Fake data ────────────────────────────────────────────────────────────────

class _DemoItem {
  _DemoItem(this.id, this.label);
  final int id;
  final String label;
}

// ── Fake repository ──────────────────────────────────────────────────────────

class _DemoRepository {
  static const _total = 50;

  Future<List<_DemoItem>> list({required int page, required int size}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final start = (page - 1) * size;
    if (start >= _total) return [];
    return List.generate(
      min(size, _total - start),
      (i) => _DemoItem(start + i, 'Item #${start + i + 1}'),
    );
  }
}

final _demoRepoProvider = Provider<_DemoRepository>((_) => _DemoRepository());

// ── ViewModel ─────────────────────────────────────────────────────────────────

class _DemoListVm extends AutoDisposeAsyncNotifier<PagedState<_DemoItem>>
    with PagedNotifierMixinNoArg<_DemoItem> {
  @override
  int get pageSize => 10;

  @override
  Future<List<_DemoItem>> fetchPage(int page, int size) =>
      ref.read(_demoRepoProvider).list(page: page, size: size);
}

final _demoListProvider =
    AutoDisposeAsyncNotifierProvider<_DemoListVm, PagedState<_DemoItem>>(
  _DemoListVm.new,
);

// ── Page ──────────────────────────────────────────────────────────────────────

class DemoPagedListPage extends ConsumerStatefulWidget {
  const DemoPagedListPage({super.key});

  @override
  ConsumerState<DemoPagedListPage> createState() => _DemoPagedListPageState();
}

class _DemoPagedListPageState extends ConsumerState<DemoPagedListPage> {
  bool _enableLoadMore = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      title: 'PagedListView + CustomScrollView',
      actions: [
        Switch(
          value: _enableLoadMore,
          onChanged: (v) => setState(() => _enableLoadMore = v),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            _enableLoadMore ? 'LoadMore ON' : 'LoadMore OFF',
            style: theme.textTheme.labelSmall,
          ),
        ),
      ],
      body: PagedListView<_DemoItem>(
        provider: _demoListProvider,
        controllerProvider: _demoListProvider.notifier,
        enableLoadMore: _enableLoadMore,
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
                  _enableLoadMore
                      ? 'Pull down to refresh ↑  Pull up to load more ↓'
                      : 'Pull down to refresh ↑  (load more disabled)',
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
                  'Extra sliver after the list',
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
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text('${item.id}', style: const TextStyle(fontSize: 12)),
          ),
          title: Text(item.label),
          subtitle: Text('Demo item #${item.id + 1}'),
        ),
      ),
    );
  }
}
