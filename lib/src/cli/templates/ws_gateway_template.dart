/// WebSocket Gateway 四件套模板。
///
/// 产出：
///   lib/features/{{name_snake}}/{{name_snake}}_topic.dart
///   lib/features/{{name_snake}}/{{name_snake}}_topic_router.dart
///   lib/features/{{name_snake}}/{{name_snake}}_ws_gateway.dart
///   lib/features/{{name_snake}}/{{name_snake}}_ws_providers.dart
///
/// 配套替换：
///   {{Name}}       — PascalCase
///   {{name}}       — camelCase
///   {{name_snake}} — snake_case
///   {{Title}}      — Title Case
library;

const wsGatewayTopicTemplate = r'''
/// {{Name}} WebSocket 复合 topic 的编码/解码工具。
///
/// 编码规则：`channel|chainCaip2|identifer`（按业务需要自行调整分隔符和字段数量）。
class {{Name}}Topic {
  final String channel;
  final String chainCaip2;
  final String identifier;

  const {{Name}}Topic(this.channel, this.chainCaip2, this.identifier);

  String encode() => '$channel|$chainCaip2|$identifier';

  static {{Name}}Topic decode(String topic) {
    final parts = topic.split('|');
    if (parts.length < 3) {
      throw FormatException('Invalid topic: $topic');
    }
    return {{Name}}Topic(parts[0], parts[1], parts[2]);
  }
}

/// {{Name}} WebSocket 服务端地址。
final {{name}}WsUri = Uri.parse('wss://{{name_snake}}-api.example/feed');
''';

const wsGatewayTopicRouterTemplate = r'''
import 'dart:convert';

import 'package:flutter_spine/flutter_spine.dart';

import '{{name_snake}}_topic.dart';

///
/// TODO：如果后端使用标准 pub/sub 协议（channel/type 字段和 topic 名一一对应），
/// 可直接改用 WsTopicRouter.simple()：
///
/// ```dart
/// final {{name}}TopicRouter = WsTopicRouter.simple(channelKey: 'channel');
/// ```
///
/// 如果使用复合 topic（类似 Market 的 price-info|eip155:1|native），
/// 保留下方的完整构造器并修改帧格式。

const {{name}}TopicRouter = WsTopicRouter(
  topicExtractor: _extractTopic,
  subscribeFrameBuilder: _buildSubscribeFrame,
  unsubscribeFrameBuilder: _buildUnsubscribeFrame,
);

String? _extractTopic(dynamic raw) {
  try {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    final channel = m['channel'] as String?;
    final chain = m['chainCaip2'] as String?;
    final id = m['identifier'] as String?;
    if (channel == null || chain == null || id == null) return null;
    return '$channel|$chain|$id';
  } catch (_) {
    return null;
  }
}

Object? _buildSubscribeFrame(String topic) {
  try {
    final t = {{Name}}Topic.decode(topic);
    return {
      'op': 'subscribe',
      'channel': t.channel,
      'chainCaip2': t.chainCaip2,
      'identifier': t.identifier,
    };
  } catch (_) {
    return null;
  }
}

Object? _buildUnsubscribeFrame(String topic) {
  try {
    final t = {{Name}}Topic.decode(topic);
    return {
      'op': 'unsubscribe',
      'channel': t.channel,
      'chainCaip2': t.chainCaip2,
      'identifier': t.identifier,
    };
  } catch (_) {
    return null;
  }
}
''';

const wsGatewayGatewayTemplate = r'''
import 'dart:convert';

import 'package:flutter_spine/flutter_spine.dart';

import '{{name_snake}}_topic.dart';

/// {{Title}} WebSocket 业务网关。
///
/// 继承 [BaseWsGateway]，处理 {{Title}} 后端的数据推送。
class {{Name}}WsGateway extends BaseWsGateway {
  {{Name}}WsGateway(super.ws);

  // TODO：替换为业务模型和 fromRaw 解码器

  Stream<Map<String, dynamic>> subscribeData(
          String chainCaip2, String identifier) =>
      ws.subscribe(
        {{Name}}Topic('data', chainCaip2, identifier).encode(),
        decoder: (raw) => jsonDecode(raw as String) as Map<String, dynamic>,
      );

  Future<void> unsubscribeData(String chainCaip2, String identifier) =>
      ws.unsubscribe(
        {{Name}}Topic('data', chainCaip2, identifier).encode(),
      );
}
''';

const wsGatewayProvidersTemplate = r'''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spine/flutter_spine.dart';

import '{{name_snake}}_topic.dart';
import '{{name_snake}}_ws_gateway.dart';

/// {{Title}} WebSocket 模块配置——注册到 [WsModuleRegistry] 中。
final {{name}}WsModule = WsModuleConfig(
  uri: {{name}}WsUri,
  topicRouter: {{name}}TopicRouter,
);

/// {{Title}} 业务 Gateway —— VM / Repository 层直接通过此 provider 获取。
final {{name}}GatewayProvider = Provider<{{Name}}WsGateway>((ref) {
  final ws = ref.watch(wsClientProvider({{name}}WsUri));
  return {{Name}}WsGateway(ws);
});
''';
