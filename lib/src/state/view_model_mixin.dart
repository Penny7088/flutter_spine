import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../effect/effect.dart';
import '../effect/effect_bus.dart';
import '../error/app_exception.dart';
import '../error/result.dart';

/// 同步 VM 的核心能力（`update` / `emit` / `run`）的可复用 mixin。
///
/// 两种使用方式：
///
/// ### 1) 现成基类（默认；handcrafted provider）
///
/// ```dart
/// class FooVm extends ViewModelNotifier<FooState> {  // 已 with ViewModelMixin
///   @override
///   FooState build() => const FooState();
/// }
/// final fooVmProvider = NotifierProvider.autoDispose<FooVm, FooState>(FooVm.new);
/// ```
///
/// ### 2) 配 `riverpod_generator`
///
/// ```dart
/// @riverpod
/// class FooVm extends _$FooVm with ViewModelMixin<FooState> {
///   @override
///   FooState build() => const FooState();
/// }
/// // build_runner 自动生成 fooVmProvider。
/// ```
///
/// 这两种写法**业务能力等价**——`update` / `emit` / `run` 行为一致。
mixin ViewModelMixin<S> on AutoDisposeNotifier<S> {
  /// 唯一允许改 state 的方法。reducer 返回同实例则 `identical` 短路，不触发 rebuild。
  /// Notifier 已销毁时静默忽略（避免 await 完成后页面已离开导致的崩溃）。
  @protected
  void update(S Function(S prev) reducer) {
    try {
      final next = reducer(state);
      if (identical(next, state)) return;
      state = next;
    } on StateError {
      // disposed
    }
  }

  /// 发射一次性副作用——内部把 effect 写入全局 `effectBusProvider`，带本 VM 的
  /// `runtimeType` 作为 source。UI 侧 `EffectListener(source: MyVm, ...)` 可按 source 过滤。
  @protected
  void emit(Effect effect) {
    try {
      ref.read(effectBusProvider).emit(runtimeType, effect);
    } on StateError {
      // disposed
    }
  }

  /// 统一的异步任务执行器。流程：onStart → action → onSuccess/onFailure → 失败发 EffectShowError。
  /// 返回 [Result] 供调用方做后续分支（成功后额外 emit toast 等）。
  @protected
  Future<Result<T>> run<T>(
    Future<T> Function() action, {
    S Function(S prev)? onStart,
    S Function(S prev, T value)? onSuccess,
    S Function(S prev, AppException error)? onFailure,
    bool emitErrorEffect = true,
  }) async {
    if (onStart != null) update(onStart);
    final result = await action().toResult();
    switch (result) {
      case Ok(:final value):
        if (onSuccess != null) update((s) => onSuccess(s, value));
      case Err(:final error):
        if (onFailure != null) update((s) => onFailure(s, error));
        if (emitErrorEffect) emit(EffectShowError(error));
    }
    return result;
  }
}

/// `ViewModelMixin` 的 family 版。用于 `@riverpod class FooVm extends _$FooVm
/// with FamilyViewModelMixin<FooState, String>`。
mixin FamilyViewModelMixin<S, Arg> on AutoDisposeFamilyNotifier<S, Arg> {
  @protected
  void update(S Function(S prev) reducer) {
    try {
      final next = reducer(state);
      if (identical(next, state)) return;
      state = next;
    } on StateError {
      // disposed
    }
  }

  @protected
  void emit(Effect effect) {
    try {
      ref.read(effectBusProvider).emit(runtimeType, effect);
    } on StateError {
      // disposed
    }
  }

  @protected
  Future<Result<T>> run<T>(
    Future<T> Function() action, {
    S Function(S prev)? onStart,
    S Function(S prev, T value)? onSuccess,
    S Function(S prev, AppException error)? onFailure,
    bool emitErrorEffect = true,
  }) async {
    if (onStart != null) update(onStart);
    final result = await action().toResult();
    switch (result) {
      case Ok(:final value):
        if (onSuccess != null) update((s) => onSuccess(s, value));
      case Err(:final error):
        if (onFailure != null) update((s) => onFailure(s, error));
        if (emitErrorEffect) emit(EffectShowError(error));
    }
    return result;
  }
}
