# flutter_spine

[![CI](https://github.com/Penny7088/flutter_arch_river_pod/actions/workflows/ci.yml/badge.svg)](https://github.com/Penny7088/flutter_arch_river_pod/actions/workflows/ci.yml)
[![pub.dev](https://img.shields.io/pub/v/flutter_spine)](https://pub.dev/packages/flutter_spine)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![codecov](https://codecov.io/gh/Penny7088/flutter_arch_river_pod/branch/main/graph/badge.svg)](https://codecov.io/gh/Penny7088/flutter_arch_river_pod)

Shared infrastructure for Flutter apps. Provides **MVVM base classes + effect bus + scaffold suite + network layer + error model**. Business packages develop new features with a unified pattern.

> **配套包**
> - [`flutter_spine_lint`](../flutter_core_lint/README.md) — 把架构约束钉成静态检查
> - [`test`](../flutter_core_test/README.md) — VM/Effect 测试 helper
>
> **延伸阅读**
> - [`ARCHITECTURE.md`](./ARCHITECTURE.md) — 架构总览（P1-P8 的来龙去脉）
> - [`example/`](./example/) — 13 文件端到端示例（任务管理小应用）

---

## 安装

```yaml
dependencies:
  flutter_spine: ^0.2.0
```

```dart
import 'package:flutter_spine/flutter_spine.dart';
```

---

## MVVM 使用文档

### 0. MVVM模型

```
┌─────────────┐   ref.watch    ┌──────────────────────────┐
│   Page      │ ─────────────▶ │   ViewModel (Notifier)    │
│ (Scaffold)  │ ◀───── state ──│  - state = 不可变值       │
│             │                 │  - 唯一 setter: update()  │
│             │ ◀── Effect ──── │  - 唯一副作用: emit()     │
└─────────────┘                 └──────────────────────────┘
        │                                   │
        │ EffectListener                    │ ref.read
        ▼                                   ▼
   DefaultEffectHandler              Repository (safeApiCall)
   (toast/router/dialog)              → AppException
```

**唯三规则**

1. State 修改 → 只能走 `update((prev) => ...)`，不能 `state = ...`
2. 副作用（toast / 跳页 / 弹窗 / 震动 / 业务事件） → 只能 `emit(EffectXxx)`，**不允许引用 `BuildContext`**
3. 异步任务 → 走 `run(action, onStart/onSuccess/onFailure)` 或 `mutate(action, applyTo)`，自动接 loading/error

违反这三条会被 [`flutter_core_lint`](../flutter_core_lint/README.md) 报警。

---

### 1. 三种 VM——选哪个？

| 适用场景 | 基类 | State 形态 | 典型代表 |
|---|---|---|---|
| **业务页面**（多字段、多动作、需自管 loading） | `ViewModelNotifier<S>` | 自定义 immutable 类（推荐 `with HasViewStatus`） | 表单、复杂工作台 |
| **单一数据展示**（拉一份、偶尔 mutate） | `AsyncViewModelNotifier<T>` | `AsyncValue<T>` | 详情页、设置页 |
| **分页列表** | `AutoDisposeAsyncNotifier<PagedState<T>> with PagedNotifierMixinNoArg<T>` | `AsyncValue<PagedState<T>>` | 订单列表、消息流 |

带运行时参数（如详情页按 `id`）的，对应有 `FamilyViewModelNotifier` / `FamilyAsyncViewModelNotifier` / `PagedNotifierMixin<T, Arg>`。

---

### 2. Pattern A — `ViewModelNotifier`（推荐默认）

适合 95% 的业务页面：表单、工作台、含多个动作和 loading/error 的页面。

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1) State —— immutable value object
@immutable
class NewTaskState with HasViewStatus {
  const NewTaskState({
    this.title = '',
    this.status = ViewStatus.idle,
    this.error,
  });

  final String title;
  @override final ViewStatus status;
  @override final AppException? error;

  bool get canSubmit => status != ViewStatus.loading && title.trim().isNotEmpty;

  NewTaskState copyWith({
    String? title,
    ViewStatus? status,
    AppException? error,
  }) =>
      NewTaskState(
        title: title ?? this.title,
        status: status ?? this.status,
        error: error ?? this.error,
      );
}

// 2) VM —— 继承 ViewModelNotifier
class NewTaskVm extends ViewModelNotifier<NewTaskState> {
  @override
  NewTaskState build() => const NewTaskState();

  void setTitle(String v) => update((s) => s.copyWith(title: v));

  Future<void> submit() async {
    if (!state.canSubmit) return;

    final r = await run(
      () => ref.read(taskRepoProvider).create(title: state.title),
      onStart:   (s)    => s.copyWith(status: ViewStatus.loading, error: null),
      onSuccess: (s, _) => const NewTaskState(status: ViewStatus.ok),
      onFailure: (s, e) => s.copyWith(status: ViewStatus.error, error: e),
    );

    if (r is Ok) {
      emit(const EffectShowToast('Saved', level: ToastLevel.success));
      emit(const EffectPop());
    }
  }
}

// 3) Provider
final newTaskVmProvider =
    NotifierProvider.autoDispose<NewTaskVm, NewTaskState>(NewTaskVm.new);
```

**关键点**

- `build()` 返回**同步**初始 state；首次异步加载在里面 `Future.microtask(load)`。
- `update()` 内部做 `identical` 短路；返回相同实例不触发 rebuild。
- `run()` 默认在失败时自动 `emit(EffectShowError(...))`，业务无须再手 catch。
- `HasViewStatus` 可选——业务用 freezed / sealed 状态也行，只是要自己传 UI builder。

---

### 3. Pattern B — `AsyncViewModelNotifier`

state 直接是 `AsyncValue<T>`，loading/error 三态由 Riverpod 全权管理。

```dart
class UserProfileVm extends AsyncViewModelNotifier<UserProfile> {
  @override
  Future<UserProfile> build() => ref.read(userRepoProvider).me();

  Future<void> renameNickname(String name) async {
    await mutate(
      () => ref.read(userRepoProvider).rename(name),
      applyTo: (curr, _) => curr.copyWith(nickname: name),
    );
    emit(const EffectShowToast('改好了'));
  }
}

final userProfileVmProvider =
    AsyncNotifierProvider.autoDispose<UserProfileVm, UserProfile>(UserProfileVm.new);
```

**API 对照**

| `ViewModelNotifier` | `AsyncViewModelNotifier` | 用法 |
|---|---|---|
| `update((prev) => next)` | `patch((curr) => next)` | 同步改 state（patch 在 loading/error 时 no-op） |
| `run(action, onStart/onSuccess/onFailure)` | `mutate(action, applyTo)` | 异步动作 + 失败 toast |
| `emit(Effect)` | `emit(Effect)` | 一致 |
| —— | `refresh()` | 重新走 `build()` |

带参数版：`FamilyAsyncViewModelNotifier<T, Arg>`，`build(Arg arg)`。

---

### 4. Pattern C — 分页列表

```dart
class TasksVm extends AutoDisposeAsyncNotifier<PagedState<Task>>
    with PagedNotifierMixinNoArg<Task> {
  @override int get pageSize => 20;

  @override
  Future<List<Task>> fetchPage(int page, int size) =>
      ref.read(taskRepoProvider).list(page: page, size: size);

  // 乐观更新 + 失败回滚
  Future<void> markDone(String id) async {
    patch((items) =>
        [for (final t in items) if (t.id == id) t.copyWith(done: true) else t]);
    try {
      await ref.read(taskRepoProvider).markDone(id);
    } on AppException catch (e) {
      _emit(EffectShowError(e));
      await refresh();
    }
  }

  void _emit(Effect e) => ref.read(effectBusProvider).emit(runtimeType, e);
}

final tasksVmProvider =
    AutoDisposeAsyncNotifierProvider<TasksVm, PagedState<Task>>(TasksVm.new);
```

> ⚠️ `PagedNotifierMixin` 不带 `emit()` 助手——如上自己写一个 `_emit` 即可，
> 或在业务包里建个 mixin。

UI 侧直接用 `PagedListView<Task>` 把 `provider` / `controllerProvider` 传进去，refresh / loadMore / 三态全自动。

**`scrollViewBuilder`** 参数让你把列表嵌入 `CustomScrollView`，自由组合 `SliverAppBar`、
`SliverToBoxAdapter` 等额外 sliver：

```dart
PagedListView<Task>(
  provider: tasksVmProvider,
  controllerProvider: tasksVmProvider.notifier,
  firstLoading: const SkeletonList(),
  itemBuilder: (ctx, task, _) => TaskTile(task),
  scrollViewBuilder: (ctx, physics, sliverChild) => CustomScrollView(
    physics: physics,
    slivers: [
      SliverAppBar(title: const Text('Pinned'), pinned: true),
      SliverToBoxAdapter(child: SomeHeader()),
      sliverChild,
      SliverToBoxAdapter(child: SomeFooter()),
    ],
  ),
)
```

**`enableLoadMore`** 设为 `false` 时隐藏上拉加载更多 footer，只保留下拉刷新（适合全量加载的列表）。

`AppListPageScaffold` 同样透传这两个参数。

---

### 5. 三大原语逐条解析

#### `update(reducer)`

```dart
update((s) => s.copyWith(busy: true));
```

- **唯一**允许改 state 的入口；直接 `state = ...` 会被 `flutter_core_lint` 警告（计划中）。
- 内部 `identical(next, prev)` 短路——返回同一实例不触发 rebuild。
- Notifier 已销毁时**静默忽略**（`StateError` 被吞）——专治"await 完页面已离开"那种崩溃。

#### `emit(Effect)`

```dart
emit(const EffectShowToast('done'));            // 内置
emit(const EffectNavigate('/order/$id'));       // 内置
emit(const EffectPop());                        // 内置
emit(EffectShowError(e));                       // 内置
emit(MyCustomEffect(payload));                  // 业务自定义
```

- 写入全局 `effectBusProvider`，自动带上 `runtimeType` 作为 source。
- UI 侧 `EffectListener(source: NewTaskVm, ...)` 按 source 过滤，避免兄弟 VM 串台。
- 内置 effect 一律由根级 `DefaultEffectHandler` 处理（toast / router / dialog / haptic）；
  自定义 effect 由 Page 级 `EffectListener.onEffect` 接收。

**6 类内置 Effect 速查**

| Effect | 字段 | 默认 handler 行为 |
|---|---|---|
| `EffectShowToast` | `message`, `level` | 调 `ScaffoldMessenger`（自定）|
| `EffectShowError` | `error: AppException` | 翻成 toast，可附错误码 |
| `EffectNavigate` | `path`, `args` | `GoRouter.push`（自定）|
| `EffectPop` | `result` | `GoRouter.pop` / `Navigator.pop` |
| `EffectShowDialog` | `dialogId`, `args` | 走业务自家的 dialog 注册中心 |
| `EffectHaptic` | `kind` | `HapticFeedback.xxxImpact` |

#### `run(action, ...)` 三段式

```dart
final r = await run(
  () => repo.something(),
  onStart:   (s)    => s.copyWith(status: ViewStatus.loading, error: null),
  onSuccess: (s, v) => s.copyWith(status: ViewStatus.ok, data: v),
  onFailure: (s, e) => s.copyWith(status: ViewStatus.error, error: e),
  emitErrorEffect: true,  // 默认；失败自动 emit(EffectShowError(e))
);
if (r is Ok<T>) { /* 后续动作，比如 emit toast + pop */ }
```

返回 `Result<T> = Ok<T> | Err<T>`——**永远不 throw**，不需要 try/catch。

---

### 6. UI 绑定

**6.1 选 Scaffold（不要再用裸 `Scaffold`）**

| Scaffold | 适用 |
|---|---|
| `AppPageScaffold` | 普通业务页面 |
| `AppListPageScaffold` | 列表页（含分页 + 三态槽位 + `scrollViewBuilder` / `enableLoadMore`） |
| `AppFormPageScaffold` | 表单页（底部固定按钮、自动避让键盘） |
| `AppBottomSheetScaffold` | 半屏 sheet 内容 |
| `AppTabChildScaffold` | TabBarView 子项 |
| `AppRawPage` | 全自定义逃生口（仍带 EffectListener）|

每个 Scaffold 都接受 `source: VmType` + `onEffect: (ctx, e) => ...`，自动挂 `EffectListener`。

> **`handleDefaultEffects` 分层策略**：避免内置 effect 被多个 Listener 重复处理：
>
> | EffectListener 位置 | `handleDefaults` | 职责 |
> |---------------------|-----------------|------|
> | 根级（`FlutterSpine.runApp`） | `false` | 不处理内置 effect |
> | `AppPageScaffold` | `true` | 统一处理 navigate/toast/pop/dialog/haptic |
> | `AppTabChildScaffold` | `false` | 只处理 `onEffect` 业务自定义 |
> | `AppBottomSheetScaffold` | `false` | 只处理 `onEffect` 业务自定义 |
>
> 父路由容器页面应设 `handleDefaultEffects: false`，避免处理子页面 VM 的 effect。

**6.2 Page 端样板**

```dart
class NewTaskPage extends ConsumerWidget {
  const NewTaskPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(newTaskVmProvider);
    final vm    = ref.read(newTaskVmProvider.notifier);

    return AppFormPageScaffold(
      title: 'New Task',
      source: NewTaskVm,                      // ← effect 过滤
      body: TextField(onChanged: vm.setTitle),
      bottomAction: FilledButton(
        onPressed: state.canSubmit ? vm.submit : null,
        child: Text(state.status.isLoading ? 'Saving…' : 'Save'),
      ),
    );
  }
}
```

**6.3 注入 DefaultEffectHandler（每个 app 一份）**

```dart
void main() {
  runApp(ProviderScope(
    overrides: [
      defaultEffectHandlerProvider
          .overrideWithValue(const MyAppEffectHandler()),
    ],
    child: const App(),
  ));
}
```

`MyAppEffectHandler` 继承 `DefaultEffectHandler`，把 `EffectShowToast` 翻译到自家 toast 库、`EffectNavigate` 翻译到自家 router——业务 VM 完全不感知具体实现。完整范例见 [`example/lib/app/effect_handler.dart`](./example/lib/app/effect_handler.dart)。

---

### 7. 业务自定义 Effect

```dart
// 1) 定义
class TrackEvent extends Effect {
  const TrackEvent(this.name, [this.props = const {}]);
  final String name;
  final Map<String, Object?> props;
}

// 2) VM 里 emit
emit(TrackEvent('checkout_clicked', {'price': 99}));

// 3) Page 里接（DefaultEffectHandler 不认识这个类型，会落到 onEffect）
AppPageScaffold(
  source: CheckoutVm,
  onEffect: (ctx, e) {
    if (e is TrackEvent) {
      ref.read(analyticsProvider).log(e.name, e.props);
    }
  },
  body: ...,
);
```

---

### 8. 测试模板

依赖 [`flutter_core_test`](../flutter_core_test/README.md)。

```dart
test('提交成功 → emit toast + pop', () async {
  final h = createVmTestHarness(
    overrides: [
      taskRepoProvider.overrideWithValue(_FakeRepo.ok()),
    ],
  );
  final history = h.recordStates(newTaskVmProvider);   // 自动 keepAlive

  h.read(newTaskVmProvider.notifier).setTitle('Hi');
  await h.read(newTaskVmProvider.notifier).submit();
  await h.pump();   // 等 broadcast tick

  expect(history.values.last.status, ViewStatus.ok);
  expect(h.effects.payloads,
      containsAllInOrder([isToast(message: 'Saved'), isPop()]));
});
```

> ⚠️ `autoDispose` provider 在 `await` 间隙会被回收。测试里要么用 `recordStates`（自动 keepAlive），要么显式 `h.keepAlive(provider)`。

完整测试范例：[`example/test/`](./example/test/)。

---

## Network 使用文档

`flutter_spine` 已经把 **HTTP（Dio 封装）** 和 **WebSocket（带状态机/重连/心跳）** 收齐到包内，
业务包不需要单独 `dio.get(...)` 或 `WebSocketChannel.connect(...)`。

### 1. HTTP（`HttpClient`）

#### 1.1 注入配置（每个 app 一份）

```dart
runApp(ProviderScope(
  overrides: [
    httpConfigProvider.overrideWithValue(
      DioHttpConfig(
        baseUrl: 'https://api.example.com',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        defaultHeaders: const {'X-App-Id': 'wallet'},
        interceptors: [
          // 自动挂 Bearer token
          AuthTokenInterceptor(
            tokenProvider: () => box.read('access_token'),
            skipPaths: const ['/auth/login', '/auth/refresh'],
          ),
          // 调试日志（仅 debug 包打 body）
          HttpLoggingInterceptor(
            logger: PrettyAppLogger(),
            logRequestBody: kDebugMode,
            logResponseBody: kDebugMode,
          ),
          // 后端 envelope: {code, message, data} 自动解包
          const EnvelopeUnwrapInterceptor(successCode: 0),
        ],
      ),
    ),
  ],
  child: const App(),
));
```

#### 1.2 业务侧调用

```dart
class UserRepository {
  UserRepository(this._http);
  final HttpClient _http;

  Future<User> me() => _http.get<User>(
        '/users/me',
        decoder: (j) => User.fromJson(j! as Map<String, dynamic>),
      );

  Future<List<Order>> orders({required int page}) => _http.get(
        '/orders',
        query: {'page': page, 'size': 20},
        decoder: (j) => (j! as List)
            .cast<Map<String, dynamic>>()
            .map(Order.fromJson)
            .toList(),
      );

  Future<Order> create(OrderDto dto) => _http.post<Order>(
        '/orders',
        body: dto.toJson(),
        decoder: (j) => Order.fromJson(j! as Map<String, dynamic>),
      );
}

final userRepoProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(httpClientProvider)),
);
```

> ✅ **不要**自己 `try/catch DioException` —— `HttpClient` 已经把所有错误归一到 `AppException`：
> 401→`UnauthorizedException`、403→`ForbiddenException`、404→`NotFoundException`、
> 5xx→`ServerException(code: status)`、超时→`TimeoutAppException`、取消→`CancelledException`、
> 断网→`NetworkException`。

#### 1.3 取消请求

```dart
class SearchVm extends ViewModelNotifier<SearchState> {
  CancelToken? _ct;

