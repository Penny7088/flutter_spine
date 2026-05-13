---
name: flutter-core-ws-setup
description: Configure WebSocket client and topic subscriptions through flutter_core's WsClient / WsClientConfig / WsTopicRouter. Use when the user asks about WebSocket, real-time push, topic subscribe/unsubscribe, reconnect, or heartbeat.
---

# WebSocket 接入

## 业务侧 5 行接入

`main.dart`：

```dart
FlutterCore.runApp(
  config: FlutterCoreConfig(
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
  ),
  app: ...,
);
```

业务 VM 用：

```dart
class FeedVm extends ViewModelNotifier<FeedState> {
  StreamSubscription? _sub;

  @override FeedState build() {
    final ws = ref.watch(wsClientProvider(Uri.parse('wss://api.example.com/feed')));
    _sub = ws.subscribe<FeedEvent>(
      'feed',
      decoder: (raw) => FeedEvent.fromJson(jsonDecode(raw as String)),
    ).listen((e) => update((s) => s.copyWith(events: [...s.events, e])));

    ref.onDispose(() async {
      await _sub?.cancel();
      await ws.unsubscribe('feed');                    // 引用计数 -1
    });
    return const FeedState();
  }
}
```

进页面自动 connect → 订阅 → 收推送；出页面自动 unsubscribe；网络抖断后自动重连 + 重订阅。

## 决策表

| 场景 | 怎么做 |
|---|---|
| 一个 app 多个 WS 节点 | `wsClientProvider(uri)` 是 family，每个 uri 独立实例 |
| 同 topic 多个组件订阅 | 直接 `subscribe` 同名 topic，引用计数自动合并 → 同一 broadcast stream |
| 不需要 topic 路由（直接听全量） | 不传 `topicRouter`，业务用 `ws.messages.listen(...)` |
| 子协议（binance/coinbase 风格） | `WsClientConfig.protocols: ['v2.json']` |
| WS 升级握手要带 token | `headers: {'Authorization': 'Bearer ...'}`（部分平台支持） |
| 关心连接状态（红绿点） | `ref.watch(provider).connectionState.listen((s) => ...)` 或在 widget 里 `StreamBuilder` |
| 关心重连进度 | state 是 `WsReconnecting(attempt: 3, nextDelay: Duration(seconds: 4))` |
| 关闭心跳 | `heartbeatInterval: Duration.zero` |
| 自定义心跳 payload | `heartbeatPayload: {'op': 'ping', 'ts': ...}` 或 `''` |

## subscribe vs messages

| | `subscribe<T>(topic)` | `messages` |
|---|---|---|
| 自动 connect | ✅（`autoConnect: true`） | ❌（手动 `await ws.connect()`） |
| topic 过滤 | ✅（按 router） | ❌（全量） |
| decoder 类型化 | ✅ | ❌（业务自己 jsonDecode） |
| 重连重订阅 | ✅（自动 replay subscribe 帧） | ❌ |
| 共享 stream / 引用计数 | ✅ | — |
| **业务推荐** | ✅ | 仅调试 / 全量场景 |

## WsTopicRouter 三种部署

### 1. 纯客户端 filter（后端不分订阅，按消息字段路由）

```dart
WsTopicRouter(
  topicExtractor: (raw) =>
    (jsonDecode(raw as String) as Map)['type'] as String?,
)
```

`subscribeFrameBuilder` / `unsubscribeFrameBuilder` 都不传 → 不发协议帧，纯客户端 demux。

### 2. 协议级订阅（典型 pub/sub）

```dart
WsTopicRouter(
  topicExtractor: (raw) =>
    (jsonDecode(raw as String) as Map)['channel'] as String?,
  subscribeFrameBuilder: (t) => {'op': 'subscribe', 'channel': t},
  unsubscribeFrameBuilder: (t) => {'op': 'unsubscribe', 'channel': t},
)
```

第一次订阅某 topic 时发 subscribe 帧；最后一个订阅取消时发 unsubscribe 帧；中间多次订阅只 +/- 引用计数。

### 3. 多字段 topic（业务自定义命名）

```dart
topicExtractor: (raw) {
  final m = jsonDecode(raw as String) as Map;
  return '${m['type']}:${m['symbol']}';                  // 'kline:BTCUSDT'
},
subscribeFrameBuilder: (t) {
  final parts = t.split(':');
  return {'op': 'subscribe', 'type': parts[0], 'symbol': parts[1]};
},
```

## 不要做的事

- ❌ 不要 `WebSocketChannel.connect(...)` —— `avoid_direct_websocket` lint 会拦。
- ❌ 不要在业务里 `await ws.connect()` 然后忘 `disconnect()` —— autoDispose provider 会自动 dispose，但你**手动 connect** 后也得**手动 disconnect**。**优先**走 `subscribe()` 让连接生命周期自动化。
- ❌ 不要在 `subscribe` 之后又监听 `messages` —— 会双消费，业务以为消息丢了。
- ❌ 不要假设 `subscribe` 立即收到第一条 —— 可能正在重连，订阅帧会暂存等连上后发。
- ❌ 不要 `topicExtractor` 抛异常 —— 单条坏消息会导致整流断（其实底层 catch 住了，但日志会刷屏）。

## 验证

```bash
cd package/flutter_core
flutter test test/network/ws/
```

`default_ws_client_test.dart` 用 fake `WsChannelFactory`，~80 行验证完整状态机 + 重连退避 + 心跳 + 订阅路由。改任何 `default_ws_client.dart` 必须跑这个测试。
