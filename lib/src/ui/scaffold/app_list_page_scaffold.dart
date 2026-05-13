import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../effect/effect.dart';
import '../../pagination/paged_list_view.dart';
import '../../pagination/paged_notifier_mixin.dart';
import '../../pagination/paged_state.dart';
import 'app_page_scaffold.dart';

/// 分页列表页骨架：`AppPageScaffold` + `PagedListView` 的组合。
///
/// 把一个常规"AppBar + 下拉刷新 + 上拉加载更多"的页面压到 O(1) 配置：
/// 传入数据 provider + controller provider + item builder 即可开箱即用。
/// 各种状态（首屏 loading / error、空态、加载更多失败）都有可覆盖的 slot。
///
/// ## 用法
///
/// ```dart
/// class OrderListPage extends ConsumerWidget {
///   @override
///   Widget build(BuildContext ctx, WidgetRef ref) {
///     return AppListPageScaffold<OrderItem>(
///       title: 'Orders',
///       source: OrderListVm,
///       provider: orderListVmProvider,
///       controllerProvider: orderListVmProvider.notifier,
///       itemBuilder: (ctx, item, i) => OrderItemCard(item),
///       firstLoading: const SkeletonList(),
///       empty: const OrderEmptyView(),
///     );
///   }
/// }
/// ```
///
/// 带筛选栏 / header 的复合布局：body 外层自己包一层 Column，用 Expanded 托住列表——
/// 如果想这么做，直接用 `AppPageScaffold` + `PagedListView`，本类只覆盖"整页即列表"的最常见场景。
class AppListPageScaffold<T> extends StatelessWidget {
  const AppListPageScaffold({
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
    this.header,
    this.footer,
    this.easyRefreshController,
    this.title,
    this.titleWidget,
    this.appBar,
    this.actions,
    this.leading,
    this.onBack,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomBar,
    this.backgroundColor,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.dismissKeyboardOnTap = true,
    this.source,
    this.onEffect,
    this.handleDefaultEffects = true,
  });

  // ── List 数据 ─────────────────────────────────────────────────────────
  final ProviderListenable<AsyncValue<PagedState<T>>> provider;
  final ProviderListenable<PagedController> controllerProvider;

  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context, int index)? separatorBuilder;

  // ── List 状态 slots ───────────────────────────────────────────────────
  final Widget? firstLoading;
  final Widget Function(Object error, VoidCallback retry)? firstError;
  final Widget? empty;
  final Widget Function(Object error, VoidCallback retry)? moreErrorBuilder;
  final Widget? noMore;

  // ── List 布局 ─────────────────────────────────────────────────────────
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Header? header;
  final Footer? footer;
  final EasyRefreshController? easyRefreshController;

  // ── Page 级配置（转发给 AppPageScaffold） ─────────────────────────────
  final String? title;
  final Widget? titleWidget;
  final PreferredSizeWidget? appBar;
  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onBack;

  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Widget? bottomBar;

  final Color? backgroundColor;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool dismissKeyboardOnTap;

  final Type? source;
  final void Function(BuildContext ctx, Effect effect)? onEffect;
  final bool handleDefaultEffects;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: title,
      titleWidget: titleWidget,
      appBar: appBar,
      actions: actions,
      leading: leading,
      onBack: onBack,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomNavigationBar,
      bottomBar: bottomBar,
      backgroundColor: backgroundColor,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      dismissKeyboardOnTap: dismissKeyboardOnTap,
      // 列表页的 body 不需要 SafeArea 包一整层——
      // EasyRefresh 底部指示器和 ListView padding 都由调用方配；
      // 同时避免 padding 导致刷新指示器顶着状态栏。
      safeArea: false,
      source: source,
      onEffect: onEffect,
      handleDefaultEffects: handleDefaultEffects,
      body: PagedListView<T>(
        provider: provider,
        controllerProvider: controllerProvider,
        itemBuilder: itemBuilder,
        separatorBuilder: separatorBuilder,
        firstLoading: firstLoading,
        firstError: firstError,
        empty: empty,
        moreErrorBuilder: moreErrorBuilder,
        noMore: noMore,
        padding: padding,
        physics: physics,
        header: header,
        footer: footer,
        easyRefreshController: easyRefreshController,
      ),
    );
  }
}
