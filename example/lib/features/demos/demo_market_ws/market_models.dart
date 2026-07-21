import 'dart:convert';

/// 简化的行情业务模型，仅用于 Demo 展示。
///
/// 真实业务中这些模型会从后端 JSON 映射生成（freezed / json_serializable）。

class PriceUpdate {
  final String symbol;
  final double price;
  final double change24h;

  const PriceUpdate({
    required this.symbol,
    required this.price,
    required this.change24h,
  });

  static PriceUpdate fromRaw(dynamic raw) {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    return PriceUpdate(
      symbol: m['symbol'] as String? ?? '',
      price: (m['price'] as num?)?.toDouble() ?? 0.0,
      change24h: (m['change24h'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() => 'PriceUpdate($symbol: $price, 24h: $change24h%)';
}

class CandleUpdate {
  final String symbol;
  final String interval;
  final double open;
  final double high;
  final double low;
  final double close;

  const CandleUpdate({
    required this.symbol,
    required this.interval,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  static CandleUpdate fromRaw(dynamic raw) {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    return CandleUpdate(
      symbol: m['symbol'] as String? ?? '',
      interval: m['interval'] as String? ?? '',
      open: (m['open'] as num?)?.toDouble() ?? 0.0,
      high: (m['high'] as num?)?.toDouble() ?? 0.0,
      low: (m['low'] as num?)?.toDouble() ?? 0.0,
      close: (m['close'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() => 'CandleUpdate($symbol $interval: O$open H$high L$low C$close)';
}

class TradeRecord {
  final String symbol;
  final double price;
  final double amount;
  final String side; // buy / sell

  const TradeRecord({
    required this.symbol,
    required this.price,
    required this.amount,
    required this.side,
  });

  static TradeRecord fromRaw(dynamic raw) {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    return TradeRecord(
      symbol: m['symbol'] as String? ?? '',
      price: (m['price'] as num?)?.toDouble() ?? 0.0,
      amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
      side: m['side'] as String? ?? '',
    );
  }

  @override
  String toString() => 'TradeRecord($symbol: $side $amount @ $price)';
}
