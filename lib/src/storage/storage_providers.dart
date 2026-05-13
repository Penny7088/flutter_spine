import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'key_value_storage.dart';

/// KV 存储的 Riverpod 注入点。
///
/// 业务包**必须**在根 [ProviderScope] 的 `overrides` 中提供具体实现，否则运行时抛出。
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     keyValueStorageProvider.overrideWithValue(HiveStorage.fromBox(box)),
///   ],
///   child: const App(),
/// )
/// ```
final keyValueStorageProvider = Provider<KeyValueStorage>(
  (ref) => throw UnimplementedError(
    'keyValueStorageProvider must be overridden in the host app.\n'
    'Example:\n'
    '  ProviderScope(\n'
    '    overrides: [\n'
    '      keyValueStorageProvider.overrideWithValue(HiveStorage.fromBox(box)),\n'
    '    ],\n'
    '  )',
  ),
  name: 'keyValueStorageProvider',
);
