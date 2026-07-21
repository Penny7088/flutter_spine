import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spine/flutter_spine.dart';

import 'swap_topic.dart';
import 'swap_ws_gateway.dart';

/// Swap 业务 Gateway —— VM / Repository 层直接通过此 provider 获取。
final swapGatewayProvider = Provider<SwapWsGateway>((ref) {
  final ws = ref.watch(wsClientProvider(swapWsUri));
  return SwapWsGateway(ws);
});