  Future<void> search(String query) async {
    _ct?.cancel();                                  // 取消上次的
    _ct = ref.read(httpClientProvider).createCancelToken();
    await run(
      () => ref.read(searchRepoProvider).find(query, cancelToken: _ct!),
      onStart:   (s) => s.copyWith(status: ViewStatus.loading),
      onSuccess: (s, items) => s.copyWith(items: items, status: ViewStatus.ok),
      // CancelledException 默认也会 emit EffectShowError；如不想让用户看到，
      // 用 emitErrorEffect: false，或在 effect handler 里过滤。
      emitErrorEffect: false,
    );
  }
}
```

#### 1.4 文件上传（`HttpClient.upload`）

`HttpClient.upload(...)` 替代手写 `Dio.post(formData)` —— 接收 `MultipartFilePart` 列表，三种来源任选：

```dart
final result = await ref.read(httpClientProvider).upload<UploadResult>(
  '/files',
  files: [
    // 1) 本地路径（移动端最常用）
    MultipartFilePart.fromPath(
      field: 'avatar',
      filePath: '/storage/photos/me.jpg',
      contentType: 'image/jpeg',
    ),
    // 2) 内存字节（Web / 截图 / 二次裁剪）
    MultipartFilePart.fromBytes(
      field: 'thumbnail',
      bytes: pngBytes,
      filename: 'thumb.png',
      contentType: 'image/png',
    ),
    // 3) 流式（大文件，不想一次性加载）
    MultipartFilePart.fromStream(
      field: 'video',
      stream: videoFile.openRead(),
      length: videoFile.lengthSync(),
      filename: 'clip.mp4',
      contentType: 'video/mp4',
    ),
  ],
  // 普通 form 字段
  fields: {'tag': 'avatar', 'uid': 42},
  // 进度回调（多次触发）
  onSendProgress: (sent, total) => debugPrint('${sent * 100 ~/ total}%'),
  decoder: (j) => UploadResult.fromJson(j! as Map<String, dynamic>),
);
```

**特性**：
* `MultipartFilePart` 是 flutter_spine 自有类型 —— **业务层不直接 import dio**（`avoid_direct_dio` lint 守护）
* 同一 `field` 多文件 → 自动生成多个 multipart part（适合后端 `attachments[]` 形态）
* 错误归一同 `request()`：5xx → `ServerException`、超时 → `TimeoutAppException`、取消 → `CancelledException`
* method 默认 `POST`，少数后端用 `PUT` 上传时传 `method: HttpMethod.put`

#### 1.5 失败重试（`RetryInterceptor`）

声明式开启——`DioHttpConfig.retry` 字段。**默认只重试幂等方法**（`GET/HEAD/PUT/DELETE/PATCH`）：

```dart
DioHttpConfig(
  baseUrl: 'https://api.example.com',
  retry: const RetryConfig(
    maxRetries: 3,
    baseDelay: Duration(milliseconds: 300),
    maxDelay: Duration(seconds: 5),
    jitterRatio: 0.2,             // ±20% 抖动避免雪崩
  ),
)
```

**默认重试条件**（任一）：
* 连接 / 发送 / 接收**超时**
* 连接错误（含 `SocketException` / `Connection refused`）
* HTTP **5xx**

**默认不重试**：
* `4xx`（业务错误，重试无意义）
* `POST`（默认认为非幂等 —— 例如付款不能重发）
* 用户主动 `cancelToken.cancel()`

**强制开启 POST 重试**（业务侧明确知道是幂等的，例如带 `Idempotency-Key` 头）：

```dart
await dio.request<dynamic>(
  '/safe-post',
  options: Options(
    method: 'POST',
    extra: const {RetryInterceptor.forceIdempotentExtraKey: true},
  ),
);
```

**完全自定义谓词**：

```dart
RetryConfig(
  shouldRetry: (err, opts) {
    // 只重试 502/503/504
    final code = err.response?.statusCode ?? 0;
    return code == 502 || code == 503 || code == 504;
  },
)
```

#### 1.6 Token 自动刷新（`AuthRefreshInterceptor`）

`401 → refresh → retry` 全自动，**带单飞保证**（N 个并发 401 只会触发 1 次刷 token）。

声明式开启：`DioHttpConfig.authRefresh` 字段：

```dart
DioHttpConfig(
  baseUrl: 'https://api.example.com',
  interceptors: [
    AuthTokenInterceptor(tokenProvider: () => session.token),  // 注入
  ],
  authRefresh: AuthRefreshConfig(
    refreshToken: () async {
      // 业务实现：调 /auth/refresh，写新 token 入 session，返回新 token
      final newToken = await ref.read(authRepoProvider).refresh();
      session.token = newToken;
      return newToken;
    },
    skipPaths: const ['/auth/login', '/auth/refresh'],  // 这俩自己 401 别套娃
  ),
)
```

**行为**：
* `refreshToken()` 返回新 token → 重发原请求 → 业务侧拿到正常响应；
* `refreshToken()` 返回 `null` / 抛异常 → 视为"登录失效"，原 401 抛出 → `UnauthorizedException`；
* 重试请求**仍然 401** → 直接抛出（最多重试一次，避免无限循环）；
* 多个 N 并发请求同时 401 → 只调 1 次 `refreshToken()`，N 个请求各自带新 token 重发。

**自定义触发条件**（少数后端把 token 过期映射成 419 / 自定义 code）：

```dart
AuthRefreshConfig(
  refreshToken: ...,
  shouldRefresh: (err) =>
      err.response?.statusCode == 401 ||
      err.response?.statusCode == 419,
)
```

#### 1.7 内置 Interceptor 速查

| Interceptor / Config | 干啥 | 何时用 |
|---|---|---|
| `AuthTokenInterceptor` | 给请求挂 `Authorization: Bearer xxx` | 99% 后端鉴权 |
| `HttpLoggingInterceptor` | 打 method + path + status + 耗时 | 全场景；body log 仅开 debug |
| `EnvelopeUnwrapInterceptor` | 解包 `{code, message, data}` 后端约定 | 后端用统一 envelope 时；否则不加 |
| `RetryConfig`（声明式） | 失败重试（指数退避 + 抖动 + 幂等判断） | 移动网络场景必备 |
| `AuthRefreshConfig`（声明式） | 401 自动 refresh → retry，带单飞 | 任何带 token 过期的 app |

> **注入顺序**：`AuthRefresh` / `Retry` 由 flutter_spine 自动按"先 401 再 5xx"的正确顺序追加到链尾，业务 `interceptors` 列表保持只放"请求前/响应后"的轻量拦截器（auth/log/envelope）。

需要更多自定义？`DioHttpConfig.interceptors` 接受任何 `dio.Interceptor`——直接写 Dio interceptor 即可（**业务侧建议遵守 `avoid_direct_dio` lint，把 dio 类型限制在 interceptor 内部**）。

#### 1.8 测试 Repository

```dart
test('UserRepository.me 解析正确', () async {
  final dio = Dio()
    ..httpClientAdapter = MyFakeAdapter((opts) => responseFor(opts));
  final repo = UserRepository(DioHttpClient.fromDio(dio));

  final user = await repo.me();
  expect(user.id, 42);
});

