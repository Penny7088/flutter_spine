/// Market 复合 topic 的编码/解码工具。
///
/// Market 后端订阅需要三个字段：channel + chainCaip2 + tokenContractAddress，
/// 但 [WsClient] 的 topic 是 String 类型。本类提供 pipe 分隔的编解码，
/// 在不改公共架构的前提下适配 Market 的多字段订阅参数。
///
/// ---
/// ## 编码规则
///
/// `channel|chainCaip2|tokenContractAddress`
///
/// | channel | 含义 |
/// |----------|------|
/// | `price-info` | 实时价格 |
/// | `candle1H` / `candle4H` / `candle1D` | K线 |
/// | `trades` | 交易记录 |
///
/// ### 示例
/// ```dart
/// MarketTopic('price-info', 'eip155:1', 'native').encode();
/// // 'price-info|eip155:1|native'
///
/// MarketTopic.decode('candle4H|eip155:1|0x123...');
/// // MarketTopic('candle4H', 'eip155:1', '0x123...')
/// ```
class MarketTopic {
  final String channel;
  final String chainCaip2;
  final String tokenAddress;

  const MarketTopic(this.channel, this.chainCaip2, this.tokenAddress);

  String encode() => '$channel|$chainCaip2|$tokenAddress';

  static MarketTopic decode(String topic) {
    final parts = topic.split('|');
    if (parts.length < 3) {
      throw FormatException('Invalid market topic: $topic');
    }
    return MarketTopic(parts[0], parts[1], parts[2]);
  }
}

/// Market WebSocket 服务端地址。
///
/// [marketGatewayProvider] 通过 [wsClientProvider] 按此 URI 创建共享连接，
/// [FlutterSpineConfig.extraOverrides] 中按此 URI 注入 Market 专用配置。
final marketWsUri = Uri.parse('wss://demo/ws/market');
