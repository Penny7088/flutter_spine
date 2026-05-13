import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../effect/effect.dart';
import '../effect/effect_bus.dart';
import '../error/result.dart';

/// 异步 VM 的核心能力（`refresh` / `patch` / `emit` / `mutate`）的可复用 mixin。
///
/// 两种使用方式（同 [ViewModelMixin]）：
///
/// ```dart
/// // 1) 现成基类
/// class FooVm extends AsyncViewModelNotifier<Foo> { @override Future<Foo> build() => ...; }
///
/// // 2) 配 riverpod_generator
/// @riverpod
/// class FooVm extends _$FooVm with AsyncViewModelMixin<Foo> {
///   @override Future<Foo> build() => ...;
/// }
/// ```
mixin AsyncViewModelMixin<T> on AutoDisposeAsyncNotifier<T> {
  /// 重新拉数据。默认 `invalidateSelf + await future`。
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// 乐观更新：不请求接口，直接改 state。state 尚无 value 时 no-op。
  @protected
  void patch(T Function(T current) mapper) {
    try {
      final curr = state.valueOrNull;
      if (curr == null) return;
      state = AsyncData(mapper(curr));
    } on StateError {
      // disposed
    }
  }

  /// 发射一次性副作用。见 [ViewModelMixin.emit]。
  @protected
  void emit(Effect effect) {
    try {
      ref.read(effectBusProvider).emit(runtimeType, effect);
    } on StateError {
      // disposed
    }
  }

  /// 变更操作：跑 [action] → 成功 [applyTo] → 失败发 [EffectShowError]。
  @protected
  Future<Result<R>> mutate<R>(
    Future<R> Function() action, {
    T Function(T current, R result)? applyTo,
    bool emitErrorEffect = true,
  }) async {
    final result = await action().toResult();
    switch (result) {
      case Ok(:final value):
        if (applyTo != null) patch((s) => applyTo(s, value));
      case Err(:final error):
        if (emitErrorEffect) emit(EffectShowError(error));
    }
    return result;
  }
}

/// `AsyncViewModelMixin` 的 family 版。
mixin FamilyAsyncViewModelMixin<T, Arg> on AutoDisposeFamilyAsyncNotifier<T, Arg> {
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  @protected
  void patch(T Function(T current) mapper) {
    try {
      final curr = state.valueOrNull;
      if (curr == null) return;
      state = AsyncData(mapper(curr));
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
  Future<Result<R>> mutate<R>(
    Future<R> Function() action, {
    T Function(T current, R result)? applyTo,
    bool emitErrorEffect = true,
  }) async {
    final result = await action().toResult();
    switch (result) {
      case Ok(:final value):
        if (applyTo != null) patch((s) => applyTo(s, value));
      case Err(:final error):
        if (emitErrorEffect) emit(EffectShowError(error));
    }
    return result;
  }
}
