import 'ws_client.dart';
import 'ws_connection_state.dart';

/// WebSocket 业务网关基类。
///
/// ## 职责
///
/// `BaseWsGateway` 负责**透传** [WsClient] 的连接生命周期和状态查询能力，
/// 将底层的 WebSocket 连接管理与上层的业务逻辑解耦。
///
/// * **不做** topic 编码 / 消息解码 —— 这些由子类在各自的
///   [WsClient.subscribe] 调用中通过 `decoder` 参数自行处理；
/// * **不做** subscribe / unsubscribe 封装 ——
///   [WsClient.subscribe] 已是泛型且足够灵活，重复封装无意义；
/// * **不做** [WsClient] 的创建和销毁 —— 创建由 Provider 层负责，
///   销毁由 `wsClientProvider` 的 `ref.onDispose` 管理。
///
/// ## 使用方式
///
/// 每个业务模块（Market、Asset、Swap 等）继承本类，实现自己的 Gateway：
///
/// ```dart
/// class MarketWsGateway extends BaseWsGateway {
///   MarketWsGateway(super.ws);
///
///   Stream<PriceUpdate> subscribePrice(String chain, String addr) =>
///       ws.subscribe(
///         'price-info|$chain|$addr',
///         decoder: PriceUpdate.fromRaw,
///       );
///
///   Future<void> unsubscribePrice(String chain, String addr) =>
///       ws.unsubscribe('price-info|$chain|$addr');
/// }
/// ```
///
/// ## 与 Provider 集成
///
/// Gateway 实例通过 Riverpod provider 创建，按业务域名注入对应的 [WsClient]：
///
/// ```dart
/// final marketGatewayProvider = Provider<MarketWsGateway>((ref) {
///   final ws = ref.watch(
///     wsClientProvider(Uri.parse('wss://market.example/feed')),
///   );
///   return MarketWsGateway(ws);
/// });
/// ```
///
/// ## 架构全景
///
/// ```
/// flutter_spine (核心)          各业务模块 (外部实现)
/// ──────────────────────       ────────────────────
/// BaseWsGateway ◄────────────── MarketWsGateway
///   │                              │
/// WsClient ◄───────────────────────┤
///   │                              │
/// wsClientProvider(Uri) ◄──────────┼── marketGatewayProvider
///                                  │
///                              (AssetWsGateway ...)
/// ```
///
/// ## 注意事项
///
/// * 子类**不应**持有 [WsClient] 之外的有状态资源。
///   Gateway 是无状态的 —— 所有状态由 [WsClient] 管理；
/// * 引用计数由 [WsClient] 内部维护。
///   同一 topic 被多个页面同时订阅时，[WsClient] 保证只发一次 subscribe 帧，
///   退订时引用计数归零才发 unsubscribe 帧。Gateway 不需要自己再做一层计数；
/// * [WsClient.dispose] 不在 Gateway 中调用 ——
///   由 Provider 层的 `ref.onDispose` 负责，避免提前断开其他页面的连接。
abstract class BaseWsGateway {
  /// 底层 WebSocket 客户端实例。
  ///
  /// 子类通过此字段调用 [WsClient.subscribe]、[WsClient.unsubscribe]、
  /// [WsClient.send] 等方法。业务模型中需要发自定义帧时也可直接使用。
  final WsClient ws;

  /// 创建 Gateway 实例，绑定指定的 [WsClient]。
  ///
  /// [ws] 通常由 Provider 层通过 `wsClientProvider` 获取后注入。
  const BaseWsGateway(this.ws);

  /// WebSocket 当前连接状态的快照。
  ///
  /// 用于 UI 层同步判断连接状态，例如控制"发送"按钮的启用/禁用。
  WsConnectionState get currentState => ws.currentState;

  /// 连接状态变化流（broadcast）。
  ///
  /// UI 层可通过监听此流渲染连接指示器（断线提示、重连倒计时等）。
  /// 典型用法：`gateway.connectionState.listen(_updateIndicator);`
  Stream<WsConnectionState> get connectionState => ws.connectionState;

  /// 启动 WebSocket 连接。
  ///
  /// 多次调用幂等：已连接或连接中时 no-op。
  /// 通常由 UI 在首次进入需要 WS 数据的页面时调用。
  Future<void> connect() => ws.connect();

  /// 主动断开连接。
  ///
  /// 调用后状态进入 [WsDisconnected]，**不**触发自动重连。
  /// [code] 和 [reason] 遵循 WebSocket close 语义（1000 = normal closure）。
  Future<void> disconnect({int? code, String? reason}) =>
      ws.disconnect(code: code, reason: reason);

  /// 查询指定 [topic] 当前是否有活跃订阅（引用计数 > 0）。
  ///
  /// 用于 UI 层判断是否已订阅某个业务频道，例如高亮"已关注"按钮。
  bool isSubscribed(String topic) => ws.isSubscribed(topic);

  /// 当前已订阅的 topic 集合（只读快照）。
  ///
  /// 可用于调试或日志记录，不建议在业务逻辑中依赖此集合的顺序。
  Set<String> get subscribedTopics => ws.subscribedTopics;
}
