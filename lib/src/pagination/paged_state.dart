import 'package:flutter/foundation.dart';

/// 分页列表的不可变状态快照。
///
/// 设计决策：
///   * 不含 `isLoading`——首次加载的 loading 由外层 `AsyncValue.isLoading` 表达；
///   * `isLoadingMore` 仅描述"已有数据、正在拉下一页"这个特殊状态；
///   * `moreError` 与 `AsyncValue.error` 正交：首屏失败走后者，加载更多失败走前者。
@immutable
class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.moreError,
  });

  final List<T> items;

  /// 当前已加载到的页码（从 1 开始）。
  final int page;

  /// 是否还有下一页。由 `items.length >= pageSize` 推断。
  final bool hasMore;

  /// 正在加载更多（非首次加载）。
  final bool isLoadingMore;

  /// 加载更多失败时保存的错误；不影响已有数据展示。
  final Object? moreError;

  bool get isEmpty => items.isEmpty;

  PagedState<T> copyWith({
    List<T>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    Object? moreError,
    bool clearMoreError = false,
  }) {
    return PagedState<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      moreError: clearMoreError ? null : (moreError ?? this.moreError),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PagedState<T> &&
        listEquals(items, other.items) &&
        page == other.page &&
        hasMore == other.hasMore &&
        isLoadingMore == other.isLoadingMore &&
        moreError == other.moreError;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(items), page, hasMore, isLoadingMore, moreError);
}
