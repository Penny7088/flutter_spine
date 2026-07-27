import 'package:flutter_spine/flutter_spine.dart';

import '../features/demos/demo_asset_ws/asset_ws_providers.dart';
import '../features/demos/demo_market_ws/market_ws_providers.dart';
import '../features/demos/demo_swap_ws/swap_ws_providers.dart';

/// 各业务模块的 WebSocket 配置列表。
///
/// 每个模块在其 providers 文件中定义了自己的 [WsModuleConfig]。
/// 新增模块只需在此列表中加一项引用即可。
final wsModules = [marketWsModule, assetWsModule, swapWsModule];

/// 共享的 WebSocket 默认配置（auth / 心跳 / 重连）。
WsClientConfig sharedWsConfig(Uri uri) {
  return WsClientConfig(
    url: uri,
    heartbeatPayload: {'op': 'ping'},
    headersProvider: () => {'Authorization': 'Bearer demo-token-12345'},
    isAuthCloseCode: (code) => code == 4001,
    onAuthExpired: () async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return 'new-token-refreshed';
    },
  );
}
