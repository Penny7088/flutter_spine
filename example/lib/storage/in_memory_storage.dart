import 'package:flutter_spine/flutter_spine.dart';

class InMemoryStorage extends KeyValueStorage {
  final _data = <String, dynamic>{};

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<void> setString(String key, String value) async {
    _data[key] = value;
  }

  @override
  int? getInt(String key) => _data[key] as int?;

  @override
  Future<void> setInt(String key, int value) async {
    _data[key] = value;
  }

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async {
    _data[key] = value;
  }

  @override
  Map<String, dynamic>? getJson(String key) {
    final raw = _data[key];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) return null;
    return null;
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async {
    _data[key] = value;
  }

  @override
  Future<bool> contains(String key) async => _data.containsKey(key);

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }
}
