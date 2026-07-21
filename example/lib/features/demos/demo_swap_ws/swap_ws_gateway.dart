import 'package:flutter_spine/flutter_spine.dart';

import 'swap_models.dart';
import 'swap_topic.dart';

/// Swap 交易 WebSocket 业务网关。
///
/// 处理实时报价、订单状态等交易相关实时推送。
class SwapWsGateway extends BaseWsGateway {
  SwapWsGateway(super.ws);

  Stream<SwapQuote> subscribeQuote(String chainCaip2, String pair) =>
      ws.subscribe(
        SwapTopic('quote', chainCaip2, pair).encode(),
        decoder: SwapQuote.fromRaw,
      );

  Future<void> unsubscribeQuote(String chainCaip2, String pair) =>
      ws.unsubscribe(
        SwapTopic('quote', chainCaip2, pair).encode(),
      );

  Stream<OrderStatusUpdate> subscribeOrderStatus(
          String chainCaip2, String orderId) =>
      ws.subscribe(
        SwapTopic('order_status', chainCaip2, orderId).encode(),
        decoder: OrderStatusUpdate.fromRaw,
      );

  Future<void> unsubscribeOrderStatus(String chainCaip2, String orderId) =>
      ws.unsubscribe(
        SwapTopic('order_status', chainCaip2, orderId).encode(),
      );
}
