extension IterableX<T> on Iterable<T> {
  /// 返回第一个满足条件的元素，不存在时返回 null（不抛异常）。
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }

  /// 安全取第 [index] 个元素，越界时返回 null。
  T? elementAtOrNull(int index) {
    if (index < 0) return null;
    var i = 0;
    for (final e in this) {
      if (i == index) return e;
      i++;
    }
    return null;
  }

  /// 将 Iterable 转成 `Map<K, T>`。
  Map<K, T> toMapBy<K>(K Function(T) key) =>
      {for (final e in this) key(e): e};

  /// 分组：`[1,2,3,4].groupBy((e) => e % 2)` → `{1: [1,3], 0: [2,4]}`
  Map<K, List<T>> groupBy<K>(K Function(T) key) {
    final map = <K, List<T>>{};
    for (final e in this) {
      map.putIfAbsent(key(e), () => []).add(e);
    }
    return map;
  }
}
