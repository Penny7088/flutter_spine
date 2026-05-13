import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_storage.dart';
import '../storage/storage_providers.dart';

const _kThemeModeKey = 'flutter_spine.theme_mode';

const _themeToKey = {
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
  ThemeMode.system: 'system',
};
const _keyToTheme = {
  'light': ThemeMode.light,
  'dark': ThemeMode.dark,
  'system': ThemeMode.system,
};

/// light / dark / system 三档主题切换，并持久化到 [KeyValueStorage]。
///
/// 用法：
/// ```dart
/// // 读取当前主题
/// final mode = ref.watch(themeModeProvider);
///
/// // 切换
/// await ref.read(themeModeProvider.notifier).set(ThemeMode.dark);
/// await ref.read(themeModeProvider.notifier).toggle(); // light <-> dark
/// ```
class ThemeModeNotifier extends Notifier<ThemeMode> {
  KeyValueStorage get _storage => ref.read(keyValueStorageProvider);

  @override
  ThemeMode build() {
    final saved = _storage.getString(_kThemeModeKey);
    return _keyToTheme[saved] ?? ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _storage.setString(_kThemeModeKey, _themeToKey[mode]!);
  }

  /// 在 light / dark 之间切换，system 视为 light。
  Future<void> toggle() async {
    await set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> reset() async => set(ThemeMode.system);
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
  name: 'themeModeProvider',
);
