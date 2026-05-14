import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../flutter_spine.dart';

/// 带页面状态管理的通用 Scaffold。
///
/// 内部复用 [AsyncPageStateView] 状态机，处理四态：
///   * `loading` — 首屏加载（默认 [LoadingView]，推荐传骨架屏）
///   * `error`   — 首屏加载失败（默认 [ErrorView] + 重试）
///   * `empty`   — 数据为空（默认 [EmptyView]）
///   * `data`    — 有数据，body 由外部 [data] 回调完全控制
///
/// `data` 不绑定任何具体实现，可以是 [PagedListView]、普通列表、复杂布局等。
///
/// 用法（整页分页列表）：
/// ```dart
/// PagedScaffold<PagedState<OrderItem>>(
///   appBar: AppBar(title: const Text('Orders')),
///   provider: orderListProvider(filter),
///   isEmpty: (s) => s.isEmpty,
///   firstLoading: const SkeletonList(),
///   empty: const OrderEmptyView(),
///   data: (state) => PagedListView<OrderItem>(
///     provider: orderListProvider(filter),
///     controllerProvider: orderListProvider(filter).notifier,
///     itemBuilder: (ctx, item, _) => OrderItemCard(item),
///   ),
/// )
/// ```
///
/// 用法（body 含筛选栏）：
/// ```dart
/// PagedScaffold<PagedState<Item>>(
///   appBar: AppBar(title: const Text('Items')),
///   provider: itemListProvider(filter),
///   isEmpty: (s) => s.isEmpty,
///   data: (state) => Column(
///     children: [
///       FilterBar(filter: filter),
///       Expanded(
///         child: PagedListView<Item>(...),
///       ),
///     ],
///   ),
/// )
/// ```
class PagedScaffold<T> extends ConsumerWidget {
  const PagedScaffold({
    super.key,
    required this.provider,
    required this.data,
    required this.isEmpty,
    this.appBar,
    this.firstLoading,
    this.firstError,
    this.empty,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.skipLoadingOnRefresh = true,
  });

  /// 监听的 provider，状态切换由此驱动。
  final ProviderListenable<AsyncValue<T>> provider;

  /// 数据非空时的 body，外部完全控制内容与布局。
  final Widget Function(T data) data;

  /// 判断数据是否为空态（如 `(s) => s.isEmpty`）。
  final bool Function(T data) isEmpty;

  // ── 状态 slots ────────────────────────────────────────────────────────────

  /// 首屏 loading。null → [LoadingView]。推荐传 `SkeletonList()`。
  final Widget? firstLoading;

  /// 首屏 error（参数：error, retry）。null → [ErrorView]。
  final Widget Function(Object error, VoidCallback retry)? firstError;

  /// 空态。null → [EmptyView]。
  final Widget? empty;

  // ── Scaffold 配置 ─────────────────────────────────────────────────────────

  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;

  /// 刷新期间是否跳过 loading 继续显示旧数据（默认 true，避免闪屏）。
  final bool skipLoadingOnRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: AsyncPageStateView<T>(
        provider: provider,
        isEmpty: isEmpty,
        loading: firstLoading,
        error: firstError,
        empty: empty,
        skipLoadingOnRefresh: skipLoadingOnRefresh,
        data: data,
      ),
    );
  }
}
