import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spine/flutter_spine.dart';

import 'market_topic.dart';
import 'market_ws_gateway.dart';

/// Market 业务 Gateway —— VM / Repository 层直接通过此 provider 获取。
///
/// ## 架构
///
/// 本 provider 依赖公共的 [wsClientProvider]，按 [marketWsUri] 获取共享的
/// [WsClient] 连接实例（同一 URI 复用同一个连接，由 `Provider.family` 保证）。
///
/// 连接配置（[WsClientConfig]）通过 [wsConfigBuilderProvider] 提供——
/// Market 专用配置（topicRouter / headersProvider / onAuthExpired 等）
/// 在 [FlutterSpineConfig.extraOverrides] 中统一注册，不放在本模块内。
///
/// ## 使用
///
/// ```dart
/// final gw = ref.watch(marketGatewayProvider);
///
/// // 订阅价格
/// gw.subscribePrice('eip155:1', 'native').listen(updatePrice);
///
/// // 订阅 K线
/// gw.subscribeCandle('eip155:1', 'native', '4H').listen(updateCandle);
/// ```
///
/// ## 生命周期
///
/// * [WsClient] 的创建和销毁由 [wsClientProvider] 管理
///   （`ref.onDispose(client.dispose)`）；
/// * [MarketWsGateway] 无状态，不需要 dispose；
/// * 订阅引用计数由 [WsClient] 内部维护，Gateway 只做透传。
final marketGatewayProvider = Provider<MarketWsGateway>((ref) {
  final ws = ref.watch(wsClientProvider(marketWsUri));
  return MarketWsGateway(ws);
});
