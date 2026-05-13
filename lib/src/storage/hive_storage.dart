import 'dart:convert';

import 'package:hive/hive.dart';

import '../error/app_exception.dart';
import '../error/safe_call.dart';
import 'key_value_storage.dart';

/// 基于 Hive 的 [KeyValueStorage] 实现。
///
/// 业务包在 `main()` 中创建：
/// ```dart
/// await Hive.initFlutter();
/// final box = await Hive.openBox('wallet_prefs');
/// final storage = HiveStorage.fromBox(box);
/// ```
/// 然后通过 `keyValueStorageProvider.overrideWithValue(storage)` 注入。
class HiveStorage implements KeyValueStorage {
  HiveStorage._(this._box);

  factory HiveStorage.fromBox(Box<dynamic> box) => HiveStorage._(box);

  final Box<dynamic> _box;

  @override
  Future<void> setString(String key, String value) =>
      safeApiCall(() => _box.put(key, value));

  @override
  String? getString(String key) => _box.get(key) as String?;

  @override
  Future<void> setInt(String key, int value) =>
      safeApiCall(() => _box.put(key, value));

  @override
  int? getInt(String key) => _box.get(key) as int?;

  @override
  Future<void> setBool(String key, bool value) =>
      safeApiCall(() => _box.put(key, value));

  @override
  bool? getBool(String key) => _box.get(key) as bool?;

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) =>
      safeApiCall(() => _box.put(key, jsonEncode(value)));

  @override
  Map<String, dynamic>? getJson(String key) {
    final raw = _box.get(key) as String?;
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e, st) {
      throw CacheException(
        message: 'invalid json at key "$key"',
        raw: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<bool> contains(String key) async => _box.containsKey(key);

  @override
  Future<void> remove(String key) => safeApiCall(() => _box.delete(key));

  @override
  Future<void> clear() => safeApiCall(_box.clear);
}