test('401 → UnauthorizedException', () async {
  final dio = Dio()..httpClientAdapter = MyFakeAdapter((_) => unauthorized());
  final repo = UserRepository(DioHttpClient.fromDio(dio));

  await expectLater(repo.me(), throwsA(isA<UnauthorizedException>()));
});
```

VM 测试想 mock 整个 Repository：直接 override `userRepoProvider` 即可，无需 mock Dio。

### 2. WebSocket（`WsClient`）

#### 2.1 注入配置（可选；不注入用默认值）

```dart
runApp(ProviderScope(
  overrides: [
    wsConfigBuilderProvider.overrideWithValue(
      (uri) => WsClientConfig(
        url: uri,
        // 动态 headers —— 每次 connect/重连实时调用，token 过期后无需重建 config
        headersProvider: () => {'Authorization': 'Bearer ${session.token}'},
        // 也可以 token 走 URL query string 而非 header：
        // queryParamsProvider: () => {'token': session.accessToken},
        heartbeatInterval: const Duration(seconds: 25),
        heartbeatPayload: {'op': 'ping'},
        baseReconnectDelay: const Duration(seconds: 1),
        maxReconnectDelay: const Duration(seconds: 30),
        maxReconnectAttempts: -1,                  // 无限重连
        // 可选：开启 topic 订阅 API（不开则只能用 raw messages 流）
        topicRouter: WsTopicRouter(
          topicExtractor: (raw) =>
              (jsonDecode(raw as String) as Map)['channel'] as String?,
          subscribeFrameBuilder:
              (t) => {'op': 'subscribe', 'channel': t},
          unsubscribeFrameBuilder:
              (t) => {'op': 'unsubscribe', 'channel': t},
        ),
        // 可选：auth 过期自动刷新 token（基于 close code 检测）
        isAuthCloseCode: (code) => code == 4001,
        onAuthExpired: () async => ref.read(authRepoProvider).refresh(),
      ),
    ),
  ],
  child: const App(),
));
```

> **`headersProvider` vs 旧版 `headers`**：`headersProvider` 是一个回调，每次 connect / 重连时调用取最新值。
> 旧版 `headers` 是静态 Map，token 过期后重连会带旧 token。建议所有新代码用 `headersProvider`。
>
> **`queryParamsProvider`**：token 走 URL query string（`?token=xxx`）而非 HTTP header 时使用。
> 行为同 `headersProvider`——每次 connect / 重连回调取最新值，手动拼接 URL 避免 Dart SDK `Uri.replace()` 在某些场景下引入 `:0` 端口的 bug。
>
> **Channel 类型**：`_defaultFactory` 统一使用 `IOWebSocketChannel.connect()`——不再根据参数
> 隐式切换 `WebSocketChannel.connect()` 和 `IOWebSocketChannel`，行为可预期。
>
> **`WsTopicRouter.simple()`**：适用于 topic 名 = channel 名的标准 pub/sub 协议，
> 一行替代手写三回调：
> ```dart
> topicRouter: WsTopicRouter.simple(channelKey: 'channel'),
> ```
> 复合 topic（如 Market 的 `price-info|eip155:1|native`）仍需完整构造器。
>
> **`WsModuleRegistry`**：多个业务模块时，用注册表替代 if-else 分支：
> ```dart
> // 各模块定义 WsModuleConfig 实例
> final marketWsModule = WsModuleConfig(uri: marketWsUri, topicRouter: marketTopicRouter);
> // main.dart 中一行注册
> WsModuleRegistry.build(modules: [marketWsModule, assetWsModule], defaultConfig: sharedWsConfig)
> ```
> 新增模块只需在列表加一项，main.dart 不再膨胀。

#### 2.2 业务侧使用：topic 订阅 API（推荐）

> 推荐姿势：**不要手动 `connect()`**——`subscribe` 会在第一次被调用时自动 connect（懒连接），
> 业务只关心"我要哪些 topic 的数据 / 不要了"。

```dart
class OrderFeedVm extends AsyncViewModelNotifier<List<Order>> {
  StreamSubscription<OrderEvent>? _sub;

