# `flutter_spine` · Agent 总纲

## 1. 我是谁

- `flutter_spine` 是**业务无关**、**UI 框架解耦**的 Flutter 地基包：MVVM + Riverpod + Effect Bus + 网络（HTTP/WS）+ 本地 KV 存储 + 自定义 Lint。
- 目标用户是**别的业务包**（`flutter_wallet`、`flutter_promotion` 等）。
- 一切公开 API 必须能在不引入业务概念的前提下使用，因此 PR 评审会以"业务团队 5 分钟读懂"为基准。
- 完整里程碑见 [`ARCHITECTURE.md`](../ARCHITECTURE.md)（P1-P8）和 [`README.md`](README.md)。

## 2. 不可破红线（违反 = 直接拒绝合入）

| 红线 | 为什么 | 怎么做 |
|---|---|---|
| ❌ 业务代码 `import 'package:flutter_spine/src/...'` | 破坏封装 | 只 import `package:flutter_core/flutter_core.dart` |
| ❌ ViewModel 持有 `BuildContext` / `Navigator` / `ScaffoldMessenger` / `showDialog` | 无法 headless 测试 | `emit(EffectXxx(...))`，UI 走 `EffectListener` |
| ❌ 业务页面 `extends Scaffold` 或裸 `Scaffold(...)` | 漏接 EffectListener / SafeArea | 选 `AppPageScaffold` / `AppFormPageScaffold` / `AppBottomSheetScaffold` / `AppRawPage` |
| ❌ 业务代码 `import 'package:dio/...'` 或 `Dio()` | 没法 mock，没法换实现 | 注入 `httpClientProvider`，配置走 `DioHttpConfig` |
| ❌ 业务代码 `import 'package:web_socket_channel/...'` 或 `WebSocketChannel.connect(...)` | 同上 | 用 `wsClientProvider`，订阅走 `subscribe<T>(topic)` |
| ❌ 业务代码 `Hive.box(...)` / `Hive.openBox(...)` | 同上 | 注入 `keyValueStorageProvider` |
| ❌ 业务代码 `MethodChannel(...)` 直接 new | 同上 | 抽 channel client + provider |
| ❌ 在 Notifier 里写 `static var x = ...` | autoDispose 失效，跨实例污染 | 用 family / scoped Provider |
| ❌ Notifier 里 `state = newState` 直接赋值 | 失去 reducer 语义 + lint 拦不到的小 bug | 走 `update((prev) => ...)` |
| ❌ 改自动生成文件（`*.g.dart` / `*.freezed.dart`） | 下次 build_runner 全冲掉 | 改源 → `dart run build_runner build --delete-conflicting-outputs` |
| ❌ 引入新依赖前不沟通 | 包"轻"是核心卖点 | 先发结构 + 必要性给人审核 |

`flutter_core_lint` 已经把上面 7 条网络/UI/storage/notifier 红线**编译期拦截**。运行 `dart run custom_lint` 必须 0 error。

## 3. ViewModel 5 行口诀

```dart
class FooVm extends ViewModelNotifier<FooState> {     // 或 with ViewModelMixin（generator 风格）
  @override FooState build() => const FooState();    // 同步初始 state；首次异步用 Future.microtask(load)
  Future<void> load() => run(                         // 异步任务唯一入口
        () => ref.read(repoProvider).fetch(),
        onStart:   (s) => s.copyWith(status: ViewStatus.loading),
        onSuccess: (s, v) => s.copyWith(status: ViewStatus.ok, data: v),
        onFailure: (s, e) => s.copyWith(status: ViewStatus.error, error: e),
      );                                              // 失败自动 emit(EffectShowError(e))
}
```

异步 VM 用 `AsyncViewModelNotifier<T>`（或 `with AsyncViewModelMixin<T>`），异步入口是 `mutate(action, applyTo: ...)`。

## 4. 决策流程图

### 4.1 用户说"加一个新页面"

