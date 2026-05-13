# flutter_spine — 架构概览

> 通用、业务无关、可在任何 Flutter 项目里直接用的"地基包"。
>
> 配套包：`flutter_core_lint`（静态约束）、`flutter_core_test`（测试 helper）。

---

## 1. 设计目标

| 目标 | 我们做了什么 | 为什么 |
|---|---|---|
| **MVVM 纪律** | `ViewModelNotifier` / `AsyncViewModelNotifier` 基类把 state/effect/异步收编 | 防止业务在 VM 里写 BuildContext / 散弹枪式 setState |
| **副作用解耦** | 全局 `EffectBus` + `Effect` sealed 子类 + `EffectListener` | VM 不再依赖具体 UI（toast/router/dialog），可纯 Dart 测试 |
| **错误可治理** | `AppException` sealed + `Result<T>` + `safeApiCall` | 业务调用方一律面对 `AppException`，编译期穷尽 |
| **页面骨架统一** | `AppXxxScaffold` 系列代替裸 `Scaffold` | 自动接 EffectListener / SafeArea / 键盘避让 |
| **架构可强制** | `flutter_core_lint` 5 条规则 | 越界写法编译期就报警，不靠 code review |
| **测试零样板** | `flutter_core_test` harness | VM 测试 5 行起，断言直接读 effect / state 历史 |

---

## 2. 模块分层

```
┌──────────────────────────────────────────────────────────────┐
│                          UI / Page                            │
│  AppPageScaffold · AppListPageScaffold · AppFormPageScaffold  │
│  AppBottomSheetScaffold · AppTabChildScaffold · AppRawPage    │
│  AppDefaultAppBar                                             │
└────────────┬───────────────────────────────────┬─────────────┘
             │ watch / read                     │ EffectListener
             ▼                                  ▼
┌──────────────────────────────────────────────────────────────┐
│                       ViewModel (Riverpod)                    │
│  ViewModelNotifier · AsyncViewModelNotifier · PagedNotifier   │
│  ── 唯一改 state 入口：update(reducer)                         │
│  ── 唯一发副作用：emit(Effect)                                 │
│  ── 异步任务：run(action, onStart/onSuccess/onFailure)         │
└────────────┬───────────────────────────────────┬─────────────┘
             │ ref.read(repo).xxx()              │ emit
             ▼                                  ▼
┌──────────────────────────────┐  ┌──────────────────────────┐
│         Repository            │  │       EffectBus           │
│  safeApiCall(...)             │  │  StreamController.broadcast│
│  → Future<T> | AppException   │  │  envelope: (source, Effect)│
└─────────┬────────────────────┘  └──────────┬───────────────┘
          │                                   │ listen
          ▼                                   ▼
┌──────────────────────────────┐  ┌──────────────────────────┐
│   DataSource (REST/WS/Hive)   │  │   DefaultEffectHandler    │
│   HttpClient · WsClient       │  │  (SnackBar / Router /     │
│   KeyValueStorage · Channel   │  │   Dialog / Haptic 注册)   │
│   Client（每种接口一个抽象）  │  │                           │
└──────────────────────────────┘  └──────────────────────────┘
```

业务团队**只需**实现：

1. 数据层 Repository（用 `safeApiCall` 包好）
2. ViewModel（继承 `ViewModelNotifier` 等）
3. UI 页面（用 `AppXxxScaffold`）
4. 一份 `DefaultEffectHandler`（整个 app 一份，bootstrap 时注入）

> ⚡ 上面这 4 类样板代码现在都可以用 `dart run flutter_spine:new <command>` 一键生成。
> 见 README 的"脚手架 CLI"章节，或直接 `dart run flutter_spine:new --help`。

---

## 3. 八个里程碑（P1-P8）

### P1 · Effect 系统

> "VM 怎么让 UI 弹个 toast，又不依赖 UI？"

```dart
// effect.dart —— sealed
sealed class Effect {}
class EffectShowToast(message, level) extends Effect;
class EffectShowError(error) extends Effect;
class EffectNavigate(path, args) extends Effect;
class EffectPop(result) extends Effect;
class EffectShowDialog(dialogId, args) extends Effect;
class EffectHaptic(kind) extends Effect;

// effect_bus.dart —— 全局 broadcast 流
final effectBusProvider = Provider<EffectBus>((_) => EffectBus());

// effect_listener.dart —— Page 用它消费
EffectListener(
  source: MyVm,           // 只接 MyVm 发的（可省）
  onEffect: (ctx, e) {},  // 业务自定义 effect 在这里接
  child: ...,             // 默认 effect 走 DefaultEffectHandler
)
```

