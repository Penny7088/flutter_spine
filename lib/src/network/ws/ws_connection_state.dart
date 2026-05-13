import 'package:flutter/foundation.dart';

import '../../error/app_exception.dart';

/// WebSocket 连接状态。
///
/// UI 侧用 `switch` 穷尽渲染指示器（断线提示 / 重连倒计时）。
sealed class WsConnectionState {
  const WsConnectionState();

  /// 是否处于"已连接"或"准备连接"——典型应用：禁用/启用发送按钮。
  bool get isAlive => this is WsConnected;
}

/// 还没调过 `connect()` 的初始态。
class WsIdle extends WsConnectionState {
  const WsIdle();

  @override
  String toString() => 'WsIdle';
}

/// 正在握手中（首次连接）。
class WsConnecting extends WsConnectionState {
  const WsConnecting();

  @override
  String toString() => 'WsConnecting';
}

/// 已连接，可以收发消息。
class WsConnected extends WsConnectionState {
  const WsConnected();

  @override
  String toString() => 'WsConnected';
}

/// 断线后正在等待重连（指数退避）。
@immutable
class WsReconnecting extends WsConnectionState {
  const WsReconnecting({required this.attempt, required this.nextDelay});

  /// 当前是第几次重连尝试（从 1 开始）。
  final int attempt;

  /// 距离下次实际发起 `connect` 还有多久。
  final Duration nextDelay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsReconnecting &&
          attempt == other.attempt &&
          nextDelay == other.nextDelay;

  @override
  int get hashCode => Object.hash(attempt, nextDelay);

  @override
  String toString() =>
      'WsReconnecting(attempt: $attempt, nextDelay: $nextDelay)';
}

/// 业务主动 disconnect / 服务端正常关闭。一般不再自动重连。
@immutable
class WsDisconnected extends WsConnectionState {
  const WsDisconnected({this.code, this.reason});

  /// WebSocket close code（1000 = normal）。
  final int? code;
  final String? reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsDisconnected && code == other.code && reason == other.reason;

  @override
  int get hashCode => Object.hash(code, reason);

  @override
  String toString() => 'WsDisconnected(code: $code, reason: $reason)';
}

/// 连接彻底失败：达到最大重连次数 / 不可恢复错误（如 401）。
@immutable
class WsFailed extends WsConnectionState {
  const WsFailed(this.error);

  final AppException error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WsFailed && error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'WsFailed($error)';
}
