import 'dart:convert';

import 'package:flutter_spine/flutter_spine.dart';

import 'swap_topic.dart';

const swapTopicRouter = WsTopicRouter(
  topicExtractor: _extractTopic,
  subscribeFrameBuilder: _buildSubscribeFrame,
  unsubscribeFrameBuilder: _buildUnsubscribeFrame,
);

String? _extractTopic(dynamic raw) {
  try {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    final channel = m['channel'] as String?;
    final chain = m['chainCaip2'] as String?;
    final pair = m['pair'] ?? m['orderId'] as String?;
    if (channel == null || chain == null || pair == null) return null;
    return '$channel|$chain|$pair';
  } catch (_) {
    return null;
  }
}

Object? _buildSubscribeFrame(String topic) {
  try {
    final t = SwapTopic.decode(topic);
    final frame = <String, dynamic>{
      'op': 'subscribe',
      'channel': t.channel,
      'chainCaip2': t.chainCaip2,
    };
    if (t.channel == 'quote') {
      frame['pair'] = t.pairOrOrderId;
    } else {
      frame['orderId'] = t.pairOrOrderId;
    }
    return frame;
  } catch (_) {
    return null;
  }
}

Object? _buildUnsubscribeFrame(String topic) {
  try {
    final t = SwapTopic.decode(topic);
    return {
      'op': 'unsubscribe',
      'channel': t.channel,
      'chainCaip2': t.chainCaip2,
    };
  } catch (_) {
    return null;
  }
}
