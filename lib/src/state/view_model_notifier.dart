import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'view_model_mixin.dart';

/// MVVM ViewModel 基类（sync build）。
///
/// **现在是 [ViewModelMixin] 的薄封装**——所有能力 (`update` / `emit` / `run`)
/// 来自 mixin，本类只负责把 mixin 装到 `AutoDisposeNotifier<S>` 上，对外
/// 提供"一行 extends 即开即用"的便利。
///
/// API 100% 兼容旧版本，无需任何业务侧改动。
///
/// ## 约束
///
/// 1. **唯一的 state 修改入口是 [ViewModelMixin.update]**——不要直接 `state = ...`（custom lint 守护）；
/// 2. **副作用走 [ViewModelMixin.emit]**——不要在 VM 里引用 `BuildContext` / `Navigator` / `ScaffoldMessenger`；
/// 3. **异步任务用 [ViewModelMixin.run]**——自动处理 loading/ok/error 三态 + 失败 toast；
/// 4. **`build()` 返回同步初始 state**——首次异步加载请在 `build()` 里 `Future.microtask(load)`。
///
/// ## 典型写法
///
/// ```dart
/// final orderListVmProvider =
///     NotifierProvider.autoDispose<OrderListVm, OrderListState>(OrderListVm.new);
///
/// class OrderListVm extends ViewModelNotifier<OrderListState> {
///   @override
///   OrderListState build() {
///     Future.microtask(load);
///     return const OrderListState();
///   }
///
///   Future<void> load() => run(
///         () => ref.read(orderRepositoryProvider).list(),
///         onStart:   (s) => s.copyWith(status: ViewStatus.loading, error: null),
///         onSuccess: (s, items) => s.copyWith(status: ViewStatus.ok, items: items),
///         onFailure: (s, e) => s.copyWith(status: ViewStatus.error, error: e),
///       );
/// }
/// ```
///
/// ## 想用 `riverpod_generator`？
///
/// 不用本基类，直接 `extends _$Foo with ViewModelMixin<S>`：
///
/// ```dart
/// @riverpod
/// class OrderListVm extends _$OrderListVm with ViewModelMixin<OrderListState> {
///   @override OrderListState build() => const OrderListState();
/// }
/// ```
abstract class ViewModelNotifier<S> extends AutoDisposeNotifier<S>
    with ViewModelMixin<S> {}

/// [ViewModelNotifier] 的 family 版——需要运行时参数的 VM 用这个。
///
/// ```dart
/// final orderDetailVmProvider = NotifierProvider.autoDispose
///     .family<OrderDetailVm, OrderDetailState, String>(OrderDetailVm.new);
///
/// class OrderDetailVm extends FamilyViewModelNotifier<OrderDetailState, String> {
///   @override
///   OrderDetailState build(String id) {
///     Future.microtask(() => load(id));
///     return const OrderDetailState();
///   }
/// }
/// ```
abstract class FamilyViewModelNotifier<S, Arg>
    extends AutoDisposeFamilyNotifier<S, Arg>
    with FamilyViewModelMixin<S, Arg> {}