**关键约束**：VM 里只有 `emit(EffectXxx(...))`，**没有** `BuildContext`。

### P2 · ViewModel 基类

> "MVVM 怎么不被自由意志写跑偏？"

```dart
abstract class ViewModelNotifier<S> extends AutoDisposeNotifier<S> {
  void update(S Function(S) reducer);          // 唯一改 state
  void emit(Effect effect);                    // 唯一发副作用
  Future<Result<T>> run<T>(action, {onStart, onSuccess, onFailure});
}

abstract class AsyncViewModelNotifier<T> extends AutoDisposeAsyncNotifier<T> {
  Future<void> refresh();
  void patch(T Function(T) update);            // 乐观更新
  void emit(Effect effect);
  Future<Result<R>> mutate<R>(action, {applyTo});
}
```

辅助：`Result<T> = Ok<T> | Err<T>`、`AppException` sealed、`ViewStatus` 枚举 + `HasViewStatus` mixin（可选 UI 状态约定）。

### P3 · 页面骨架系列

> "每个页面都重写 Scaffold + AppBar + EffectListener？"

| Scaffold | 适用 | 自动给你 |
|---|---|---|
| `AppPageScaffold` | 普通页面 | AppBar / EffectListener / 键盘隐藏 / SafeArea |
| `AppListPageScaffold` | 列表页（含分页） | 上 + `PagedListView` 三态槽位 |
| `AppFormPageScaffold` | 表单页 | 上 + 底部固定按钮 + 自动避让键盘 |
| `AppBottomSheetScaffold` | 半屏 sheet 内容 | drag handle + title bar + EffectListener |
| `AppTabChildScaffold` | TabBarView 子项 | EffectListener + AutomaticKeepAlive |
| `AppRawPage` | 全自定义逃生口 | 仅 EffectListener |
| `AppDefaultAppBar` | 标准 AppBar | title / leading / actions / back behavior |

业务页面 95% 不该再出现裸 `Scaffold`。

### P4 · 自定义 Lint

| 规则 | 拦什么 | 救你哪些坑 |
|---|---|---|
| `avoid_raw_scaffold` | 业务文件直接用 `Scaffold` | 漏接 EffectListener / 漏 SafeArea |
| `no_ui_in_viewmodel` | VM 里 `Navigator` / `ScaffoldMessenger` / `showDialog` | VM 测试无法 headless 跑 |
| `avoid_static_mutable_in_notifier` | Notifier 里 `static var` | autoDispose 失效、跨实例污染 |
| `avoid_direct_hive_access` | 业务直接用 `Hive.box` | 无法在测试里 swap 实现 |
| `avoid_direct_method_channel` | 业务直接 `MethodChannel(...)` | 无法 fake 平台层 |

启用：`pubspec.yaml` 加 `custom_lint` + `flutter_core_lint`，`analysis_options.yaml` 开 `plugins: [custom_lint]`，跑 `dart run custom_lint`。

### P5 · 测试工具箱（`flutter_core_test`）

```dart
test('pay flow', () async {
  final h = createVmTestHarness();              // 自动 NoopHandler + EffectRecorder
  final history = h.recordStates(orderVmProvider);

  await h.read(orderVmProvider.notifier).pay();
  await h.pump();                               // 等 broadcast tick

  expect(history.values.last.status, OrderStatus.paid);
  expect(h.effects.lastPayload, isToast(message: '已支付'));
});
```

含：
* `EffectRecorder` / `StateRecorder`
* `isToast` / `isNavigate` / `isPop` / `isErrorEffect` / `isDialog` / `isHaptic` matchers
* `VmTestHarness` + `createVmTestHarness`
* `TestProviderScope`（Widget 测试用）+ `WidgetTester.recordEffects()`

### P6 · Network 抽象（HTTP + WebSocket）

> "VM 不应该 import dio/web_socket_channel。"

**HTTP**