  @override
  Future<List<Order>> build() async {
    final ws = ref.watch(wsClientProvider(Uri.parse('wss://api.example.com/feed')));

    // 进入页面订阅；retain 期间持续接收。第一次 subscribe 会自动 connect。
    _sub = ws
        .subscribe<OrderEvent>(
          'order_update',
          decoder: (raw) =>
              OrderEvent.fromJson(jsonDecode(raw as String) as Map<String, dynamic>),
        )
        .listen(_apply);

    // 离开页面：解订阅 + 取 listener。引用计数归零时 client 会自动发 unsubscribe 帧。
    ref.onDispose(() async {
      await _sub?.cancel();
      await ws.unsubscribe('order_update');
    });

    return ref.read(orderRepoProvider).initial();
  }

  void _apply(OrderEvent e) =>
      patch((curr) => [for (final o in curr) if (o.id == e.id) e.toOrder() else o]);
}
```

订阅 API 的关键行为：

| 行为 | 说明 |
|---|---|
| **懒连接** | 第一次 `subscribe(autoConnect: true)`（默认）触发 `connect()`；不需要 `main.dart` 里就 connect |
| **引用计数** | 同一 topic 多次 `subscribe` → 共享同一 broadcast stream；`unsubscribe` 计数 -1，归零才发协议帧 |
| **多订阅者隔离** | 模块 A 订阅 + 模块 B 订阅 → A 的 `unsubscribe` 不会影响 B 收消息 |
| **重连自动 replay** | 网络抖动重连后，所有活跃 topic 的 subscribe 帧自动重发；业务无感知，**不需要在 connectionState 监听里手动恢复** |
| **路由由业务定义** | `topicExtractor` / frame builder 都是注入的；同一份 `WsClient` 适配任何后端协议（pub/sub / channel / 自定义） |
| **协议可选** | `subscribeFrameBuilder == null` → 纯客户端 filter，不通知后端，适合"后端无差别推送，客户端按 topic 路由"场景 |

辅助 API：

```dart
ws.isSubscribed('order_update');   // bool
ws.subscribedTopics;               // Set<String>，只读快照
```

#### 2.3 多业务 Gateway 模式（`BaseWsGateway` + `StreamProvider`）

多个业务模块（Market / Asset / Swap）各自一套 WS 协议时，三层架构避免重复：

```
StreamProvider.autoDispose.family    ← 页面级生命周期（自动 unsubscribe）
  └── MarketWsGateway extends BaseWsGateway   ← 业务协议适配
        └── wsClientProvider(marketWsUri)     ← 连接级生命周期（共享连接池）
              └── DefaultWsClient             ← 连接/心跳/重连/引用计数
