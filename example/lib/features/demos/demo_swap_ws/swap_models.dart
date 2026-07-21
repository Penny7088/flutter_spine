import 'dart:convert';

/// Swap 业务模型。

class SwapQuote {
  final String pair;
  final double price;
  final double priceImpact;

  const SwapQuote({
    required this.pair,
    required this.price,
    required this.priceImpact,
  });

  static SwapQuote fromRaw(dynamic raw) {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    return SwapQuote(
      pair: m['pair'] as String? ?? '',
      price: (m['price'] as num?)?.toDouble() ?? 0.0,
      priceImpact: (m['priceImpact'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderStatusUpdate {
  final String orderId;
  final String status;
  final double filled;

  const OrderStatusUpdate({
    required this.orderId,
    required this.status,
    required this.filled,
  });

  static OrderStatusUpdate fromRaw(dynamic raw) {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    return OrderStatusUpdate(
      orderId: m['orderId'] as String? ?? '',
      status: m['status'] as String? ?? '',
      filled: (m['filled'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
