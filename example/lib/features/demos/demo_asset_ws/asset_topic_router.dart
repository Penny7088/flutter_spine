import 'dart:convert';

import 'package:flutter_spine/flutter_spine.dart';

import 'asset_topic.dart';

const assetTopicRouter = WsTopicRouter(
  topicExtractor: _extractTopic,
  subscribeFrameBuilder: _buildSubscribeFrame,
  unsubscribeFrameBuilder: _buildUnsubscribeFrame,
);

String? _extractTopic(dynamic raw) {
  try {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    final channel = m['channel'] as String?;
    final chain = m['chainCaip2'] as String?;
    final account = m['accountAddress'] as String?;
    if (channel == null || chain == null || account == null) return null;
    return '$channel|$chain|$account';
  } catch (_) {
    return null;
  }
}

Object? _buildSubscribeFrame(String topic) {
  try {
    final t = AssetTopic.decode(topic);
    return {
      'op': 'subscribe',
      'channel': t.channel,
      'chainCaip2': t.chainCaip2,
      'accountAddress': t.accountAddress,
    };
  } catch (_) {
    return null;
  }
}

Object? _buildUnsubscribeFrame(String topic) {
  try {
    final t = AssetTopic.decode(topic);
    return {
      'op': 'unsubscribe',
      'channel': t.channel,
      'chainCaip2': t.chainCaip2,
      'accountAddress': t.accountAddress,
    };
  } catch (_) {
    return null;
  }
}
