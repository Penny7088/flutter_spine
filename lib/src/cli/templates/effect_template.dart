/// 自定义 Effect。Page 级 `EffectListener.onEffect` 接收。
const effectTemplate = r'''
import 'package:flutter_spine/flutter_spine.dart';

/// 自定义 Effect 示例：业务自有副作用，不要塞进 [EffectShowToast] / [EffectShowDialog]。
///
/// 用法：
///
/// ```dart
/// // VM 里：
/// emit(const {{Name}}Effect(payload: 'hello'));
///
/// // Page 里：
/// AppPageScaffold(
///   onEffect: (e) {
///     if (e is {{Name}}Effect) {
///       // 业务处理
///     }
///   },
///   ...
/// )
/// ```
class {{Name}}Effect extends Effect {
  const {{Name}}Effect({required this.payload});

  final String payload;

  @override
  String toString() => '{{Name}}Effect(payload: $payload)';
}
''';
