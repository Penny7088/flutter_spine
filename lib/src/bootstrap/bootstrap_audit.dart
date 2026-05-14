import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../flutter_spine.dart';

/// 接入完成度自检——在 [FlutterSpine.runApp] 启动时打印一份"已配置 / 未配置"
/// 清单到控制台（仅 `kDebugMode`），release 自动跳过。
///
/// 同样的数据也供 [FlutterSpineDiagnosticsBanner] widget 渲染。
class BootstrapAudit {
  const BootstrapAudit._(this.entries);

  final List<AuditEntry> entries;

  /// 从 [FlutterSpineConfig] 静态收集（启动时使用）。
  factory BootstrapAudit.fromConfig(FlutterSpineConfig c) => BootstrapAudit._([
        AuditEntry(
          'effectHandler',
          c.effectHandler.runtimeType.toString(),
          AuditStatus.ok,
          detail: c.effectHandler is MaterialDefaultEffectHandler
              ? 'default Material handler — pass custom toast/dialogs to override'
              : null,
        ),
        if (c.http != null)
          AuditEntry(
            'http',
            'baseUrl=${c.http!.baseUrl}',
            AuditStatus.ok,
            detail: '${c.http!.interceptors.length} interceptor(s)',
          )
        else
          const AuditEntry(
            'http',
            'not configured',
            AuditStatus.skipped,
            detail: 'httpClientProvider will throw on first read',
          ),
        if (c.ws != null)
          const AuditEntry('ws', 'custom builder', AuditStatus.ok)
        else
          const AuditEntry(
            'ws',
            'default builder',
            AuditStatus.warn,
            detail: 'no topicRouter; subscribe() will throw',
          ),
        if (c.storage != null)
          const AuditEntry(
            'storage',
            'configured (async initializer)',
            AuditStatus.ok,
          )
        else
          const AuditEntry(
            'storage',
            'not configured',
            AuditStatus.skipped,
            detail: 'keyValueStorageProvider will throw on first read',
          ),
        AuditEntry(
          'logger',
          c.logger == null
              ? 'PrettyAppLogger (default)'
              : c.logger.runtimeType.toString(),
          AuditStatus.ok,
        ),
        AuditEntry(
          'ErrorObserver',
          c.errorObserverEnabled ? 'enabled' : 'disabled',
          c.errorObserverEnabled ? AuditStatus.ok : AuditStatus.warn,
        ),
        AuditEntry(
          'LogObserver',
          c.logObserverInDebug ? 'debug-only' : 'disabled',
          AuditStatus.ok,
        ),
        AuditEntry(
          'extraObservers',
          '${c.extraObservers.length}',
          AuditStatus.ok,
        ),
        AuditEntry(
          'extraOverrides',
          '${c.extraOverrides.length}',
          AuditStatus.ok,
        ),
      ]);

  /// 运行时探针——通过 [WidgetRef] 实时读各 provider 状态。
  /// 比 [BootstrapAudit.fromConfig] 准确（能感知到业务在 `ProviderScope` 里
  /// 手动加的 override）。
  factory BootstrapAudit.collect(WidgetRef ref) {
    final entries = <AuditEntry>[];

    void probe<T>(
      String key,
      ProviderListenable<T> p, {
      String Function(T value)? render,
    }) {
      try {
        final value = ref.read(p);
        entries.add(AuditEntry(
          key,
          render != null ? render(value) : value.runtimeType.toString(),
          AuditStatus.ok,
        ));
      } catch (e) {
        entries.add(AuditEntry(
          key,
          'NOT CONFIGURED',
          AuditStatus.skipped,
          detail: e.toString().split('\n').first,
        ));
      }
    }

    probe('http', httpClientProvider);
    probe<WsClientConfig Function(Uri)>(
      'ws config builder',
      wsConfigBuilderProvider,
      render: (_) => 'configured',
    );
    probe('storage', keyValueStorageProvider);
    probe('logger', appLoggerProvider);
    return BootstrapAudit._(entries);
  }

  /// kDebugMode 下打印到控制台。
  static void printToConsole(FlutterSpineConfig config) {
    if (!kDebugMode) return;
    debugPrint(BootstrapAudit.fromConfig(config).render());
  }

  /// 渲染成 box 字符串（启动日志 + DiagnosticsBanner 共用）。
  String render() {
    final buf = StringBuffer();
    const line = '════════════════════════════════════════════════════════════';
    buf.writeln('╔$line');
    buf.writeln('║  flutter_spine bootstrap audit (DEBUG ONLY)');
    buf.writeln('╠$line');
    for (final e in entries) {
      final icon = switch (e.status) {
        AuditStatus.ok => '✅',
        AuditStatus.warn => '⚠️ ',
        AuditStatus.skipped => '⏭️ ',
      };
      final keyPad = e.key.padRight(18);
      buf.writeln('║  $icon $keyPad : ${e.value}');
      if (e.detail != null) {
        buf.writeln('║       └─ ${e.detail}');
      }
    }
    buf.writeln('╚$line');
    return buf.toString();
  }
}

/// 单条审计结果。
class AuditEntry {
  const AuditEntry(this.key, this.value, this.status, {this.detail});

  final String key;
  final String value;
  final AuditStatus status;
  final String? detail;
}

enum AuditStatus { ok, warn, skipped }
