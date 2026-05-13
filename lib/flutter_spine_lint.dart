import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'lints/avoid_direct_dio.dart';
import 'lints/avoid_direct_hive_access.dart';
import 'lints/avoid_direct_method_channel.dart';
import 'lints/avoid_direct_websocket.dart';
import 'lints/avoid_raw_scaffold.dart';
import 'lints/avoid_static_mutable_in_notifier.dart';
import 'lints/no_ui_in_viewmodel.dart';

/// 插件入口。由 `custom_lint` 通过 `pubspec.yaml` 中的
/// `dev_dependencies: flutter_spine` + analysis_options 里的
/// `plugins: custom_lint` 激活。
PluginBase createPlugin() => _FlutterSpineLintPlugin();

class _FlutterSpineLintPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
        AvoidRawScaffold(),
        NoUiInViewModel(),
        AvoidStaticMutableInNotifier(),
        AvoidDirectHiveAccess(),
        AvoidDirectMethodChannel(),
        AvoidDirectDio(),
        AvoidDirectWebSocket(),
      ];
}