/// Swap WebSocket 服务端地址。
final swapWsUri = Uri.parse('wss://swap-api.example/feed');

/// Swap 复合 topic 的编码/解码工具。
///
/// 编码规则：`channel|chainCaip2|pairOrOrderId`
///
/// | channel | 含义 |
/// |----------|------|
/// | `quote` | 实时报价 |
/// | `order_status` | 订单状态 |
class SwapTopic {
  final String channel;
  final String chainCaip2;
  final String pairOrOrderId;

  const SwapTopic(this.channel, this.chainCaip2, this.pairOrOrderId);

  String encode() => '$channel|$chainCaip2|$pairOrOrderId';

  static SwapTopic decode(String topic) {
    final parts = topic.split('|');
    if (parts.length < 3) {
      throw FormatException('Invalid swap topic: $topic');
    }
    return SwapTopic(parts[0], parts[1], parts[2]);
  }
}
