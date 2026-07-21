/// Asset WebSocket 服务端地址。
final assetWsUri = Uri.parse('wss://asset-api.example/feed');

/// Asset 复合 topic 的编码/解码工具。
///
/// 编码规则：`channel|chainCaip2|accountAddress`
///
/// | channel | 含义 |
/// |----------|------|
/// | `balance` | 资产余额 |
/// | `staking` | 质押状态 |
class AssetTopic {
  final String channel;
  final String chainCaip2;
  final String accountAddress;

  const AssetTopic(this.channel, this.chainCaip2, this.accountAddress);

  String encode() => '$channel|$chainCaip2|$accountAddress';

  static AssetTopic decode(String topic) {
    final parts = topic.split('|');
    if (parts.length < 3) {
      throw FormatException('Invalid asset topic: $topic');
    }
    return AssetTopic(parts[0], parts[1], parts[2]);
  }
}