1. 看 `flutter-core-new-feature` skill。
2. 优先 CLI：`dart run flutter_core:new <page|async-page|form|feature> <name> [--with-test] [--with-repo] [--gen]`。**不要**手抄模板——CLI 是单一来源。
3. 路由约定走业务包 `lib/app/router.dart`，flutter_core 不管。

### 4.2 用户说"加 HTTP 接口" / "调后端"

1. 看 `flutter-core-http-setup` skill。
2. Repository 层用 `httpClient.get/post/...<T>(path, decoder: ...)`，绝不直接 import dio。
3. 接 `safeApiCall` 把异常归一到 `AppException` 子类。
4. 需要重试 / 401 刷新，用 `DioHttpClient.fromDio` 自行组装 `RetryInterceptor` / `AuthRefreshInterceptor`（见 http-setup skill）；文件上传走 `httpClient.upload`。

### 4.3 用户说"加 WebSocket" / "实时推送"

1. 看 `flutter-core-ws-setup` skill。
2. **永远**用 `subscribe<T>('topic', decoder: ...)`，不要直接 `messages.listen` —— 后者拿不到 topic 路由 / 重连重订阅。
3. 业务进页面 `subscribe`、出页面 `unsubscribe`，连接/重连/心跳/重订阅都自动。

### 4.4 用户说"写个测试"

1. 看 `flutter-core-test-vm` skill。
2. `final h = createVmTestHarness();` 起手；断言用 `h.effects.lastPayload` 配 `isToast()` / `isNavigate()` 等 matcher。
3. **不要** `WidgetTester.pumpWidget(MaterialApp(...))` 来测 VM——那是 widget 测试的事。

### 4.5 用户说"加一条 lint" / "禁止某种写法"

1. 看 `flutter-core-add-lint` skill。
2. 在 `package/flutter_core_lint/lib/src/lints/` 加文件，注册到 `lib/flutter_core_lint.dart` 的 `getLintRules`。
3. 必须考虑豁免（flutter_core 自身、`/test/`、`/example/`、`bootstrap.dart`、`main.dart`）。

### 4.6 用户说 "lint 报错了 / dart run custom_lint 红了"

→ `flutter-core-fix-lint-fail` skill。

## 5. 测试纪律

| 改动类型 | 必须跑 |
|---|---|
| `lib/src/state/**` 或任何 mixin/Notifier 基类 | `flutter test test/state/` + `flutter test test/pagination/` |
| `lib/src/network/http/**` | `flutter test test/network/http/` |
| `lib/src/network/ws/**` | `flutter test test/network/ws/` |
| `lib/src/effect/**` | `flutter test test/effect/` |
| `lib/src/cli/**` 或 `bin/new.dart` | 手动 `dart run flutter_core:new <subcmd> <tmp_name> --dry-run` smoke |


最终 PR 前必须：`cd package/flutter_spine && flutter analyze && flutter test`。

## 6. 命名 / 文件位置

- VM 文件：`<feature>_vm.dart`，类名 `<Feature>Vm`，provider 名 `<feature>VmProvider`。
- State 文件：和 VM 同文件 OR 同目录 `<feature>_state.dart`，必须 `@immutable` + `copyWith`。
- Effect：`<feature>_effects.dart`，`sealed class XxxEffect extends Effect`。
- 公开 API 一律加 dartdoc（`///`），中文 OK；私有可以省。

## 7. 禁用清单（不要再做）

- 不要再写 `extends ConsumerStatefulWidget` 然后在 `initState` 里 `ref.read().load()`——VM 的 `build()` 里 `Future.microtask(load)` 即可。
- 不要把 effect 塞进 state 字段（"toast 后 setState 清空"那种 hack）—— 状态会被时间旅行 / 错位重放。
- 不要在 ViewModel 里 `try/catch` 后吞错——`run()` 已经把失败统一上报，业务 try-catch 等于把信号丢了。
- 不要给 `ViewModelNotifier` 加新基类层级——能力扩展走 mixin 组合，不要继承链。
- 不要在 `flutter_spine` 包内引入业务模型（`Order` / `User` / `Wallet`）—— 它就是地基，地基里不能有业务。
