import 'package:flutter_spine/flutter_spine.dart';

import 'market_models.dart';
import 'market_topic.dart';

/// Market 行情 WebSocket 业务网关。
///
/// 继承 [BaseWsGateway]，专门处理 Market 后端的价格、K线、交易记录订阅。
/// 内部通过 [WsClient.subscribe] 管理 topic 的生命周期（引用计数、重连重订阅等）。
///
/// ---
/// ## 使用示例
///
/// ```dart
/// final gw = ref.watch(marketGatewayProvider);
///
/// // 订阅实时价格
/// gw.subscribePrice('eip155:1', 'native').listen((p) => print('${p.price}'));
///
/// // 订阅 4H K线
/// gw.subscribeCandle('eip155:1', 'native', '4H').listen(print);
///
/// // 退订
/// gw.unsubscribePrice('eip155:1', 'native');
/// ```
///
/// ---
/// ## 设计要点
///
/// * Gateway 本身是**无状态**的——所有连接/订阅状态由 [WsClient] 管理；
/// * 同一 topic 被多个页面订阅时，[WsClient] 内部引用计数保证只发一次 subscribe 帧；
/// * 退订时引用计数归零才发 unsubscribe 帧；
/// * 重连后自动恢复所有活跃 topic 的订阅，Gateway 无需额外处理。
class MarketWsGateway extends BaseWsGateway {
  MarketWsGateway(super.ws);

  // ── Price ──────────────────────────────────────────────────────────────────

  Stream<PriceUpdate> subscribePrice(String chainCaip2, String tokenAddress) =>
      ws.subscribe(
        MarketTopic('price-info', chainCaip2, tokenAddress).encode(),
        decoder: PriceUpdate.fromRaw,
      );

  Future<void> unsubscribePrice(String chainCaip2, String tokenAddress) =>
      ws.unsubscribe(
        MarketTopic('price-info', chainCaip2, tokenAddress).encode(),
      );

  // ── Candle ─────────────────────────────────────────────────────────────────

  /// 订阅指定间隔的 K线。[interval] 如 `1H`、`4H`、`1D`。
  Stream<CandleUpdate> subscribeCandle(
    String chainCaip2,
    String tokenAddress,
    String interval,
  ) =>
      ws.subscribe(
        MarketTopic('candle$interval', chainCaip2, tokenAddress).encode(),
        decoder: CandleUpdate.fromRaw,
      );

  Future<void> unsubscribeCandle(
    String chainCaip2,
    String tokenAddress,
    String interval,
  ) =>
      ws.unsubscribe(
        MarketTopic('candle$interval', chainCaip2, tokenAddress).encode(),
      );

  // ── Trades ─────────────────────────────────────────────────────────────────

  Stream<TradeRecord> subscribeTrades(
          String chainCaip2, String tokenAddress) =>
      ws.subscribe(
        MarketTopic('trades', chainCaip2, tokenAddress).encode(),
        decoder: TradeRecord.fromRaw,
      );

  Future<void> unsubscribeTrades(String chainCaip2, String tokenAddress) =>
      ws.unsubscribe(
        MarketTopic('trades', chainCaip2, tokenAddress).encode(),
      );
}