```dart
abstract class HttpClient {
  Future<T> request<T>({required HttpMethod method, required String path, ...});
  Future<HttpResponse<T>> requestRaw<T>({...});           // 含 status/headers
  Future<T> get/post/put/patch/delete<T>(...);            // 便捷方法
  CancelToken createCancelToken();
  void close();
}

// Dio 实现：所有 DioException 自动归一到 AppException
class DioHttpClient extends HttpClient {
  Future<T> upload<T>(...);                              // multipart 上传 + 进度
  // ...
}

// 上传 payload —— 业务侧不直接 import dio
class MultipartFilePart {
  MultipartFilePart.fromPath / fromBytes / fromStream;
}

// 内置 interceptor（请求前 / 响应后）
class AuthTokenInterceptor extends Interceptor { ... }   // Bearer token
class HttpLoggingInterceptor extends Interceptor { ... } // method/path/status/耗时
class EnvelopeUnwrapInterceptor extends Interceptor { ...} // {code,message,data}

// 声明式中间件（DioHttpConfig 字段，自动按正确顺序注入到链尾）
class RetryConfig { ... }                                // 指数退避 + 抖动 + 幂等判断
class AuthRefreshConfig { ... }                          // 401 → refresh → retry，单飞保证
```

**WebSocket**

```dart
sealed class WsConnectionState {}
class WsIdle / WsConnecting / WsConnected
class WsReconnecting(attempt, nextDelay)
class WsDisconnected(code, reason)
class WsFailed(error)

abstract class WsClient {
  Stream<WsConnectionState> get connectionState;
  Stream<dynamic> get messages;                            // 全量流（不被 topicRouter 过滤）
  Future<void> connect();
  Future<void> disconnect();
  void send(Object data);                                  // Map/List 自动 jsonEncode
  Future<void> dispose();

  // topic 订阅 API（需 WsClientConfig.topicRouter 注入）
  Stream<T> subscribe<T>(String topic, {T Function(dynamic)? decoder, bool autoConnect = true});
  Future<void> unsubscribe(String topic);                  // 引用计数 -1，归零才发协议帧
  bool isSubscribed(String topic);
  Set<String> get subscribedTopics;
}

class WsTopicRouter {
  final String? Function(dynamic raw) topicExtractor;      // 从消息抽 topic
  final Object? Function(String topic)? subscribeFrameBuilder;     // null = 不通知后端
  final Object? Function(String topic)? unsubscribeFrameBuilder;
}

class DefaultWsClient implements WsClient { ... }          // 状态机 + 退避重连 + 心跳 + 订阅路由
```

**关键设计**

* `WsChannelFactory` 可注入 → 测试用 fake channel 替换，~80 行验证完整状态机
* 重连指数退避：`base × 2^(attempt-1)`，封顶 `maxDelay`，可配抖动
* 心跳定时器，业务可关 (`Duration.zero`) 或换 payload
* HTTP 错误 / WS 失败统一回到 `AppException` —— VM `run()` 自动 `EffectShowError`
* topic 订阅 = **懒连接** + **引用计数** + **重连自动 replay**
  —— 业务进页面 `subscribe()` / 出页面 `unsubscribe()`，不用关心连接生命周期 / 重连恢复

### P7 · `MaterialDefaultEffectHandler`

> "每个 app 都要写一遍 EffectHandler 吗？"

不需要——`flutter_spine` 自带一份默认实现，开箱即用：

```dart
class MaterialDefaultEffectHandler extends DefaultEffectHandler {
  // 业务定制注入点（都是可选）
  final ToastShower? toast;                          // null → SnackBar 兜底
  final Map<String, DialogShower> dialogs;           // 自动覆盖内置 'alert'/'confirm'
  final bool useGoRouter;                            // 默认 true，自动回退 Navigator
  final bool hapticEnabled;
}
```

| 内置 effect | 默认行为 | 业务定制 |
|---|---|---|
| `EffectShowToast` / `EffectShowError` | `ScaffoldMessenger.showSnackBar` | 传 `toast: (ctx, msg, lvl) => ...` |
| `EffectNavigate` | `GoRouter.maybeOf?.push`，回退 `Navigator.pushNamed` | 传 `useGoRouter: false` 或自家 handler |
| `EffectPop` | 同上回退顺序 | 同上 |
| `EffectShowDialog('alert')` | 内置单按钮提示 | `dialogs: {'alert': ...}` 覆盖 |
| `EffectShowDialog('confirm')` | 内置双按钮确认 | `dialogs: {'confirm': ...}` 覆盖 |
| `EffectHaptic` | `HapticFeedback.xxxImpact` | 传 `hapticEnabled: false` |
| 业务自定义 effect | 一律返回 `false`，透传给 `EffectListener.onEffect` | 由 Page 处理 |

