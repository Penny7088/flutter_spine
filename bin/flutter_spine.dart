import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_spine/src/cli/commands/async_page_command.dart';
import 'package:flutter_spine/src/cli/commands/bootstrap_command.dart';
import 'package:flutter_spine/src/cli/commands/effect_command.dart';
import 'package:flutter_spine/src/cli/commands/feature_command.dart';
import 'package:flutter_spine/src/cli/commands/form_command.dart';
import 'package:flutter_spine/src/cli/commands/page_command.dart';
import 'package:flutter_spine/src/cli/commands/repo_command.dart';
import 'package:flutter_spine/src/cli/commands/ws_gateway_command.dart';

/// flutter_spine 代码脚手架。
///
/// 用法（在业务工程根目录执行）：
///
/// ```bash
/// dart run flutter_spine:new <command> <name> [options]
///
/// dart run flutter_spine:new page user_profile --with-test
/// dart run flutter_spine:new async-page order_detail
/// dart run flutter_spine:new form login
/// dart run flutter_spine:new repo user
/// dart run flutter_spine:new effect refresh_balance
/// dart run flutter_spine:new feature wallet \
///     --variant=async --with-repo --with-route --with-test
/// dart run flutter_spine:new bootstrap
/// ```
Future<void> main(List<String> args) async {
  final runner = CommandRunner<int>(
    'flutter_spine:new',
    'flutter_spine 脚手架：一键生成 page / repo / feature / bootstrap 等模板。',
  )
    ..addCommand(PageCommand())
    ..addCommand(AsyncPageCommand())
    ..addCommand(FormCommand())
    ..addCommand(RepoCommand())
    ..addCommand(EffectCommand())
    ..addCommand(FeatureCommand())
    ..addCommand(BootstrapCommand())
    ..addCommand(WsGatewayCommand());

  try {
    final code = await runner.run(args);
    exit(code ?? 0);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  }
}
