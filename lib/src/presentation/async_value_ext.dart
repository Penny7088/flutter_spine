import 'package:flutter_riverpod/flutter_riverpod.dart';

extension AsyncValueX<T> on AsyncValue<T> {
  /// 有数据返回 data，否则返回 [fallback]。
  /// 比 `value ?? default` 更安全：[value] 在 error 分支也可能为 null。
  T dataOr(T fallback) => hasValue ? value as T : fallback;

  /// 正在刷新（已有旧数据，但正在 refetch）。
  bool get isRefreshing => isLoading && hasValue;

  /// 从已加载数据派生一个值；未加载时返回 [fallback]。
  R pick<R>(R Function(T data) map, {required R fallback}) =>
      hasValue ? map(value as T) : fallback;
}
