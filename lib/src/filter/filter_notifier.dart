import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 过滤条件 Notifier 基类。
///
/// 搭配 [PagedNotifierMixin] 使用时，filter provider 的值作为列表 family 参数。
/// filter 变化时 Riverpod 自动按新 key 重建列表（或复用缓存），无需手动 invalidate。
///
/// 用法：
/// ```dart
/// class OrderFilterCtrl extends FilterNotifier<OrderFilter> {
///   @override
///   OrderFilter initial() => const OrderFilter();
/// }
///
/// final orderFilterProvider =
///     NotifierProvider.autoDispose<OrderFilterCtrl, OrderFilter>(
///       OrderFilterCtrl.new,
///     );
///
/// // 页面里：
/// final filter = ref.watch(orderFilterProvider);
/// final list   = ref.watch(orderListProvider(filter));
///
/// // 改筛选（自动触发列表刷新）：
/// ref.read(orderFilterProvider.notifier).update((f) => f.copyWith(status: '4'));
/// ```
///
/// 约束：[F] 必须是不可变值对象，正确实现 `==` / `hashCode`；建议提供 `copyWith`。
abstract class FilterNotifier<F> extends AutoDisposeNotifier<F> {
  /// 子类提供初始过滤值。
  F initial();

  @override
  F build() => initial();

  /// 整体替换为新值。
  void set(F value) => state = value;

  /// 基于当前值局部更新。
  void update(F Function(F current) mapper) => state = mapper(state);

  /// 恢复为初始值。
  void reset() => state = initial();
}
