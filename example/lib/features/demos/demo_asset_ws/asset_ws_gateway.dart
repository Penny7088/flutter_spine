import 'package:flutter_spine/flutter_spine.dart';

import 'asset_models.dart';
import 'asset_topic.dart';

/// Asset 资产 WebSocket 业务网关。
///
/// 处理钱包余额变动、质押状态等资产相关实时推送。
class AssetWsGateway extends BaseWsGateway {
  AssetWsGateway(super.ws);

  Stream<BalanceUpdate> subscribeBalance(
          String chainCaip2, String accountAddress) =>
      ws.subscribe(
        AssetTopic('balance', chainCaip2, accountAddress).encode(),
        decoder: BalanceUpdate.fromRaw,
      );

  Future<void> unsubscribeBalance(
          String chainCaip2, String accountAddress) =>
      ws.unsubscribe(
        AssetTopic('balance', chainCaip2, accountAddress).encode(),
      );

  Stream<StakingStatus> subscribeStaking(
          String chainCaip2, String accountAddress) =>
      ws.subscribe(
        AssetTopic('staking', chainCaip2, accountAddress).encode(),
        decoder: StakingStatus.fromRaw,
      );

  Future<void> unsubscribeStaking(
          String chainCaip2, String accountAddress) =>
      ws.unsubscribe(
        AssetTopic('staking', chainCaip2, accountAddress).encode(),
      );
}