```

**层 1：`BaseWsGateway`**（`flutter_spine` 核心提供）

```dart
abstract class BaseWsGateway {
  final WsClient ws;
  const BaseWsGateway(this.ws);

  // 透传：连接状态、生命周期、订阅查询
  WsConnectionState get currentState => ws.currentState;
  Stream<WsConnectionState> get connectionState => ws.connectionState;
  Future<void> connect() => ws.connect();
  Future<void> disconnect({int? code, String? reason}) => ws.disconnect(...);
  bool isSubscribed(String topic) => ws.isSubscribed(topic);
  Set<String> get subscribedTopics => ws.subscribedTopics;
}
```

**层 2：业务 Gateway**（Market 模块实现，~60 行）

```dart
class MarketWsGateway extends BaseWsGateway {
  MarketWsGateway(super.ws);

  Stream<PriceUpdate> subscribePrice(String chain, String addr) =>
      ws.subscribe('price-info|$chain|$addr', decoder: PriceUpdate.fromRaw);

  Future<void> unsubscribePrice(String chain, String addr) =>
      ws.unsubscribe('price-info|$chain|$addr');
}
```

**层 3：`StreamProvider.autoDispose.family`**（自动生命周期管理）

```dart
final priceStreamProvider = StreamProvider.autoDispose
    .family<PriceUpdate, (String chain, String addr)>(
  (ref, params) {
    final (chain, addr) = params;
    final gw = ref.watch(marketGatewayProvider);
    ref.onDispose(() => gw.unsubscribePrice(chain, addr));  // ← 自动退订
    return gw.subscribePrice(chain, addr);
  },
);
```

页面只需 `ref.watch(priceStreamProvider(('eip155:1', 'native')))`。页面退出时 Widget 从树中移除
→ `autoDispose` 触发 → `ref.onDispose` 回调 → `unsubscribePrice` → 引用计数归零 → 发 unsubscribe 帧。
**不需要手动管理任何 StreamSubscription 或 unsubscribe 调用。**

完整示例见 [`example/lib/features/demos/demo_market_ws/`](./example/lib/features/demos/demo_market_ws/)。

#### 2.4 Token 过期自动刷新

`WsClientConfig` 内建的 token 刷新机制——对标 HTTP 层的 `AuthRefreshInterceptor`：

| 配置字段 | 作用 |
|----------|------|
| `headersProvider` | 每次 connect / 重连时实时获取最新 token |
| `isAuthCloseCode` | 判断 close code 是否为 auth 过期（如 4001） |
| `onAuthExpired` | token 刷新回调（单飞保证——并发只调一次） |

**流程**：

```
Server close (code=4001)
  → _onChannelDone → _handleRemoteClose
    → closeCode == 4001 && isAuthCloseCode(4001)
      → onAuthExpired()                     ← 单飞刷新
        → 成功 → reset reconnect counter → _doConnect（带新 token）
        → 失败 → WsFailed
