import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/page_state/empty_view.dart';
import '../presentation/page_state/error_view.dart';
import '../presentation/page_state/loading_view.dart';
import 'paged_notifier_mixin.dart';
import 'paged_state.dart';

/// 通用分页列表视图。内置 EasyRefresh + 五态状态机：
///
/// ```
/// 首屏 loading  → [firstLoading]（默认 LoadingView，推荐传 SkeletonList）
/// 首屏 error    → [firstError]（默认 ErrorView + retry）
/// 空态          → [empty]（默认 EmptyView）
/// 正常列表       → EasyRefresh + ListView（含下拉刷新 / 上拉加载更多）
/// 加载更多失败   → [moreErrorBuilder]（默认 MoreErrorBar，贴在列表底部）
/// ```
///
/// 用法：
/// ```dart
/// PagedListView<OrderItem>(
///   provider: c2cOrderListProvider(filter),
///   controllerProvider: c2cOrderListProvider(filter).notifier,
///   itemBuilder: (ctx, item, i) => OrderItemCard(item),
///   empty: const OrderEmptyView(),
///   firstLoading: const ShimmerSkeletonList(),
/// )
/// ```
class PagedListView<T> extends ConsumerStatefulWidget {
  const PagedListView({
    super.key,
    required this.provider,
    required this.controllerProvider,
    required this.itemBuilder,
    this.separatorBuilder,
    this.firstLoading,
    this.firstError,
    this.empty,
    this.moreErrorBuilder,
    this.noMore,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.easyRefreshController,
    this.header,
    this.footer,
  });

  /// 监听的 provider（类型为 `AsyncValue<PagedState<T>>`）。
  final ProviderListenable<AsyncValue<PagedState<T>>> provider;

  /// Notifier provider，需实现 [PagedController]。
  /// 用于调用 `refresh()` / `loadMore()`。
  final ProviderListenable<PagedController> controllerProvider;

  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context, int index)? separatorBuilder;

  // ── 状态 slots ──────────────────────────────────────────────────────────

  /// 首屏加载。null → [LoadingView]。推荐传 `SkeletonList()`。
  final Widget? firstLoading;

  /// 首屏加载失败（参数：error, retry）。null → [ErrorView]。
  final Widget Function(Object error, VoidCallback retry)? firstError;

  /// 空态。null → [EmptyView]。
  final Widget? empty;

  /// 加载更多失败（参数：error, retry）。null → [MoreErrorBar]。
  final Widget Function(Object error, VoidCallback retry)? moreErrorBuilder;

  /// 没有更多数据时的底部提示。null → 空 [SizedBox]。
  final Widget? noMore;

  // ── 布局 ────────────────────────────────────────────────────────────────

  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  /// EasyRefresh header / footer 定制（null 时使用全局默认）。
  final Header? header;
  final Footer? footer;

  /// 外部传入可复用；不传则组件内部自建（dispose 由组件负责）。
  final EasyRefreshController? easyRefreshController;

  @override
  ConsumerState<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends ConsumerState<PagedListView<T>> {
  late EasyRefreshController _controller;
  bool _controllerOwned = false;

  @override
  void initState() {
    super.initState();
    if (widget.easyRefreshController != null) {
      _controller = widget.easyRefreshController!;
    } else {
      _controller = EasyRefreshController(
        controlFinishRefresh: true,
        controlFinishLoad: true,
      );
      _controllerOwned = true;
    }
  }

  @override
  void dispose() {
    if (_controllerOwned) _controller.dispose();
    super.dispose();
  }

  PagedController get _notifier =>
      ref.read(widget.controllerProvider);

  Future<void> _onRefresh() async {
    try {
      await _notifier.refresh();
      _controller.finishRefresh(IndicatorResult.success);
    } catch (_) {
      _controller.finishRefresh(IndicatorResult.fail);
    }
  }

  Future<void> _onLoad() async {
    try {
      final hasMore = await _notifier.loadMore();
      _controller.finishLoad(
        hasMore ? IndicatorResult.success : IndicatorResult.noMore,
      );
    } catch (_) {
      _controller.finishLoad(IndicatorResult.fail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(widget.provider);

    // ── 首屏 loading ────────────────────────────────────────────────────
    if (!value.hasValue && value.isLoading) {
      return widget.firstLoading ?? const LoadingView();
    }

    // ── 首屏 error ──────────────────────────────────────────────────────
    if (value.hasError && !value.hasValue) {
      final retry = _buildFirstRetry();
      return widget.firstError?.call(value.error!, retry) ??
          ErrorView(error: value.error!, onRetry: retry);
    }

    // ── 有数据（含刷新中保留旧数据） ────────────────────────────────────
    final state = value.valueOrNull ?? const PagedState();

    if (state.isEmpty) {
      return widget.empty ?? const EmptyView();
    }

    return _buildRefreshableList(state);
  }

  Widget _buildRefreshableList(PagedState<T> state) {
    final items = state.items;

    // 计算 itemCount：items + moreError 条 + noMore 条（各最多1）
    final extraBottom = (state.moreError != null || (!state.hasMore)) ? 1 : 0;
    final itemCount = items.length + extraBottom;

    return EasyRefresh(
      controller: _controller,
      header: widget.header,
      footer: widget.footer,
      onRefresh: _onRefresh,
      onLoad: state.hasMore ? _onLoad : null,
      child: widget.separatorBuilder != null
          ? ListView.separated(
              padding: widget.padding,
              physics: widget.physics,
              shrinkWrap: widget.shrinkWrap,
              itemCount: itemCount,
              separatorBuilder: (ctx, i) =>
                  i < items.length - 1
                      ? widget.separatorBuilder!(ctx, i)
                      : const SizedBox.shrink(),
              itemBuilder: (ctx, i) => _buildItem(ctx, i, items, state),
            )
          : ListView.builder(
              padding: widget.padding,
              physics: widget.physics,
              shrinkWrap: widget.shrinkWrap,
              itemCount: itemCount,
              itemBuilder: (ctx, i) => _buildItem(ctx, i, items, state),
            ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    int index,
    List<T> items,
    PagedState<T> state,
  ) {
    if (index < items.length) {
      return widget.itemBuilder(context, items[index], index);
    }
    // 底部 footer 区域
    if (state.moreError != null) {
      final retry = () => _notifier.loadMore();
      return widget.moreErrorBuilder?.call(state.moreError!, retry) ??
          MoreErrorBar(error: state.moreError!, onRetry: retry);
    }
    if (!state.hasMore) {
      return widget.noMore ?? const SizedBox(height: 20);
    }
    return const SizedBox.shrink();
  }

  VoidCallback _buildFirstRetry() => () {
        final p = widget.provider;
        if (p is ProviderOrFamily) ref.invalidate(p as ProviderOrFamily);
      };
}
