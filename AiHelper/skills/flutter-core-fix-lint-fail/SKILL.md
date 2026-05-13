---
name: flutter-core-fix-lint-fail
description: Diagnose and fix flutter_core_lint failures (avoid_raw_scaffold, no_ui_in_viewmodel, avoid_static_mutable_in_notifier, avoid_direct_hive_access, avoid_direct_method_channel, avoid_direct_dio, avoid_direct_websocket) or custom_lint plugin crashes. Use when dart run custom_lint reports an error or the plugin crashes.
---

# 修 custom_lint 报错

## 第一步：分清楚是「代码命中规则」还是「插件崩了」

```bash
cd package/flutter_core/example
dart run custom_lint
```

| 输出形态 | 含义 | 跳到下面对应章节 |
|---|---|---|
| `lib/foo.dart:12:3 • avoid_xxx • 一段中文 problemMessage` | 业务代码命中 lint | § A |
| `Unhandled exception: type 'X' is not a subtype of type 'Y' in type cast` | plugin 自身 crash | § B |
| `flutter_core_lint:custom_lint failed to load` | plugin 加载失败 | § C |

---

## A. 代码命中规则

### `avoid_raw_scaffold`

业务页面用了裸 `Scaffold(...)` 或 `class XxxPage extends StatelessWidget` 里返回 `Scaffold`。

```dart
// ❌
return Scaffold(appBar: AppBar(title: Text('x')), body: ...);

// ✅
return AppPageScaffold(title: 'x', body: ...);
```

如果是真的需要全自定义（启动屏 / 全屏播放器），用 `AppRawPage(child: ...)` —— 仍然挂 `EffectListener`，但 layout 完全你写。

### `no_ui_in_viewmodel`

VM 里出现了 `BuildContext` / `Navigator` / `ScaffoldMessenger` / `showDialog` / `showModalBottomSheet`。

```dart
// ❌
class FooVm extends ViewModelNotifier<FooState> {
  void onTap(BuildContext ctx) => Navigator.of(ctx).push(...);
}

// ✅
void onTap() => emit(const EffectNavigate('/detail/42'));
```

需要 dialog 结果回流？发 `EffectShowDialog('confirm', args: ...)`，UI 接到后 `showDialog`，结果通过业务方法回传 VM（`vm.onConfirm()`）。

### `avoid_static_mutable_in_notifier`

```dart
// ❌
class FooVm extends ViewModelNotifier<FooState> {
  static int _retryCount = 0;       // autoDispose 失效，跨实例污染
}

// ✅ 用 family 把"共享状态"显式化
final retryCounterProvider = Provider.autoDispose.family<int, String>((ref, key) => 0);
```

或者用 `state` 字段保存，或抽成 `keyValueStorageProvider`（持久化）。

### `avoid_direct_hive_access`

```dart
// ❌
final box = Hive.box('orders');
await box.put('last_id', '42');

// ✅
final storage = ref.read(keyValueStorageProvider);
await storage.write('last_id', '42');
```

Hive 初始化（`Hive.initFlutter` / `openBox`）只允许在 `lib/main.dart` / `lib/bootstrap.dart` 里。

### `avoid_direct_method_channel`

```dart
// ❌
const _ch = MethodChannel('foo');
_ch.invokeMethod('bar');

// ✅ 抽 channel client + provider
abstract class FooChannelClient {
  Future<String> bar();
}
class FooChannelClientImpl implements FooChannelClient { ... }
final fooChannelProvider = Provider<FooChannelClient>((_) => FooChannelClientImpl());
```

测试可换 `_FakeFooChannel`。

### `avoid_direct_dio`

```dart
// ❌
import 'package:dio/dio.dart';
final dio = Dio();
final res = await dio.get('/orders');

// ✅
final http = ref.read(httpClientProvider);
final orders = await http.get<List<Order>>(
  '/orders',
  decoder: (raw) => (raw as List).map(Order.fromJson).toList(),
);
```

详细见 `flutter-core-http-setup` skill。

### `avoid_direct_websocket`

```dart
// ❌
import 'package:web_socket_channel/web_socket_channel.dart';
final ch = WebSocketChannel.connect(Uri.parse('wss://...'));

// ✅
final ws = ref.watch(wsClientProvider(Uri.parse('wss://...')));
final sub = ws.subscribe<MyEvent>('topic', decoder: ...).listen(...);
```

详细见 `flutter-core-ws-setup` skill。

---

## B. plugin 自身 crash

### 最常见：`PrefixElement` cast

```
Unhandled exception:
type 'PrefixElementImpl' is not a subtype of type 'Fragment' in type cast
```

某条 lint 在解析 import prefix（`import 'package:foo/foo.dart' as f;` 里的 `f`）时把它当类型/库元素。修：

`package/flutter_core_lint/lib/src/lints/<rule>.dart` 里的 `_libraryUri` 等辅助方法加 guard：

```dart
String _libraryUri(Element? element) {
  if (element == null) return '';
  if (element is PrefixElement) return '';        // ← 加这行
  return element.librarySource?.uri.toString() ?? '';
}
```

### 检索哪条规则在 crash

`dart run custom_lint -v` 看堆栈，找最近一次 `package:flutter_core_lint/src/lints/<file>.dart` 的栈帧，那条规则就是嫌疑犯。

### plugin 改完不生效？

```bash
# 强刷 custom_lint 缓存
cd package/flutter_core/example
rm -rf .dart_tool/build .dart_tool/custom_lint
dart pub get
dart run custom_lint
```

VS Code / Cursor 还要 **Restart Analysis Server**（command palette）。

---

## C. plugin 加载失败

### `Could not find package flutter_core_lint`

业务工程 `pubspec.yaml` 没加 `dev_dependencies: flutter_core_lint`，或者 `path` 指错。

### `analysis_options.yaml` 漏配 plugin

```yaml
analyzer:
  plugins:
    - custom_lint
```

少这段 `dart run custom_lint` 能跑但 IDE 里看不到。

### 版本错位

`flutter_core_lint` 用 `custom_lint_builder: 0.7.x`，业务工程不要把 `custom_lint` 强行升到 1.x，会接口签名漂移。

---

## 实在改不动的逃生口

如果**单行**确实有合理理由要绕（比如临时调试代码、第三方库不可避免的 raw 调用），用 `// ignore: avoid_xxx`：

```dart
// ignore: avoid_direct_dio
final debugDio = Dio()..interceptors.add(...);
```

但**必须**：
1. 当行 ignore（不是 file-wide），不要 `// ignore_for_file:`。
2. 注释一行说为什么不能用 flutter_core 抽象。
3. PR 描述里点出来。

任何"我改不动 lint" → 优先看是不是漏了豁免（应该走 `flutter-core-add-lint` skill 的 § "必有豁免清单"）。