```

> 未配置 `onAuthExpired` 时，auth close code 会走普通重连逻辑（但旧 token 会导致持续失败）。

#### 2.5 raw messages 流（不需要 topic 路由时）

不配 `topicRouter`，或纯粹想看全量帧时（调试 / 服务端只推一种消息）：

```dart
@override
Future<List<Order>> build() async {
  final ws = ref.watch(wsClientProvider(Uri.parse('wss://api.example.com/feed')));
  await ws.connect();
  _sub = ws.messages.listen((raw) => _onPush(raw));
  ref.onDispose(() => _sub?.cancel());
  return ref.read(orderRepoProvider).initial();
}
```

> ⚠️ 即使配了 `topicRouter`，`messages` 流仍接收**全量**消息（不做路由过滤）——
> 路由只影响 `subscribe()` 返回的子流。两套 API 互不干扰。

#### 2.6 UI 显示连接指示器

```dart
class WsIndicator extends ConsumerWidget {
  const WsIndicator({super.key, required this.uri});
  final Uri uri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_wsStateProvider(uri));
    final color = switch (state) {
      WsConnected()    => Colors.green,
      WsConnecting()   => Colors.amber,
      WsReconnecting() => Colors.orange,
      WsDisconnected() => Colors.grey,
      WsFailed()       => Colors.red,
      WsIdle()         => Colors.grey,
    };
    return Icon(Icons.circle, color: color, size: 10);
  }
}

final _wsStateProvider = StreamProvider.family<WsConnectionState, Uri>(
  (ref, uri) => ref.watch(wsClientProvider(uri)).connectionState,
);
```

#### 2.7 状态机

```
WsIdle ──connect()──▶ WsConnecting ──ready──▶ WsConnected
                          │                         │
                          │ ready 失败              │ remote close
                          ▼                         ▼
                     WsReconnecting(attempt,    closeCode 检查:
                      nextDelay)                ├─ 1000/1001 → WsDisconnected（不再重连）
                          │                     ├─ auth code (4001) → onAuthExpired()
                          │ 退避结束              │     ├─ 成功 → 重连（带新 token）
                          ▼                     │     └─ 失败 → WsFailed
                    （回到 WsConnecting，循环）   └─ 其余 → WsReconnecting
                          │
                          │ 达到 maxReconnectAttempts
                          ▼
                     WsFailed(error)

任何状态 ──disconnect()──▶ WsDisconnected   （不再自动重连）
```

#### 2.8 内部行为

| 行为 | 默认 | 自定义 |
|---|---|---|
| 心跳间隔 | 25s | `heartbeatInterval`；`Duration.zero` 关闭 |
| 心跳载荷 | `{"op":"ping"}` | `heartbeatPayload`；`Map`/`List` 自动 jsonEncode |
| 连接 headers | 无 | `headersProvider`：每次 connect/重连实时获取 |
| token 刷新 | 无 | `onAuthExpired` + `isAuthCloseCode`（close code 路径）+ `isConnectAuthError`（连接拒绝路径）：单飞刷新 + 自动重连 |
| URL 容错 | 无 | `http→ws` / `https→wss` 自动修正 + `:0` port 自动移除 |
| 重连退避 | base × 2^(attempt-1)，封顶 maxDelay | `baseReconnectDelay` / `maxReconnectDelay` |
| 退避抖动 | ±20% | `reconnectJitterRatio`；0 关闭 |
| 最大重连次数 | 无限 | `maxReconnectAttempts`；达到后 `WsFailed` |
| 握手超时 | 10s | `connectTimeout` |

#### 2.9 测试 WsClient

注入 fake `WsChannelFactory`——见 [`test/network/ws/default_ws_client_test.dart`](./test/network/ws/default_ws_client_test.dart) 的 `_FakeWsChannel` 实现，~80 行可全套验证状态机/重连/心跳。topic 订阅 API 的测试见 [`test/network/ws/ws_topic_subscription_test.dart`](./test/network/ws/ws_topic_subscription_test.dart)。

```dart
final source = _ChannelSource();
final client = DefaultWsClient(config, channelFactory: source.factory);

await client.connect();
source.last.completeReady();              // 模拟握手成功
source.last.receiveMessage('hello');      // 模拟服务端推送
source.last.simulateRemoteClose();        // 触发自动重连
```

---

## 模块说明

| 模块 | 路径 | 说明 |
|---|---|---|
| **Effect** | `src/effect/` | `EffectBus` + `Effect` sealed + `EffectListener` + `DefaultEffectHandler` |
| **State** | `src/state/` | `ViewModelNotifier` / `AsyncViewModelNotifier` + family 版 + `ViewStatus` + `HasViewStatus` |
| **UI** | `src/ui/` | `AppDefaultAppBar` + 6 个 `AppXxxScaffold` |
| Error | `src/error/` | `sealed AppException` 层级 + `safeApiCall` + `Result<T>` |
| **HTTP** | `src/network/http/` | `HttpClient` + `DioHttpClient` + 3 内置 Interceptor + provider |
| **WebSocket** | `src/network/ws/` | `WsClient` + `DefaultWsClient`（重连/心跳/状态机/topic 订阅/token 刷新）+ `BaseWsGateway` + `WsTopicRouter` + provider |
| Network | `src/network/` | `ChannelClient`（MethodChannel 薄封装） |
| Pagination | `src/pagination/` | `PagedState` + `PagedNotifierMixin` + `PagedListView` |
| Filter | `src/filter/` | `FilterNotifier` 过滤基类 |
| Presentation | `src/presentation/` | `AsyncBuilder` + `AsyncValue` 扩展 + 三态 page-state view |
| Logging | `src/logging/` | `AppLogger` 抽象 + `PrettyAppLogger` |
| Observers | `src/observers/` | `ErrorObserver` + `LogObserver` |
| Storage | `src/storage/` | `KeyValueStorage` + `HiveStorage` |
| Theme | `src/theme/` | `AppThemeExtension` + `ThemeModeNotifier` |
| Utils | `src/utils/` | 数值、字符串、日期、集合、BuildContext 扩展 |

---

## 业务包接入模板（一行 API）

`flutter_spine` 提供 `FlutterSpine.runApp` 一行启动——**半包**：本类只接管
`ProviderScope` + `EffectListener`，`MaterialApp` 100% 由业务控制。

### 极简——零配置（直接能跑）

```dart
import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';

void main() {
  FlutterSpine.runApp(
    // 不传 config 也行：默认 effectHandler = MaterialDefaultEffectHandler()
    app: (ctx) => MaterialApp(home: const HomePage()),
  );
}
```

### 进阶——业务全套接入

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:hive/hive.dart';

void main() {
  FlutterSpine.runApp(
    config: FlutterSpineConfig(
      // 1) 业务 toast/dialog —— 不需要再写一个 EffectHandler 子类
      effectHandler: MaterialDefaultEffectHandler(
        toast: (ctx, msg, lvl) {
          BotToast.showText(text: msg);
          return true;
        },
        dialogs: {
          'order_confirm': (ctx, args) => showDialog(
            context: ctx,
            builder: (_) => OrderConfirmDialog(args as OrderArgs),
          ),
        },
      ),
      // 2) HTTP
      http: DioHttpConfig(
        baseUrl: 'https://api.example.com',
        interceptors: [
          AuthTokenInterceptor(tokenProvider: () => null),
          HttpLoggingInterceptor(logRequestBody: kDebugMode),
        ],
      ),
      // 3) WebSocket（带业务 topic 协议）
      ws: (uri) => WsClientConfig(
        url: uri,
        heartbeatInterval: const Duration(seconds: 25),
        heartbeatPayload: const {'op': 'ping'},
        topicRouter: WsTopicRouter(
          topicExtractor: (raw) =>
              (jsonDecode(raw as String) as Map)['channel'] as String?,
          subscribeFrameBuilder: (t) => {'op': 'subscribe', 'channel': t},
          unsubscribeFrameBuilder: (t) => {'op': 'unsubscribe', 'channel': t},
        ),
      ),
      // 4) KV 存储（异步初始化）
      storage: () async {
        await Hive.initFlutter();
        final box = await Hive.openBox<dynamic>('prefs');
        return HiveStorage.fromBox(box);
      },
      // 5) 业务自定义 observers / overrides
      extraObservers: const [MyAnalyticsObserver()],
      extraOverrides: [myAppConfigProvider.overrideWithValue(const AppCfg())],
    ),
    app: (ctx) => MaterialApp.router(routerConfig: buildRouter()),
  );
}
```

