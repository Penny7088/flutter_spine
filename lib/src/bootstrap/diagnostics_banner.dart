import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap_audit.dart';

/// 一个 DEBUG-only 的"接入完成度"诊断面板。
///
/// release build 编译为 [SizedBox.shrink]——零运行时开销。
///
/// ```dart
/// // 在某个调试入口页面 / debug 抽屉里：
/// const FlutterSpineDiagnosticsBanner()
/// ```
///
/// 默认折叠成屏幕角落的小 chip，点开展开成完整的清单。
class FlutterSpineDiagnosticsBanner extends ConsumerStatefulWidget {
  const FlutterSpineDiagnosticsBanner({
    super.key,
    this.alignment = AlignmentDirectional.bottomStart,
    this.startCollapsed = true,
  });

  /// 浮动 chip 在屏幕的位置。默认左下角。
  final AlignmentGeometry alignment;

  /// 初始是否折叠成 chip。点击切换展开/折叠。
  final bool startCollapsed;

  @override
  ConsumerState<FlutterSpineDiagnosticsBanner> createState() =>
      _FlutterSpineDiagnosticsBannerState();
}

class _FlutterSpineDiagnosticsBannerState
    extends ConsumerState<FlutterSpineDiagnosticsBanner> {
  late bool _collapsed = widget.startCollapsed;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final audit = BootstrapAudit.collect(ref);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Align(
        alignment: widget.alignment,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: scheme.surfaceContainerHighest,
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _collapsed = !_collapsed),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: AlignmentDirectional.topStart,
                child: _collapsed
                    ? _Chip(audit: audit)
                    : _Expanded(audit: audit),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.audit});
  final BootstrapAudit audit;

  @override
  Widget build(BuildContext context) {
    final hasIssue = audit.entries.any((e) => e.status != AuditStatus.ok);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasIssue ? Icons.warning_amber_rounded : Icons.check_circle,
            size: 16,
            color: hasIssue ? Colors.amber : scheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            'flutter_spine',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Expanded extends StatelessWidget {
  const _Expanded({required this.audit});
  final BootstrapAudit audit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.developer_mode, size: 16),
                const SizedBox(width: 6),
                Text(
                  'flutter_spine diagnostics',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Icon(Icons.expand_less, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 8),
            for (final e in audit.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _AuditRow(entry: e),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});
  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.status) {
      AuditStatus.ok => Colors.green,
      AuditStatus.warn => Colors.amber.shade700,
      AuditStatus.skipped => Colors.grey,
    };
    final icon = switch (entry.status) {
      AuditStatus.ok => Icons.check_circle,
      AuditStatus.warn => Icons.warning_amber_rounded,
      AuditStatus.skipped => Icons.remove_circle_outline,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style.copyWith(fontSize: 11),
              children: [
                TextSpan(
                  text: '${entry.key}: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: entry.value),
                if (entry.detail != null)
                  TextSpan(
                    text: '\n${entry.detail}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