### P7.5 · ViewModel mixin（双形态）

> "现有手写 provider 风格 + 新的 `riverpod_generator` 风格如何共存？"

把 4 个 base class 的能力**拆成 mixin**，旧基类成为 mixin 的薄封装：

```dart
// mixin 形式（generator 用）
mixin ViewModelMixin<S> on AutoDisposeNotifier<S> { update / emit / run }
mixin AsyncViewModelMixin<T> on AutoDisposeAsyncNotifier<T> { refresh / patch / emit / mutate }
mixin FamilyViewModelMixin<S, Arg> on AutoDisposeFamilyNotifier<S, Arg> { ... }
mixin FamilyAsyncViewModelMixin<T, Arg> on AutoDisposeFamilyAsyncNotifier<T, Arg> { ... }

// 旧基类（手写 provider 用，API 100% 兼容旧代码）
abstract class ViewModelNotifier<S>
    extends AutoDisposeNotifier<S> with ViewModelMixin<S> {}
```

| 风格 | VM 写法 | provider |
|---|---|---|
| 手写（默认） | `class FooVm extends ViewModelNotifier<FooState>` | 自己写 `final fooVmProvider = NotifierProvider.autoDispose<...>(...)` |
| generator | `@riverpod class FooVm extends _$FooVm with ViewModelMixin<FooState>` | build_runner 自动生成 `fooVmProvider` |

CLI 任意命令加 `--gen` 切到 generator 模板；`bootstrap --gen` 自动给 pubspec 追加
`build_runner / riverpod_generator / riverpod_annotation` 依赖并落 `build.yaml`。

### P8 · 一行接入（`FlutterCore.runApp`）

> "main.dart 还要写 60 行 boilerplate 吗？"

不要——`FlutterCore.runApp` **半包**：只接管 `ProviderScope` + `EffectListener`，
`MaterialApp` / theme / locale / router 100% 由业务控制。

```dart
void main() {
  FlutterCore.runApp(
    config: const FlutterCoreConfig(),                // 零字段也能跑
    app: (ctx) => MaterialApp(home: const HomePage()),
  );
}
```

`FlutterCoreConfig` 全字段渐进式（全部可选 / 有默认值）：

| 字段 | 类型 | 缺省行为 |
|---|---|---|
| `effectHandler` | `DefaultEffectHandler` | `MaterialDefaultEffectHandler()` |
| `http` | `DioHttpConfig?` | 不注入 → `httpClientProvider` read 时抛错（懒失败） |
| `ws` | `WsClientConfig Function(Uri)?` | 用 flutter_spine 默认 builder（无 topicRouter） |
| `storage` | `FutureOr<KeyValueStorage> Function()?` | 不注入 → `keyValueStorageProvider` read 时抛错 |
| `logger` | `AppLogger?` | `PrettyAppLogger` |
| `extraObservers` / `extraOverrides` | `List<...>` | 追加在默认后面（**业务覆盖默认**） |
| `errorObserverEnabled` | `bool` | `true` |
| `logObserverInDebug` | `bool` | `true`（release 自动跳过） |

### 接入自检（双保险）

1. **启动时打印**：DEBUG 下 `FlutterCore.runApp` 自动打印 `BootstrapAudit` 清单到控制台
   （✅ ok / ⚠️ warn / ⏭️ skipped）
2. **DEBUG widget**：`FlutterCoreDiagnosticsBanner()` 塞到任意页面——折叠成屏幕角落 chip，
   点开看完整接入状态。release build 编译为 `SizedBox.shrink`，零运行时开销

---

## 4. 一行 / 一句速查表