### `FlutterSpineConfig` 字段

| 字段 | 类型 | 默认值 / 缺省行为 |
|---|---|---|
| `effectHandler` | `DefaultEffectHandler` | `MaterialDefaultEffectHandler()`（SnackBar + GoRouter + Haptic） |
| `http` | `DioHttpConfig?` | `null` → `httpClientProvider` 在被 read 时抛错（懒失败） |
| `ws` | `WsClientConfig Function(Uri)?` | `null` → 用默认 builder（无 topicRouter） |
| `storage` | `FutureOr<KeyValueStorage> Function()?` | `null` → `keyValueStorageProvider` 在被 read 时抛错 |
| `logger` | `AppLogger?` | `null` → 默认 `PrettyAppLogger` |
| `extraObservers` | `List<ProviderObserver>` | `const []`，追加在默认 observers 后面 |
| `extraOverrides` | `List<Override>` | `const []`，追加在默认 overrides 后面（**会覆盖默认**） |
| `errorObserverEnabled` | `bool` | `true` |
| `logObserverInDebug` | `bool` | `true`（release build 自动跳过） |

### 接入自检

`FlutterSpine.runApp` 在 DEBUG 下会自动打印一份"接入完成度"清单到控制台：

```
╔═════════════════════════════════════════════════════════
║  flutter_spine bootstrap audit (DEBUG ONLY)
╠═════════════════════════════════════════════════════════
║  ✅ effectHandler     : MaterialDefaultEffectHandler
║       └─ default Material handler — pass custom toast/dialogs to override
║  ✅ http              : baseUrl=https://api.example.com
║       └─ 2 interceptor(s)
║  ✅ ws                : custom builder
║  ⏭️  storage           : not configured
║       └─ keyValueStorageProvider will throw on first read
║  ✅ logger            : PrettyAppLogger (default)
╚═════════════════════════════════════════════════════════
```

想在 app 里随时看一眼当前接入状态？把 `FlutterSpineDiagnosticsBanner` 塞到任意页面：

```dart
Scaffold(
  body: Stack(children: [
    YourPageContent(),
    const FlutterSpineDiagnosticsBanner(), // DEBUG only，release 编译为 SizedBox
  ]),
)
```

折叠成屏幕角落小 chip，点开看完整清单——release build 自动消失，零运行时开销。

### 自定义 `MaterialDefaultEffectHandler`

`MaterialDefaultEffectHandler` 处理所有 6 个内置 effect，业务自定义 effect 会自动透传给
Page 级 `EffectListener.onEffect`。99% 场景**不需要**再写自家 handler，按需通过 ctor 注入即可：

| 想做的事 | 怎么做 |
|---|---|
| 用 BotToast / Fluttertoast 替代 SnackBar | 传 `toast: (ctx, msg, lvl) { ...; return true; }` |
| 注册业务弹窗 | 传 `dialogs: {'pay_confirm': (ctx, args) => showDialog(...)}` |
| 关闭 GoRouter（用 Navigator） | 传 `useGoRouter: false` |
| 完全关闭震动 | 传 `hapticEnabled: false` |
| 自家覆盖内置 `'alert'` / `'confirm'` | `dialogs` 传同名 key |

只有当你想**完全接管**所有 effect 时，才需要 `class XxxHandler extends DefaultEffectHandler`。

---

## 脚手架 CLI（`flutter_spine:new`）

不再人工 Ctrl-C/V 模板代码——`flutter_spine` 自带一个 Dart CLI，在业务工程根目录里
直接跑 `dart run flutter_spine:new <command>` 一次落齐 page / vm / state / 测试 / 路由。

### 命令总览

```bash
dart run flutter_spine:new --help
```

| 命令 | 一句话 | 默认产出 |
|---|---|---|
| `page` | 同步 VM 页面 | `<name>_state.dart` + `<name>_vm.dart` + `<name>_page.dart` |
| `async-page` | 拉接口页面（`AsyncViewModelNotifier` + `AsyncBuilder`） | `<name>_data.dart` + `<name>_vm.dart` + `<name>_page.dart` |
| `paged-list` | 分页列表（`PagedNotifierMixin` + `AppListPageScaffold`） | `<name>_item.dart` + `<name>_vm.dart` + `<name>_page.dart` |
| `form` | 表单页（state + canSubmit + run + EffectPop） | `<name>_state.dart` + `<name>_vm.dart` + `<name>_page.dart` |
| `repo` | Repository 三件套（abstract + Http impl + provider） | 生成到 `lib/data/` |
| `effect` | 自定义 Effect 类 | 生成到 `lib/effects/` |
| `feature` | **一键全套**：page + 可选 repo + 可选路由 + 可选测试 | 见下 |
| `bootstrap` | 整个 app 的启动骨架（直接用 `MaterialDefaultEffectHandler`） | `lib/main.dart` + `lib/app/router.dart` |

### 通用 options

| flag | 作用 |
|---|---|
| `--path <dir>` | 输出目录，默认 `lib/features/<name_snake>` |
| `--with-test` | 同时在 `test/features/<name_snake>/` 下生成测试，使用 `flutter_core_test` 工具箱 |
| `--dry-run` | 只打印将要写的文件，不真落盘——首次跑必看 |
| `-f, --force` | 已存在的文件直接覆盖（默认会跳过并 warn） |

### 命名约定

输入名怎么写都行——CLI 自动在模板里替换为各种 case：

| 输入 | `{{Name}}` | `{{name}}` | `{{name_snake}}` | `{{name-kebab}}` | `{{Title}}` |
|---|---|---|---|---|---|
| `user_profile` | `UserProfile` | `userProfile` | `user_profile` | `user-profile` | `User Profile` |
| `userProfile` | `UserProfile` | `userProfile` | `user_profile` | `user-profile` | `User Profile` |
| `User-Profile` | `UserProfile` | `userProfile` | `user_profile` | `user-profile` | `User Profile` |

### 典型用法

**1. 启动新工程**

```bash
dart pub add flutter_spine --path=../package/flutter_spine
dart run flutter_spine:new bootstrap                # 一次生成 main + router（用默认 MaterialDefaultEffectHandler）
```

**2. 起一个新业务页面**

