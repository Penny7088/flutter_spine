import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'effect.dart';

/// 带来源信息的 effect 包装。UI 侧可按 [source] 过滤监听。
class EffectEnvelope {
  const EffectEnvelope({required this.source, required this.payload});

  /// 发射该 effect 的 ViewModel 的 `runtimeType`。
  ///
  /// `EffectListener` 通过 `source == MyVm` 这样的判断筛选出本页 VM 的 effect；
  /// 若不传 source，则监听全量。
  final Type source;

  final Effect payload;

  @override
  String toString() => 'EffectEnvelope(source=$source, payload=$payload)';
}

/// 全局 effect 总线。
///
/// 所有 `ViewModelNotifier.emit` 写入同一条 [stream]。
/// UI 侧通过 `EffectListener` 订阅：
///   * App 根级挂一次 → 处理内置 effect（toast/navigate/pop...）；
///   * Page 级再挂一次 → 处理本页 VM 的业务 effect。
///
/// 生命周期由 [effectBusProvider] 管理，[close] 会在 `ProviderContainer.dispose()` 时触发。
class EffectBus {
  EffectBus() : _controller = StreamController<EffectEnvelope>.broadcast();

  final StreamController<EffectEnvelope> _controller;

  /// 所有 effect 的流。broadcast 模式，支持多订阅者。
  Stream<EffectEnvelope> get stream => _controller.stream;

  /// Bus 是否已关闭。
  bool get isClosed => _controller.isClosed;

  /// 发射一个 effect。已关闭的 bus 上调用会静默忽略，不会抛异常——
  /// 这样测试里 teardown 后仍有延迟 emit 不会炸。
  void emit(Type source, Effect effect) {
    if (_controller.isClosed) return;
    _controller.add(EffectEnvelope(source: source, payload: effect));
  }

  /// 关闭 bus。通常由 [effectBusProvider] 的 `onDispose` 触发，业务代码不应直接调用。
  Future<void> close() {
    if (_controller.isClosed) return Future.value();
    return _controller.close();
  }
}

/// 全局 effect bus provider。
///
/// 生命周期跟随 `ProviderContainer`：container 销毁时自动关闭 bus。
/// 测试里 `addTearDown(container.dispose)` 即可正确清理。
final effectBusProvider = Provider<EffectBus>((ref) {
  final bus = EffectBus();
  ref.onDispose(bus.close);
  return bus;
});
