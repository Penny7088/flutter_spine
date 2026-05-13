---
name: flutter-core-test-vm
description: Write VM tests using flutter_core_test's VmTestHarness, EffectRecorder, StateRecorder, and effect matchers (isToast/isNavigate/isPop/isErrorEffect/isHaptic/isDialog). Use when the user asks to write or fix a ViewModel/Notifier test.
---

# 写 VM 测试

VM 测试**不**用 `WidgetTester`、**不**用 `MaterialApp`、**不**用 `pumpWidget`。`flutter_core_test` 已经把样板沉到 `createVmTestHarness()`。

## 起手 5 行

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_core_test/flutter_core_test.dart';
import 'package:my_app/features/order/order_vm.dart';

void main() {
  test('pay flow', () async {
    final h = createVmTestHarness(
      overrides: [
        orderRepoProvider.overrideWithValue(_FakeRepo()),
      ],
    );
    final history = h.recordStates(orderVmProvider);

    await h.read(orderVmProvider.notifier).pay();
    await h.pump();                          // 关键：等 broadcast tick

    expect(history.values.last.status, OrderStatus.paid);
    expect(h.effects.lastPayload, isToast(message: '已支付'));
  });
}
```

## VmTestHarness API

| 调用 | 作用 |
|---|---|
| `createVmTestHarness(overrides: [...])` | 起 container，自动注入 `NoopDefaultEffectHandler` + `EffectRecorder`，`addTearDown` 自动 dispose |
| `h.read(provider)` | container.read 的便捷转发 |
| `h.read(provider.notifier).method()` | 调 VM 方法 |
| `h.read(provider.future)` | 强制 await 异步 VM 的首格 |
| `h.keepAlive(provider)` | 防 autoDispose 在 await 间隙释放 state |
| `h.recordStates(provider)` | 返回 `StateRecorder<S>`，`values` / `last` / `distinct` 看历史；自动 keepAlive |
| `h.effects` | `EffectRecorder`，看 VM 发了什么副作用 |
| `h.pump()` | `Future.delayed(Duration.zero)`，让 broadcast 流交付 |
| `h.container` | 底层 ProviderContainer，`refresh` / `invalidate` 直接走它 |

## EffectRecorder 断言

```dart
h.effects.payloads          // List<Effect>
h.effects.lastPayload       // 最近一次
h.effects.has(matcher)      // bool
h.effects.where(matcher)    // 过滤
```

## Effect matchers

| Matcher | 用途 |
|---|---|
| `isToast()` / `isToast(message: 'x', level: ToastLevel.success)` | toast |
| `isNavigate()` / `isNavigate(path: '/x')` | 导航 |
| `isPop()` / `isPop(result: 42)` | 关页 |
| `isErrorEffect()` / `isErrorEffect(of: NetworkException)` | run() 失败发的 EffectShowError |
| `isDialog()` / `isDialog(id: 'confirm')` | 弹窗 |
| `isHaptic()` / `isHaptic(kind: HapticKind.light)` | 震动 |
| `isInstanceOf<MyEffect>()` | 业务自定义 effect |

## 异步 VM 测试 pattern

```dart
test('orders load and cancel', () async {
  final h = createVmTestHarness(overrides: [...]);
  // 先等 build 完成（loading → data）
  await h.read(ordersVmProvider.future);

  await h.read(ordersVmProvider.notifier).cancel('o1');
  await h.pump();

  final state = h.read(ordersVmProvider);
  expect(state.value!.length, 2);
});
```

## Repo / Service mock 用 mocktail

```dart
class _MockHttp extends Mock implements HttpClient {}

setUpAll(() {
  registerFallbackValue<HttpDecoder<dynamic>>((_) => null);
});

final http = _MockHttp();
when(() => http.get<List<Order>>(any(), decoder: any(named: 'decoder')))
    .thenAnswer((_) async => [const Order(id: '1')]);
```

绝对**不要** mock `Dio`。

## fake_async（带定时器/退避的测试）

测试涉及重连退避、心跳、retry 间隔时用 `fake_async`：

```dart
import 'package:fake_async/fake_async.dart';

test('reconnect backoff', () {
  fakeAsync((async) {
    final ws = ...; ws.connect();
    async.elapse(const Duration(seconds: 5));
    expect(ws.currentState, isA<WsReconnecting>());
  });
});
```

## 必查清单

- [ ] 用了 `createVmTestHarness()`，不是手 new `ProviderContainer`。
- [ ] 改 state 后 `await h.pump()`，再断言 effect。
- [ ] `recordStates` 拿到的 `StateRecorder` 包含初始值（`values.first` 就是 build() 返回的）。
- [ ] async VM 先 `await h.read(p.future)` 再调业务方法，否则方法可能在 build 之前跑。
- [ ] `expect(h.effects.lastPayload, isToast(message: '...'))` 用 matcher，不要 `isA<EffectShowToast>()` 然后手摸字段。
- [ ] 没 import `flutter/material.dart`、没 `pumpWidget`、没 `MaterialApp`。

## 不要做的事

- ❌ 不要 `final container = ProviderContainer(); ... container.dispose();` —— 用 harness。
- ❌ 不要在 setup 里 `effectBus.events.listen(events.add)` —— harness 已经有 `EffectRecorder`。
- ❌ 不要在 `expect` 里 await —— matcher 是同步的；在 `await h.pump()` 之后断言。
- ❌ 不要假设 `h.read(p)` 之后 build 已跑完异步副作用 —— 异步 build 用 `await h.read(p.future)`；同步 VM 里 `Future.microtask(load)` 也得 `await h.pump()`。

## 验证

```bash
cd <package_dir>
flutter test test/<feature>/
```

需要 coverage：`flutter test --coverage`，看 `coverage/lcov.info`。