| 想做 | 答案 |
|---|---|
| 写一个简单页面 | `AppPageScaffold(title: ..., body: ...)` |
| VM 改 state | `update((prev) => prev.copyWith(...))` |
| VM 调接口 | `run(repo.x, onStart: ..., onSuccess: ..., onFailure: ...)` |
| VM 让 UI 跳页 | `emit(EffectNavigate('/detail/$id'))` |
| VM 让 UI 关页 | `emit(EffectPop(result))` |
| VM 让 UI 弹 toast | `emit(EffectShowToast('done', level: ToastLevel.success))` |
| 列表分页 | `extends AsyncNotifier with PagedNotifierMixinNoArg`，写 `fetchPage` 即可 |
| 测 VM | `final h = createVmTestHarness(); ...; expect(h.effects.lastPayload, isToast());` |
| 启动 app | `FlutterCore.runApp(config: FlutterCoreConfig(...), app: (ctx) => MaterialApp(...))` |
| 接 toast | 默认走 SnackBar；用 BotToast 传 `MaterialDefaultEffectHandler(toast: ...)` 即可 |
| 加业务弹窗 | `MaterialDefaultEffectHandler(dialogs: {'confirm': (ctx, args) => ...})` |
| 接入完成度自检 | DEBUG 自动打印；想看运行时插 `const FlutterCoreDiagnosticsBanner()` |
| 加 lint | pubspec 加 `custom_lint` + `flutter_core_lint`，重启 IDE |
| 调 HTTP | `ref.read(httpClientProvider).get<T>(path, decoder: ...)` |
| 配 HTTP | override `httpConfigProvider` 给 `DioHttpConfig(baseUrl, interceptors)` |
| 上传文件 | `httpClient.upload(path, files: [MultipartFilePart.fromPath(...)], onSendProgress: ...)` |
| 自动加鉴权 | `AuthTokenInterceptor(tokenProvider: () => storage.read('token'))` |
| 失败自动重试 | `DioHttpConfig(retry: RetryConfig(maxRetries: 3, baseDelay: ...))` |
| 401 自动 refresh | `DioHttpConfig(authRefresh: AuthRefreshConfig(refreshToken: () async => ...))` |
| 后端 envelope | `EnvelopeUnwrapInterceptor(successCode: 0)` |
| 拿 WS | `ref.watch(wsClientProvider(uri))`，调 `connect()` / `messages.listen` |
| WS 订阅 topic | `ws.subscribe<OrderEvent>('orders', decoder: ...).listen(...)`（自动 connect + 重连 replay） |
| WS 退订 topic | `await ws.unsubscribe('orders')`（引用计数 -1，归零才发 unsubscribe 帧） |
| 配 WS 协议 | override `wsConfigBuilderProvider` 给 `WsClientConfig(topicRouter: WsTopicRouter(...))` |
| WS 状态指示器 | `ref.watch(wsClient.connectionState)` 配 `switch` 渲染图标 |
| 起新页面 | `dart run flutter_spine:new async-page order_detail --with-test` |
| 起完整 feature | `dart run flutter_spine:new feature wallet --variant=async --with-repo --with-route --with-test` |
| 起新工程骨架 | `dart run flutter_spine:new bootstrap` |
| 切到 riverpod_generator 风格 | 任意 `new` 命令加 `--gen`；首次跑 `bootstrap --gen` 自动配 build_runner |
| 给 generator 类用 update/emit/run | `class FooVm extends _$FooVm with ViewModelMixin<FooState>` |

---

## 5. 端到端示例

跑一遍 `example/` —— 13 个文件演示了上面所有内容。

```bash
cd example/
flutter pub get
flutter run             # 体验
flutter test            # 6 个 VM 测试 case
dart run custom_lint    # 验证 lint 生效
```

---

## 6. 监管边界（业务团队请遵守）

* ❌ 业务包不要 `import 'package:flutter_spine/src/...'`，只走 `flutter_spine.dart` 公开导出
* ❌ 业务页面不要新建一个继承 `Scaffold` 的 widget——挑一个 AppXxxScaffold 替代
* ❌ 业务 VM 不要暴露 `BuildContext` / 不要 `showDialog`——所有"开窗"用 `EffectShowDialog`
* ❌ 不要往 Notifier 类里塞可变 `static`——用 family / scoped Provider
* ❌ 不要直接 `Dio(...)` / `WebSocketChannel.connect(...)`——走 `HttpClient` / `WsClient` 抽象
   （`avoid_direct_dio` / `avoid_direct_websocket` 两条 lint 守护）
* ✅ 自定义 Effect 直接 `class MyEffect extends Effect {}`，Page 级 `EffectListener.onEffect` 接收
* ✅ 业务 Exception 继承 `AppException` 子类（拒绝裸 throw `Exception`）

---
