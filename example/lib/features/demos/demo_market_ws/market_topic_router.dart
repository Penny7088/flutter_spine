import 'dart:convert';

import 'package:flutter_spine/flutter_spine.dart';

import 'market_topic.dart';

/// Market 后端的 WebSocket 协议适配器。
///
/// 三个职责：
/// 1. **topic 提取**：从后端推送的 JSON 消息中还原 `channel|chainCaip2|tokenAddress`
/// 2. **subscribe 帧构造**：把 topic string 转成 Market 后端的订阅帧
/// 3. **unsubscribe 帧构造**：把 topic string 转成 Market 后端的退订帧
///
/// 用于 [WsClientConfig.topicRouter] 字段。
const marketTopicRouter = WsTopicRouter(
  topicExtractor: _extractTopic,
  subscribeFrameBuilder: _buildSubscribeFrame,
  unsubscribeFrameBuilder: _buildUnsubscribeFrame,
);

String? _extractTopic(dynamic raw) {
  try {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    final channel = m['channel'] as String?;
    final chain = m['chainCaip2'] as String?;
    final addr = m['tokenContractAddress'] as String?;
    if (channel == null || chain == null || addr == null) return null;
    return '$channel|$chain|$addr';
  } catch (_) {
    return null;
  }
}

Object? _buildSubscribeFrame(String topic) {
  try {
    final t = MarketTopic.decode(topic);
    return {
      'op': 'subscribe',
      'channel': t.channel,
      'chainCaip2': t.chainCaip2,
      'tokenContractAddress': t.tokenAddress,
    };
  } catch (_) {
    return null;
  }
}

Object? _buildUnsubscribeFrame(String topic) {
  try {
    final t = MarketTopic.decode(topic);
    return {
      'op': 'unsubscribe',
      'channel': t.channel,
      'chainCaip2': t.chainCaip2,
      'tokenContractAddress': t.tokenAddress,
    };
  } catch (_) {
    return null;
  }
}
