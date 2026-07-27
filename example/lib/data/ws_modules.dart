import 'package:flutter/foundation.dart';
import 'package:flutter_spine/flutter_spine.dart';

import '../features/demos/demo_asset_ws/asset_ws_providers.dart';
import '../features/demos/demo_market_ws/market_ws_providers.dart';
import '../features/demos/demo_swap_ws/swap_ws_providers.dart';

/// 各业务模块的 WebSocket 配置列表。
final wsModules = [marketWsModule, assetWsModule, swapWsModule];

/// 当前全局 token——[onAuthExpired] 刷新后写回这里，
/// [queryParamsProvider] 每次 connect/重连时读取。
String _currentToken =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6Indlbi1jb3JlLTIwMjYiLCJ0eXAiOiJKV1QifQ.'
    'eyJ1c2VySWQiOiJ1c2VyXzAxa3k1NDg3cHpmczA4ZTFlNWcxdnhoZHZyIiwiZGV2aWNlSWQiOiJkdmljXzAxa3k1NDg3cTJmczA4ZWhnNzViMjRqcXFiIiwiaXNHdWVzdCI6dHJ1ZSwibG9naW5UeXBlIjoiZ3Vlc3QiLCJzaWQiOiI2LVJBMjRZRjJSS0NnWWJRcDVZeU1oOHNWR3RuWEhSNDg0TVF6bVROWEFzIiwiZXhwIjoxNzg1MTQzOTcwLCJpYXQiOjE3ODUxNDAzNzAsImlzcyI6Indlbi13YWxsZXQiLCJuYmYiOjE3ODUxNDAzNzAsInN1YiI6InVzZXJfMDFreTU0ODdwemZzMDhlMWU1ZzF2eGhkdnIifQ.'
    'WIkLxkUWauAeQBmH1JsL8BlnVvFvpPbfs-jBTOPySu56Nk9MI815biqsaLeYFKNbA4pOBFtnL460EUORpNAm7-yTlDKmE9yZlqJORNuuz85Ora8tOe3qSNwp8LYDVkohXrsUWiNlApasyG8jMI9ev5kI_TIT9XhZBKITJWbEAA7sytUCB17rNq3XIhRJDJ25sHCj86-BAb9Wc0DPM1Qf7PyDmuVKRPajP7ibGXHRtOVH4qzrgYQwpRf64pmbG1MG22JTeN2uB8PDLSNI3zcF7vC6SbNbn9VmZx3NzknRQRH9BdluRPdAeKEesvBI8I9b2vaMPBLDrfyY6hJtCv7bjw';

/// 共享的 WebSocket 默认配置（token / 心跳 / 重连）。
///
/// 全局 token 由 [_currentToken] 变量托管：[queryParamsProvider] 读取，
/// [onAuthExpired] 刷新后写回。所有模块共享同一份 token。
WsClientConfig sharedWsConfig(Uri uri) {
  return WsClientConfig(
    url: uri,
    heartbeatPayload: {'type': 'ping'},
    queryParamsProvider: () => {'token': _currentToken},
    isAuthCloseCode: (code) => code == 4001,
      maxReconnectAttempts:3,
    isConnectAuthError: (error) {
      final msg = error.toString();
      return msg.contains('401') || msg.contains('403');
    },
    onAuthExpired: () async {
      debugPrint('[onAuthExpired] ===');
      // 真实业务中在这里调用 authRepo.refresh()，拿到新 token 写回 _currentToken
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _currentToken = 'refreshed-token-${DateTime.now().millisecondsSinceEpoch}';
      return _currentToken;
    },
  );
}