```bash
dart run flutter_spine:new async-page order_detail --with-test
# →  lib/features/order_detail/order_detail_data.dart
# →  lib/features/order_detail/order_detail_vm.dart
# →  lib/features/order_detail/order_detail_page.dart
# →  test/features/order_detail/order_detail_vm_test.dart
```

**3. 一键起完整 feature（含 repo + 路由 + 测试）**

```bash
dart run flutter_spine:new feature wallet \
    --variant=async --with-repo --with-route --with-test

# 产出：
#   lib/features/wallet/wallet_{data,vm,page}.dart
#   lib/data/wallet/wallet_repository{,_impl,_provider}.dart
#   test/features/wallet/wallet_vm_test.dart
# 同时自动 patch lib/app/router.dart：
#   - 加 import 'package:<pkg>/features/wallet/wallet_page.dart'
#   - 在 routes:[ 后追加 GoRoute(path: '/wallet', builder: ... WalletPage())
```

`feature` 的 `--variant` 可选 `page` / `async` / `list` / `form`，对应上表四种页面命令。

**4. 单独生成 Repository / Effect**

```bash
dart run flutter_spine:new repo user      # → lib/data/user_repository{,_impl,_provider}.dart
dart run flutter_spine:new effect refresh_balance   # → lib/effects/refresh_balance_effect.dart
```

### riverpod_generator 风格（`--gen`）

CLI 同时支持 **手写 provider**（默认）和 **`@riverpod` 注解 + build_runner** 两种模式。
所有 5 个产出页面/repo 的命令都支持 `--gen` flag：

```bash
# 一次接入 generator——pubspec 自动加 build_runner / riverpod_generator / riverpod_annotation
# + 落地 build.yaml + 控制台提示下一步要跑的 build_runner 命令
dart run flutter_spine:new bootstrap --gen

# 然后所有 feature/page/... 命令都可加 --gen
dart run flutter_spine:new feature wallet --variant=async --with-repo --with-test --gen
dart run flutter_spine:new page user_profile --gen
```

加 `--gen` 后生成的 vm 文件长这样：

```dart
import 'package:flutter_spine/flutter_spine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'wallet_data.dart';

part 'wallet_vm.g.dart';

@riverpod
class WalletVm extends _$WalletVm with AsyncViewModelMixin<WalletData> {
  @override
  Future<WalletData> build() async {
    return ref.read(walletRepositoryProvider).load();
  }
}
```

跑一次 `dart run build_runner build --delete-conflicting-outputs` 就能用——
生成的 `walletVmProvider` 名字和手写模式**完全一致**，所以 page / test 文件**两种模式共享**。

#### Mixin 提供的能力（手写 / generator 通用）

| Mixin | 应用到 | 提供的 API |
|---|---|---|
| `ViewModelMixin<S>` | `AutoDisposeNotifier<S>` | `update` / `emit` / `run` |
| `AsyncViewModelMixin<T>` | `AutoDisposeAsyncNotifier<T>` | `refresh` / `patch` / `emit` / `mutate` |
| `FamilyViewModelMixin<S, Arg>` | `AutoDisposeFamilyNotifier<S, Arg>` | 同上 sync 版 |
| `FamilyAsyncViewModelMixin<T, Arg>` | `AutoDisposeFamilyAsyncNotifier<T, Arg>` | 同上 async 版 |

> 旧基类（`ViewModelNotifier` / `AsyncViewModelNotifier` / family 版）现在是这些 mixin 的薄封装——
> API 100% 兼容老代码。手写风格继续用基类，generator 风格用 mixin，**业务能力等价**。

### 安全网

* 默认**不**覆盖任何已存在的文件——必须显式 `--force`。先 `--dry-run` 看清楚要写哪几个，再加 `-f`。
* `feature --with-route` 在 `routes: [` 块里 **idempotent 追加**：同一 path 已存在会 skip，不会重复加。
* CLI 不会修改 `pubspec.yaml`、不会跑 `pub get`，所有副作用都在 `lib/` & `test/` 下。
* 模板代码里都带了 `// TODO:` 标注，明确指出业务需要替换的接入点（如 `repo.fetch(...)`）。
* 生成的样板代码经过 `flutter analyze` 验证零 lint，自带的 vm 测试也都是绿的——可以直接 `flutter test` 跑通。

---

## 开发约定

1. ⛔ **VM 里不要引用 `BuildContext` / `Navigator` / `ScaffoldMessenger` / `showDialog`** — 一律走 `emit(EffectXxx)`。`no_ui_in_viewmodel` lint 会拦。
2. ⛔ **业务页面不要新建继承 `Scaffold` 的 widget** — 选一个 `AppXxxScaffold`。`avoid_raw_scaffold` lint 会拦。
3. ⛔ **Notifier 类里禁 `static` 可变字段**。`avoid_static_mutable_in_notifier` lint 会拦。
4. ⛔ **不要直接 `Hive.box(...)` / `MethodChannel(...)` / `Dio(...)` / `WebSocketChannel.connect(...)`** — 走 `KeyValueStorage` / `ChannelClient` / `HttpClient` / `WsClient` 抽象。
5. ✅ **DataSource / Repository 出口**必须 `safeApiCall(...)` 包裹（除非用 `HttpClient`，它已经内置归一），保证上层只面对 `AppException`。
6. ✅ **family 参数**必须是不可变值对象（正确实现 `==` / `hashCode`）。
7. ✅ **toast / 跳页 / 弹窗** 全部走 `EffectXxx` —— 业务 host 一份 `DefaultEffectHandler` 决定真实呈现。
8. `Core` 不包含任何业务颜色、路由名、API 端点。

> 启用 lint：`pubspec.yaml` 加 `dev_dependencies: { custom_lint: ^0.7.0, flutter_core_lint: { path: ../flutter_core_lint } }`，
> `analysis_options.yaml` 写入 `analyzer: { plugins: [custom_lint] }`，重启 IDE 或跑 `dart run custom_lint`。

---

## 错误流向

```
HTTP                          WebSocket                    Native
Dio (DioException)            WebSocketChannel (Exception) MethodChannel (PlatformException)
    ↓ DioHttpClient mapper        ↓ DefaultWsClient mapper     ↓ ChannelClient + safeApiCall
AppException (sealed) ←──────────┴────────────────────────────┘
    ↓ throw / Future.error
Repository → VM.run() / mutate() / fetchPage()
    ↓ Result.Err
emit(EffectShowError(e))      ←── 默认自动发，无须业务关心
    ↓
EffectListener → DefaultEffectHandler → toast/dialog
    +
ErrorObserver(logger)         ←── 同时记日志
```

---

## 测试

```bash
cd package/flutter_spine
flutter test
```

写业务 VM 测试请用 [`flutter_core_test`](../flutter_core_test/README.md)。

---

## 进阶阅读

- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — P1-P5 设计来龙去脉、决策记录、roadmap
- [`example/`](./example/) — 端到端任务管理示例（13 文件 + 6 个测试）
- [`flutter_core_lint`](../flutter_core_lint/README.md) — 5 条静态约束
- [`flutter_core_test`](../flutter_core_test/README.md) — 测试 helper API 全集
