import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dio_http_client.dart';
import 'http_client.dart';

/// 业务 host 必须在 `ProviderScope` 里 override 此 provider，提供本 app 的
/// HTTP 配置（baseUrl / 超时 / interceptor 链）。
///
/// ## 用法
///
/// ```dart
/// runApp(ProviderScope(
///   overrides: [
///     httpConfigProvider.overrideWithValue(
///       DioHttpConfig(
///         baseUrl: 'https://api.example.com',
///         interceptors: [
///           AuthTokenInterceptor(tokenProvider: () => box.read('token')),
///           HttpLoggingInterceptor(logger: PrettyAppLogger(), logRequestBody: kDebugMode),
///         ],
///       ),
///     ),
///   ],
///   child: const App(),
/// ));
/// ```
final httpConfigProvider = Provider<DioHttpConfig>((_) {
  throw UnimplementedError(
    'httpConfigProvider must be overridden by the app. '
    'See flutter_spine README → HTTP section.',
  );
});

/// 全 app 共享的单例 [HttpClient]。读 [httpConfigProvider] 自动构造。
///
/// 业务通常通过 `ref.read(httpClientProvider).get(...)` 调用。
/// 测试想换实现：override 本 provider 为自家 fake，或用 `DioHttpClient.fromDio` +
/// `MockAdapter`。
final httpClientProvider = Provider<HttpClient>((ref) {
  final config = ref.watch(httpConfigProvider);
  final client = DioHttpClient.fromConfig(config);
  ref.onDispose(client.close);
  return client;
});
