import 'package:path/path.dart' as p;

import '../templates/ws_gateway_template.dart';
import 'base_command.dart';

class WsGatewayCommand extends FlutterSpineCommand {
  @override
  String get name => 'ws-gateway';

  @override
  String get description =>
      '生成 WebSocket Gateway 四件套：topic / topic_router / ws_gateway / providers。';

  @override
  String get invocation =>
      'flutter_spine:new ws-gateway <name> [--path] [--with-test]';

  @override
  Future<int> run() async {
    final dir = outputDir;
    final snake = naming.snake;

    writer.writeFile(
      p.join(dir, '${snake}_topic.dart'),
      render(wsGatewayTopicTemplate),
    );
    writer.writeFile(
      p.join(dir, '${snake}_topic_router.dart'),
      render(wsGatewayTopicRouterTemplate),
    );
    writer.writeFile(
      p.join(dir, '${snake}_ws_gateway.dart'),
      render(wsGatewayGatewayTemplate),
    );
    writer.writeFile(
      p.join(dir, '${snake}_ws_providers.dart'),
      render(wsGatewayProvidersTemplate),
    );

    writer.summary();
    return 0;
  }
}
