---
name: flutter-core-vm-author
description: Author or refactor a ViewModel using flutter_core's ViewModelNotifier / AsyncViewModelNotifier base classes (or ViewModelMixin / AsyncViewModelMixin for riverpod_generator). Use when the user asks to write/modify a VM, change state shape, add an action method, or convert between handcrafted/generator styles.
---

# 写一个 ViewModel

## 决策表

| VM 类型 | 基类 / mixin |
|---|---|
| 同步初始 state（推荐起步） | `ViewModelNotifier<S>` 或 `with ViewModelMixin<S>` |
| 异步加载（首屏 loading）+ 业务变更 | `AsyncViewModelNotifier<T>` 或 `with AsyncViewModelMixin<T>` |
| 带 build 参数（family） | `FamilyViewModelNotifier<S, Arg>` 或 `with FamilyViewModelMixin<S, Arg>` |
| 带 build 参数（family）+ 异步 | `AsyncFamilyViewModelNotifier<T, Arg>` 或 `with FamilyAsyncViewModelMixin<T, Arg>` |
| 分页列表 | 业务自建状态类 + `AutoDisposeAsyncNotifier`，手写 `refresh` / `loadMore`（无内置分页类型，见 README §4 Pattern C） |

## 同步 VM 模板

```dart
@immutable
class CounterState {
  const CounterState({this.value = 0, this.status = ViewStatus.idle, this.error});
  final int value;
  final ViewStatus status;
  final AppException? error;
  CounterState copyWith({int? value, ViewStatus? status, AppException? error}) =>
      CounterState(
        value: value ?? this.value,
        status: status ?? this.status,
        error: error ?? this.error,
      );
}

class CounterVm extends ViewModelNotifier<CounterState> {
  @override
  CounterState build() => const CounterState();

  void increment() => update((s) => s.copyWith(value: s.value + 1));

  Future<void> persist() => run(
        () => ref.read(counterRepoProvider).save(state.value),
        onStart:   (s) => s.copyWith(status: ViewStatus.loading, error: null),
        onSuccess: (s, _) => s.copyWith(status: ViewStatus.ok),
        onFailure: (s, e) => s.copyWith(status: ViewStatus.error, error: e),
      );
}

final counterVmProvider =
    NotifierProvider.autoDispose<CounterVm, CounterState>(CounterVm.new);
```

## 异步 VM 模板

```dart
class OrdersVm extends AsyncViewModelNotifier<List<Order>> {
  @override
  Future<List<Order>> build() => ref.read(orderRepoProvider).list();

  Future<void> cancel(String id) => mutate(
        () => ref.read(orderRepoProvider).cancel(id),
        applyTo: (curr, _) => curr.where((o) => o.id != id).toList(),
      );
}

final ordersVmProvider =
    AsyncNotifierProvider.autoDispose<OrdersVm, List<Order>>(OrdersVm.new);
```

UI 用：

```dart
final state = ref.watch(ordersVmProvider);
state.when(
  data: (orders) => ListView(...),
  loading: () => const SkeletonView(),
  error: (e, st) => ErrorView(error: e),
);
```

## generator 风格（业务工程已用 build_runner）

```dart
@riverpod
class CounterVm extends _$CounterVm with ViewModelMixin<CounterState> {
  @override
  CounterState build() => const CounterState();

  void increment() => update((s) => s.copyWith(value: s.value + 1));
}
```

build_runner 自动生成 `counterVmProvider`。

异步 + family 同理：

```dart
@riverpod
class OrderDetailVm extends _$OrderDetailVm with FamilyAsyncViewModelMixin<Order, String> {
  @override
  Future<Order> build(String id) => ref.read(orderRepoProvider).get(id);
}
```

## 起手 5 步

1. 想清楚 state 形状（用 `class FooState` + `copyWith`，**不**要直接拿 `dynamic Map`）。
2. 决定 sync vs async：**首屏要等接口的用 async；本地交互/可乐观显示的用 sync**。
3. 决定 family or not：state 跟运行时参数（订单 id、tab 类型）相关 → family。
4. 决定手写 vs generator：**看业务工程已有的风格**，不要混用。
5. 写 `build()` + 业务方法（`run` / `mutate` 包接口调用）+ provider 声明。

## 必查清单

- [ ] state 是 `@immutable` + `copyWith`，没有 `dynamic`。
- [ ] 没有 `BuildContext` / `Navigator` / `ScaffoldMessenger` / `showDialog`。
- [ ] 没有直接 `state = ...`；只有 `update((s) => ...)`。
- [ ] 异步入口都包了 `run()` / `mutate()`，没有自己 `try/catch` 后 setState 的散弹枪。
- [ ] `build()` **同步**返回（同步 VM）或 `Future<T>`（异步 VM），首次加载用 `Future.microtask(load)`。
- [ ] 没有 `static var` / `static late`（lint 会拦）。
- [ ] 出页面要清的资源（订阅、定时器）放在 `ref.onDispose(...)`。

## 不要做的事

- ❌ 不要 `extends StateNotifier` —— 这是旧 Riverpod 1.x API，本仓不再用。
- ❌ 不要 `class FooVm extends Notifier<S>` 但**不**继承 `ViewModelNotifier` —— 会丢 `update/emit/run` 三件套。
- ❌ 不要 `state = state.copyWith(...)` —— `update` 才能 identical 短路 + disposed 静默。
- ❌ 不要在 `build()` 里 `await load()` —— `build()` 是同步合约（async VM 也是 `Future<T>` 一次性返回 future，不是任意 await）。
- ❌ 不要把"loading"当 effect 发 —— loading 是 state，不是 effect。toast / 弹窗 / 跳转才是 effect。

## 验证

写完跑 `flutter analyze` + 关联测试（`flutter-core-test-vm` skill 配套）。

修了 `lib/src/state/` 任何文件 → `flutter test test/state/` 必跑。
