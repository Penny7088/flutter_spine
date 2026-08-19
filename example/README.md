# flutter_spine example

`flutter_spine` 的端到端示例。一个 ~13 个文件的"任务管理"小应用 + 3 个 WebSocket Demo 模块，覆盖 MVVM、HTTP、WebSocket 全栈。

```
┌──────────────────────────────────────────────────────────┐
│                  HomePage  (AppPageScaffold)              │
│  ┌────────────────────┬────────────────────────────────┐  │
│  │   TasksTab          │      StatsTab                  │  │
│  │  AppPageScaffold    │   AppPageScaffold              │  │
│  │  + RefreshIndicator │   + AsyncViewModelNotifier     │  │
│  │  + 手动分页 Notifier │                                │  │
│  └─────────┬───────────┴────────────────────────────────┘  │
│            │ tap → showModalBottomSheet                     │
│            ▼                                                │
│   StatusPickerSheet  (AppBottomSheetScaffold)               │
│            │ pop(TaskStatus)                                │
│            ▼                                                │
│   tasksVm.changeStatus → patch + emit toast/error           │
└──────────────────────────────────────────────────────────┘
                       FAB │
                           ▼
              NewTaskPage  (AppFormPageScaffold)
                + NewTaskVm.submit()  → run() 三段式
                  → emit Toast + Pop
```

## 跑起来

```bash
cd package/flutter_spine/example
flutter pub get
flutter run -d chrome      # 或 -d windows / 任何已连设备
```

## 跑测试

```bash
flutter test
```

期望：3 个 test case in `new_task_vm_test.dart` + 3 个 in `tasks_vm_test.dart`，全绿。

## 跑 lint（验证 `flutter_spine_lint` 生效）

```bash
dart run custom_lint
```

故意引入违规试试：在 `lib/` 下随便写一个文件 `bad.dart`：

```dart
import 'package:flutter/material.dart';
class Bad extends StatelessWidget {
  @override
  Widget build(_) => Scaffold(body: Container());   // ← avoid_raw_scaffold 命中
}
```

应在终端看到 `WARNING: avoid_raw_scaffold` 报警。

---

## 文件地图（按使用顺序）

| 文件 | 演示什么 |
|---|---|
| `lib/main.dart` | `ProviderScope` + override `defaultEffectHandlerProvider` + 根级 `EffectListener` |
| `lib/app/effect_handler.dart` | 把所有内置 `Effect`（toast/navigate/pop/dialog/haptic）翻译到具体 UI |
| `lib/app/router.dart` | go_router 配置——VM emit 路由不感知它 |
| `lib/data/task.dart` | 简单 immutable model |
| `lib/data/task_repository.dart` | fake 仓库；`safeApiCall` 把 `throw String` → `AppException` |
| `lib/features/home/home_page.dart` | `AppPageScaffold` + `TabBar`，无嵌套 Scaffold |
| `lib/features/home/tasks_vm.dart` | 业务侧手动分页：自建 `TaskListState` + `AutoDisposeAsyncNotifier` + 手写 refresh/loadMore + 乐观更新/回滚 |
| `lib/features/home/tasks_tab.dart` | 业务侧分页列表：`RefreshIndicator` + `NotificationListener` 触发 refresh/loadMore + 触发 sheet |
| `lib/features/home/stats_vm.dart` | `AsyncViewModelNotifier`（state = `AsyncValue<T>`）|
| `lib/features/home/stats_tab.dart` | `asyncStats.when(...)` 三态 + RefreshIndicator |
| `lib/features/new_task/new_task_vm.dart` | `ViewModelNotifier` + `run()` 三段式 + `emit(EffectPop)` |
| `lib/features/new_task/new_task_page.dart` | `AppFormPageScaffold`：键盘自适应 + 底部按钮 |
| `lib/features/status_picker/status_picker_sheet.dart` | `AppBottomSheetScaffold`：drag handle + close button + radio list |

### WebSocket Demo 模块（`features/demos/`）

| 目录 | 演示什么 |
|------|----------|
| `demo_market_ws/` | `MarketWsGateway extends BaseWsGateway` — 多业务 Gateway 模式、topic 编解码、auth 刷新、StreamProvider.autoDispose 生命周期管理 |
| `demo_asset_ws/` | `AssetWsGateway` — 余额/质押订阅，与 Market 共享同一套 `WsClient` 基础设施 |
| `demo_swap_ws/` | `SwapWsGateway` — 报价/订单状态订阅，展示第三个业务模块的接入方式 |
| `demo_ws_page.dart` | `WsTopicRouter` 底层 API 演示（subscribe / unsubscribe 手控） |

三个 Gateway 模块都在 `main.dart` 的 `FlutterSpineConfig.extraOverrides` 中按 URI 注册，
通过一个 `_sharedWsConfig` 工厂共享 auth/心跳/重连策略，每个模块只覆写自己的 `topicRouter`。

## 测试模板（直接抄）

| 文件 | 学到什么 |
|---|---|
| `test/new_task_vm_test.dart` | `createVmTestHarness` + `recordStates` + `isToast/isPop/isErrorEffect` 断言 |
| `test/tasks_vm_test.dart` | `keepAlive(autoDispose)` + 等 future + 测 `run()` 失败链路 |

> ⚠️ 写 VM 测试时一定 `await h.pump()` —— `EffectBus` 是 `StreamController.broadcast`，
> 多次 emit 需要至少 1 个 event-loop tick 才能全部到达 recorder。

## 故事线（推荐阅读顺序）

1. 先看 `main.dart` 知道整个 app 怎么 bootstrap（含 `FlutterSpineConfig` WS 配置）；
2. 再看 `effect_handler.dart` 理解 effect → UI 的翻译表；
3. 看 `tasks_vm.dart` 理解"业务侧只 patch + emit，不碰 BuildContext"；
4. 看 `new_task_vm.dart` 理解"提交流程的 4 行就够：onStart / onSuccess / onFailure / 收尾 emit"；
5. 看 `demo_market_ws/main.dart` 中的 WS 注册方式 → `market_stream_providers.dart` 的 autoDispose 模式 → `market_ws_gateway.dart` 的 Gateway 实现；
6. 最后跑测试：`flutter test` —— 看 100ms 内 6 个 case 全绿。浏览 `/demos` 路由下的所有 Demo 页面。
