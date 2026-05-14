import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../flutter_spine.dart';

/// 对 [AsyncValue<T>] 的四种状态（loading / error / empty / data）提供统一渲染。
///
/// 和 [AsyncBuilder] 的区别：
///   * [AsyncBuilder] 只区分 loading / error / data 三态；
///   * [AsyncPageStateView] 额外提供空态，通过 [isEmpty] 回调判断。
///
/// 适用场景：单数据页面 + 有空态区分（如订单详情、列表初次加载）。
/// 分页列表场景请用 [PagedListView]。
///
/// 用法：
/// ```dart
/// AsyncPageStateView<List<OrderItem>>(
///   provider: orderListProvider,
///   isEmpty: (list) => list.isEmpty,
///   empty: const OrderEmptyView(),
///   data: (list) => _OrderListBody(list),
/// )
/// ```
class AsyncPageStateView<T> extends ConsumerWidget {
  const AsyncPageStateView({
    super.key,
    required this.provider,
    required this.data,
    required this.isEmpty,
    this.loading,
    this.empty,
    this.error,
    this.skipLoadingOnRefresh = true,
  });

  final ProviderListenable<AsyncValue<T>> provider;

  /// 数据非空时的内容渲染。
  final Widget Function(T data) data;

  /// 判断数据是否为空态（如 `(list) => list.isEmpty`）。
  final bool Function(T data) isEmpty;

  /// 自定义加载中 Widget。null → [LoadingView]。
  final Widget? loading;

  /// 自定义空态 Widget。null → [EmptyView]。
  final Widget? empty;

  /// 自定义错误 Widget（参数：error, retry）。null → [ErrorView]。
  final Widget Function(Object error, VoidCallback retry)? error;

  /// 刷新期间是否跳过 loading 状态继续显示旧数据（默认 true，避免闪屏）。
  final bool skipLoadingOnRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(provider);
    final retry = _buildRetry(ref);

    // 有数据（包括刷新中仍有旧数据的情况）
    if (value.hasValue && (skipLoadingOnRefresh || !value.isLoading)) {
      final d = value.value as T;
      return isEmpty(d) ? (empty ?? const EmptyView()) : data(d);
    }

    // 有错误且非刷新中
    if (value.hasError && !value.isLoading) {
      return error?.call(value.error!, retry) ??
          ErrorView(error: value.error!, onRetry: retry);
    }

    // 首次加载
    return loading ?? const LoadingView();
  }

  VoidCallback _buildRetry(WidgetRef ref) => () {
        final p = provider;
        if (p is ProviderOrFamily) ref.invalidate(p as ProviderOrFamily);
      };
}
