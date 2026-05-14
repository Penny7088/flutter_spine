import '../../flutter_spine.dart';

/// KV 存储抽象接口。
///
/// 具体实现：[HiveStorage]（已提供）。
/// 也可接入 SharedPreferences、MMKV 等，只需实现此接口。
abstract class KeyValueStorage {
  Future<void> setString(String key, String value);
  String? getString(String key);

  Future<void> setInt(String key, int value);
  int? getInt(String key);

  Future<void> setBool(String key, bool value);
  bool? getBool(String key);

  /// 以 JSON 字符串形式存储 Map。
  Future<void> setJson(String key, Map<String, dynamic> value);

  /// 读取 JSON Map，key 不存在时返回 null。
  Map<String, dynamic>? getJson(String key);

  Future<bool> contains(String key);
  Future<void> remove(String key);
  Future<void> clear();
}
