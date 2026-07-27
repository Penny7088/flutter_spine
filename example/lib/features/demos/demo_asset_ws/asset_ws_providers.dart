import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spine/flutter_spine.dart';

import 'asset_topic.dart';
import 'asset_topic_router.dart';
import 'asset_ws_gateway.dart';

/// Asset 业务 Gateway —— VM / Repository 层直接通过此 provider 获取。
final assetGatewayProvider = Provider<AssetWsGateway>((ref) {
  final ws = ref.watch(wsClientProvider(assetWsUri));
  return AssetWsGateway(ws);
});

/// Asset 模块自描述配置——注册到 [WsModuleRegistry]。
final assetWsModule = WsModuleConfig(
  uri: assetWsUri,
  topicRouter: assetTopicRouter,
);
