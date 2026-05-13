import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'async_view_model_mixin.dart';

/// MVVM ViewModel 基类（async build）——用于"读一份数据 + 偶尔 mutate"的页面。
///
/// **现在是 [AsyncViewModelMixin] 的薄封装**——所有能力 (`refresh` / `patch` /
/// `emit` / `mutate`) 来自 mixin，本类只负责把 mixin 装到
/// `AutoDisposeAsyncNotifier<T>` 上，对外提供"一行 extends 即开即用"的便利。
///
/// API 100% 兼容旧版本，无需任何业务侧改动。
///
/// 适用：详情页、设置页、用户信息等。状态直接是 `AsyncValue<T>`，loading / error
/// 由 Riverpod 自动管理。分页列表请用 `PagedNotifierMixin`；需要自定义 status 字段的
/// 复杂页面请用 `ViewModelNotifier`。
///
/// ## 典型写法
///
/// ```dart
/// final userProfileVmProvider =
///     AsyncNotifierProvider.autoDispose<UserProfileVm, UserProfile>(UserProfileVm.new);
///
/// class UserProfileVm extends AsyncViewModelNotifier<UserProfile> {
///   @override
///   Future<UserProfile> build() => ref.read(userRepoProvider).currentUser();
///
///   Future<void> updateNickname(String name) async {
///     await mutate(
///       () => ref.read(userRepoProvider).updateNickname(name),
///       applyTo: (curr, _) => curr.copyWith(nickname: name),
///     );
///     emit(const EffectShowToast('修改成功'));
///   }
/// }
/// ```
///
/// ## 想用 `riverpod_generator`？
///
/// 不用本基类，直接 `extends _$Foo with AsyncViewModelMixin<T>`：
///
/// ```dart
/// @riverpod
/// class UserProfileVm extends _$UserProfileVm
///     with AsyncViewModelMixin<UserProfile> {
///   @override Future<UserProfile> build() =>
///       ref.read(userRepoProvider).currentUser();
/// }
/// ```
abstract class AsyncViewModelNotifier<T> extends AutoDisposeAsyncNotifier<T>
    with AsyncViewModelMixin<T> {}

/// [AsyncViewModelNotifier] 的 family 版。
///
/// ```dart
/// final orderDetailVmProvider = AsyncNotifierProvider.autoDispose
///     .family<OrderDetailVm, OrderDetail, String>(OrderDetailVm.new);
///
/// class OrderDetailVm extends FamilyAsyncViewModelNotifier<OrderDetail, String> {
///   @override
///   Future<OrderDetail> build(String id) =>
///       ref.read(orderRepoProvider).detail(id);
/// }
/// ```
abstract class FamilyAsyncViewModelNotifier<T, Arg>
    extends AutoDisposeFamilyAsyncNotifier<T, Arg>
    with FamilyAsyncViewModelMixin<T, Arg> {}
