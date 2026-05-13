import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/app_exception.dart';
import 'paged_state.dart';

/// 分页 Notifier 的公共接口。
///
/// [PagedListView] 通过此接口驱动刷新 / 加载更多，无需感知具体 Notifier 类型。
/// 所有使用 [PagedNotifierMixin] / [PagedNotifierMixinNoArg] 的子类自动实现此接口。
abstract class PagedController {
  Future<void> refresh();
  Future<bool> loadMore();
}

/// 分页 Notifier 混入（带 family 参数 [Arg]）。
///
/// 子类只需实现 [fetchPage]，其余分页逻辑（首屏、loadMore、refresh、patch）
/// 由 mixin 统一提供。彻底消除 `static int pageNum` / `static String status` 写法。
///
/// 典型用法（配合 @riverpod 注解）：
/// ```dart
/// @riverpod
/// class OrderList extends _$OrderList
///     with PagedNotifierMixin<OrderItem, OrderFilter> {
///   @override
///   Future<List<OrderItem>> fetchPage(OrderFilter arg, int page, int size) =>
///       ref.read(orderRepositoryProvider).list(arg, page: page, size: size);
/// }
/// ```
///
/// 约束：
///   * [Arg] 必须是不可变值对象，正确实现 `==` / `hashCode`；
///   * family key 变化时，Riverpod 会自动重建并拉取首页。
mixin PagedNotifierMixin<T, Arg>
    on AutoDisposeFamilyAsyncNotifier<PagedState<T>, Arg>
    implements PagedController {
  /// 每页条数。子类可按需 override。
  int get pageSize => 20;

  /// 子类实现：拉取第 [page] 页，返回当页数据列表。
  Future<List<T>> fetchPage(Arg arg, int page, int size);

  @override
  Future<PagedState<T>> build(Arg arg) async {
    final items = await fetchPage(arg, 1, pageSize);
    return PagedState<T>(
      items: items,
      page: 1,
      hasMore: items.length >= pageSize,
    );
  }

  /// 下拉刷新：invalidate 自身，等待重新 build 完成。
  @override
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  @override
  Future<bool> loadMore() async {
    final prev = state.valueOrNull;
    if (prev == null || !prev.hasMore || prev.isLoadingMore) return false;

    state = AsyncData(prev.copyWith(isLoadingMore: true, clearMoreError: true));
    try {
      final next = await fetchPage(arg, prev.page + 1, pageSize);
      state = AsyncData(prev.copyWith(
        items: [...prev.items, ...next],
        page: prev.page + 1,
        hasMore: next.length >= pageSize,
        isLoadingMore: false,
      ));
      return next.isNotEmpty;
    } on AppException catch (e) {
      state = AsyncData(prev.copyWith(isLoadingMore: false, moreError: e));
      return false;
    } catch (e, st) {
      state = AsyncData(prev.copyWith(
        isLoadingMore: false,
        moreError: UnknownException(message: e.toString(), raw: e, stackTrace: st),
      ));
      return false;
    }
  }

  /// 本地乐观更新，不触发网络请求（如取消订单后立刻从列表移除）。
  void patch(List<T> Function(List<T> current) patcher) {
    final prev = state.valueOrNull;
    if (prev == null) return;
    state = AsyncData(prev.copyWith(items: patcher(prev.items)));
  }
}

/// 无参数版本，适合不依赖任何外部过滤的分页列表。
mixin PagedNotifierMixinNoArg<T>
    on AutoDisposeAsyncNotifier<PagedState<T>>
    implements PagedController {
  int get pageSize => 20;

  Future<List<T>> fetchPage(int page, int size);

  @override
  Future<PagedState<T>> build() async {
    final items = await fetchPage(1, pageSize);
    return PagedState<T>(
      items: items,
      page: 1,
      hasMore: items.length >= pageSize,
    );
  }

  @override
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  @override
  Future<bool> loadMore() async {
    final prev = state.valueOrNull;
    if (prev == null || !prev.hasMore || prev.isLoadingMore) return false;

    state = AsyncData(prev.copyWith(isLoadingMore: true, clearMoreError: true));
    try {
      final next = await fetchPage(prev.page + 1, pageSize);
      state = AsyncData(prev.copyWith(
        items: [...prev.items, ...next],
        page: prev.page + 1,
        hasMore: next.length >= pageSize,
        isLoadingMore: false,
      ));
      return next.isNotEmpty;
    } on AppException catch (e) {
      state = AsyncData(prev.copyWith(isLoadingMore: false, moreError: e));
      return false;
    } catch (e, st) {
      state = AsyncData(prev.copyWith(
        isLoadingMore: false,
        moreError: UnknownException(message: e.toString(), raw: e, stackTrace: st),
      ));
      return false;
    }
  }

  void patch(List<T> Function(List<T> current) patcher) {
    final prev = state.valueOrNull;
    if (prev == null) return;
    state = AsyncData(prev.copyWith(items: patcher(prev.items)));
  }
}
