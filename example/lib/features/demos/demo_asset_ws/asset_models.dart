import 'dart:convert';

/// Asset 业务模型。

class BalanceUpdate {
  final String account;
  final String token;
  final double amount;

  const BalanceUpdate({
    required this.account,
    required this.token,
    required this.amount,
  });

  static BalanceUpdate fromRaw(dynamic raw) {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    return BalanceUpdate(
      account: m['accountAddress'] as String? ?? '',
      token: m['token'] as String? ?? '',
      amount: (m['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class StakingStatus {
  final String account;
  final double staked;
  final double rewards;

  const StakingStatus({
    required this.account,
    required this.staked,
    required this.rewards,
  });

  static StakingStatus fromRaw(dynamic raw) {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    return StakingStatus(
      account: m['accountAddress'] as String? ?? '',
      staked: (m['staked'] as num?)?.toDouble() ?? 0.0,
      rewards: (m['rewards'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
