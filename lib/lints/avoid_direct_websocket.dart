// ignore_for_file: deprecated_member_use
// 保留旧 element 模型，与 custom_lint_builder 0.7.x 一致。

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../flutter_spine.dart';
import 'avoid_direct_dio.dart';

/// 禁止业务代码直接使用 WebSocket 底层 API：
///
/// * `package:web_socket_channel/...` 的 `WebSocketChannel` / `IOWebSocketChannel` /
///   `HtmlWebSocketChannel` 等类直接 `new` 或调静态 `connect`；
/// * `dart:io` 的 `WebSocket.connect(...)`；
/// * `dart:html` 的 `WebSocket(...)`（Web 平台）。
///
/// **不**禁止：使用 `flutter_spine` 暴露的 `WsClient` / `DefaultWsClient` /
/// `WsClientConfig` / `WsTopicRouter` / `BaseWsGateway` /
/// `WsModuleRegistry` / `WsModuleConfig` 等已封装类型。
///
/// ## 为什么
///
/// * 业务代码绕过 `WsClient` 抽象 → 拿不到统一的状态机（[WsConnectionState]）；
/// * 没有内置心跳 / 指数退避重连 / topic 订阅 / token 自动刷新；
/// * 重连失败后无法接入 [EffectShowError] / Riverpod observers；
/// * 测试时无法注入 `_FakeWsChannel`，必须真连后端。
///
/// ## 改写指引
///
/// ```dart
/// // ❌ 业务代码
/// final ch = WebSocketChannel.connect(Uri.parse('wss://api/feed'));
/// ch.stream.listen(_onMsg);
///
/// // ✅ 三层架构（推荐）
/// // 1. 定义模块配置
/// final marketWsModule = WsModuleConfig(
///   uri: Uri.parse('wss://market-api.example/feed'),
///   topicRouter: WsTopicRouter.simple(channelKey: 'channel'),
/// );
///
/// // 2. 注册到 WsModuleRegistry
/// //    main.dart → FlutterSpineConfig.extraOverrides
/// WsModuleRegistry.build(modules: [marketWsModule], defaultConfig: ...)
///
/// // 3. 创建 Gateway
/// class MarketWsGateway extends BaseWsGateway {
///   MarketWsGateway(super.ws);
///   Stream<PriceUpdate> subscribePrice(String chain, String addr) =>
///       ws.subscribe('price-info|$chain|$addr', decoder: PriceUpdate.fromRaw);
/// }
///
/// // 4. 页面使用（StreamProvider.autoDispose 自动管理订阅生命周期）
/// final priceAsync = ref.watch(priceStreamProvider(('eip155:1', 'native')));
/// ```
///
/// ## 豁免
///
/// * `flutter_spine` 自身的 WebSocket 实现：`package/flutter_spine/lib/src/network/**`
/// * 应用启动 `/lib/main.dart` / `lib/bootstrap.dart`
/// * 测试 / fixture / example 路径
class AvoidDirectWebSocket extends DartLintRule {
  const AvoidDirectWebSocket() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_direct_websocket',
    problemMessage:
        '业务代码请使用 WsClient (flutter_spine)，不要直接连 WebSocket 底层 API。',
    correctionMessage:
        '通过 WsTopicRouter.simple() / WsModuleRegistry / BaseWsGateway 三层架构接入；'
        '订阅用 ws.subscribe<T>(topic, decoder: ...)；'
        '用 StreamProvider.autoDispose.family 管理订阅生命周期。',
  );

  static const _wsChannelUri = 'package:web_socket_channel/';
  static const _dartIoUri = 'dart:io';
  static const _dartHtmlUri = 'dart:html';

  static const _bannedTypes = {
    'WebSocket',
    'WebSocketChannel',
    'IOWebSocketChannel',
    'HtmlWebSocketChannel',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName.replaceAll('\\', '/');
    if (_isExempt(path)) return;

    context.registry.addInstanceCreationExpression((node) {
      final type = node.staticType;
      if (type == null) return;
      final element = type.element;
      if (element == null) return;
      if (!_bannedTypes.contains(element.name)) return;

      final uri = element.library?.source.uri.toString() ?? '';
      if (!_isBannedLib(uri)) return;

      reporter.atNode(node, _code);
    });

    // `WebSocketChannel.connect(...)` / `WebSocket.connect(...)` 等静态调用
    context.registry.addMethodInvocation((node) {
      final target = node.realTarget;
      if (target == null) return;

      final name = switch (target) {
        Identifier() => target.name,
        _ => null,
      };
      if (name == null || !_bannedTypes.contains(name)) return;

      final uri = _libraryUri(_resolveElement(target));
      if (!_isBannedLib(uri)) return;

      reporter.atNode(node, _code);
    });
  }

  Element? _resolveElement(dynamic node) {
    if (node is SimpleIdentifier) return node.staticElement;
    if (node is PrefixedIdentifier) return node.staticElement;
    return null;
  }

  /// 见 [AvoidDirectDio] 的同名方法 —— 处理 PrefixElement 的 cast 异常。
  String _libraryUri(Element? element) {
    if (element == null) return '';
    if (element is PrefixElement) return '';
    try {
      return element.librarySource?.uri.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  bool _isBannedLib(String uri) =>
      uri.startsWith(_wsChannelUri) ||
      uri == _dartIoUri ||
      uri == _dartHtmlUri;

  bool _isExempt(String path) {
    return path.contains('/package/flutter_spine/lib/src/network/') ||
        path.endsWith('/lib/main.dart') ||
        path.endsWith('/lib/bootstrap.dart') ||
        path.contains('/test/') ||
        path.contains('/test_fixtures/') ||
        path.contains('/example/');
  }
}