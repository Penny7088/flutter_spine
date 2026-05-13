import 'package:flutter/material.dart';
import 'package:flutter_spine/flutter_spine.dart';

import '../../data/task.dart';

/// 半屏选择器：用 [AppBottomSheetScaffold] 装内容，结果通过 `Navigator.pop`
/// 返回给调用方。
///
/// 这里**不**用 `emit(EffectPop(result))`——sheet 是 UI 即时反馈，
/// 没有 VM 中介；effect 适合"VM 决定关页面"那种异步链路。
class StatusPickerSheet extends StatelessWidget {
  const StatusPickerSheet({super.key, required this.current});

  final TaskStatus current;

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetScaffold(
      title: 'Change status',
      showCloseButton: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in TaskStatus.values)
            RadioListTile<TaskStatus>(
              value: s,
              groupValue: current,
              onChanged: (v) => Navigator.of(context).pop(v),
              title: Text(s.label),
            ),
        ],
      ),
    );
  }
}
