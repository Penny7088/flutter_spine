import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'market_models.dart';
import 'market_ws_providers.dart';

/// ──────────── Riverpod StreamProvider 层 ────────────
///
/// 使用 `StreamProvider.autoDispose.family` 管理 WebSocket 订阅生命周期。
/// **调用方不需要手动 unsubscribe** — 当所有 listener 取消时，
/// `autoDispose` 自动触发 `ref.onDispose`，退订 topic。
///
/// ## 用法
///
/// ```dart
/// // 页面中直接 watch，无需手动管理 subscription
/// final price = ref.watch(priceStreamProvider(('eip155:1', 'native')));
/// price.when(
///   data: (update) => Text('${update.price}'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Error: $e'),
/// );
///
/// // 页面退出 → autoDispose 触发 → ref.onDispose 回调
/// // → unsubscribePrice → WsClient 引用计数归零 → 发 unsubscribe 帧
/// ```
///
/// ## 跨页面共享
///
/// 如果两个页面同时 watch 同一个 `(chain, addr)` 的 provider：
/// * `ref.onDispose` **不会**在第一个页面退出时触发（还有 listener）
/// * 第二个页面也退出后才触发 unsubscribe
/// * 这正是引用计数的正确语义

/// 实时价格 StreamProvider。
///
/// 参数 `(chainCaip2, tokenAddress)`，例如 `('eip155:1', 'native')`。
final priceStreamProvider = StreamProvider.autoDispose
    .family<PriceUpdate, (String chainCaip2, String tokenAddress)>(
  (ref, params) {
    final (chain, addr) = params;
    final gw = ref.watch(marketGatewayProvider);

    ref.onDispose(() => gw.unsubscribePrice(chain, addr));

    return gw.subscribePrice(chain, addr);
  },
);

/// K线 StreamProvider。
///
/// 参数 `(chainCaip2, tokenAddress, interval)`，interval 如 `1H`、`4H`、`1D`。
final candleStreamProvider = StreamProvider.autoDispose.family<CandleUpdate,
    (String chainCaip2, String tokenAddress, String interval)>(
  (ref, params) {
    final (chain, addr, interval) = params;
    final gw = ref.watch(marketGatewayProvider);

    ref.onDispose(() => gw.unsubscribeCandle(chain, addr, interval));

    return gw.subscribeCandle(chain, addr, interval);
  },
);

/// 交易记录 StreamProvider。
///
/// 参数 `(chainCaip2, tokenAddress)`。
final tradesStreamProvider = StreamProvider.autoDispose
    .family<TradeRecord, (String chainCaip2, String tokenAddress)>(
  (ref, params) {
    final (chain, addr) = params;
    final gw = ref.watch(marketGatewayProvider);

    ref.onDispose(() => gw.unsubscribeTrades(chain, addr));

    return gw.subscribeTrades(chain, addr);
  },
);
