---
name: flutter-core-http-setup
description: Configure HTTP client with Dio, interceptors, retry, 401 auth-refresh, and multipart upload through flutter_core's DioHttpConfig. Use when the user asks about HTTP setup, baseUrl, headers, token, retry, upload, or 401 refresh in flutter_core apps.
---

# HTTP 接入

## 业务侧 5 行接入

`main.dart`：

```dart
FlutterCore.runApp(
  config: FlutterCoreConfig(
    http: DioHttpConfig(
      baseUrl: 'https://api.example.com',
      defaultHeaders: const {'Accept': 'application/json'},
      interceptors: [
        AuthTokenInterceptor(tokenProvider: () async => storage.read('token')),
        HttpLoggingInterceptor(),
        EnvelopeUnwrapInterceptor(successCode: 0),       // 后端是 {code,msg,data} 的话
      ],
      retry: const RetryConfig(maxRetries: 3),
      authRefresh: AuthRefreshConfig(refreshToken: () => authRepo.refresh()),
    ),
  ),
  app: (ctx) => MaterialApp(home: const HomePage()),
);
```

业务用：

```dart
class OrderRepo {
  OrderRepo(this._http);
  final HttpClient _http;
  Future<List<Order>> list() => _http.get<List<Order>>(
    '/orders',
    decoder: (raw) => (raw as List).map(Order.fromJson).toList(),
  );
}

final orderRepoProvider = Provider((ref) => OrderRepo(ref.read(httpClientProvider)));
```

## 决策表

| 场景 | 怎么配 |
|---|---|
| 加全局 baseUrl | `DioHttpConfig(baseUrl: '...')` |
| 加 Bearer token | `interceptors: [AuthTokenInterceptor(tokenProvider: ...)]` |
| 后端有 `{code,message,data}` envelope | `interceptors: [EnvelopeUnwrapInterceptor(successCode: 0)]` |
| 网络错 / 5xx 自动重试 | `retry: RetryConfig(maxRetries: 3)` |
| 401 自动 refresh token | `authRefresh: AuthRefreshConfig(refreshToken: () async => ...)` |
| 文件上传 | `httpClient.upload(path, files: [MultipartFilePart.fromPath(...)], ...)` |
| 取消请求 | `final ct = httpClient.createCancelToken(); ... ct.cancel();` |

## RetryConfig 默认行为

- 默认重试：网络错、connect/send/receive timeout、5xx、429。
- 默认幂等方法：GET / HEAD / OPTIONS / DELETE / PUT —— **POST / PATCH 默认不重试**（防重复扣款类副作用）。
- 想 POST 也重试：`forceIdempotentExtraKey: 'X-Request-Id'`，业务每次 POST 在 header 里塞唯一 id（后端按 id 去重）。
- 自定义判定：`shouldRetry: (DioException e, RequestOptions opt, int attempt) => bool`。
- 退避：`baseDelay × 2^(attempt-1)`，封顶 `maxDelay`，乘 `(1 ± jitterRatio)` 随机。

## AuthRefreshConfig 必看

- 单飞机制：并发 N 个 401 只会触发**一次** refresh，其它请求等同一个 future。
- `refreshToken()` 返回 `String?` —— `null` = 拒绝 refresh，原 401 上抛 `UnauthorizedException`。
- `skipPaths`：refresh 接口本身要排除（`['/auth/refresh']`），否则 401 → refresh → 又 401 → 再 refresh 死循环。
- `shouldRefresh: (DioException e) => bool` 默认只在 401。如果后端用 `{code:401_in_body, status:200}` 这种烂设计，自定义这个判定 + 上 `EnvelopeUnwrapInterceptor`。
- refresh 成功后**自动 retry 原请求**（用新 token 换掉 header）。

## 不要做的事

- ❌ 不要在 `interceptors: [...]` 里手动塞 `RetryInterceptor` / `AuthRefreshInterceptor` —— 用 `DioHttpConfig.retry / authRefresh` 字段，否则顺序乱（retry 必须在 authRefresh 之后）。
- ❌ 不要 `dio.interceptors.add(...)` 在 `httpClientProvider` 之外动 dio —— `DioHttpClient` 拿到的是同一个实例，会脏。
- ❌ 业务 Repository 不要 `import 'package:dio/dio.dart';`（`avoid_direct_dio` lint 会拦）。需要 dio 的 `Options` / `CancelToken` 等类型，flutter_core 已经 re-export 了 `CancelToken`；其它能避就避。
- ❌ 不要在 Repository 里 `try { } catch (DioException e) { }` —— `DioHttpClient` 内部已经把 DioException 归一到 `AppException`，业务 catch 拿不到 `DioException`。

## upload 详解

```dart
final res = await http.upload<UploadResp>(
  '/avatar',
  files: [
    MultipartFilePart.fromPath(
      path: '/sdcard/a.png',
      field: 'file',
      filename: 'avatar.png',                             // 可选，默认取 path basename
      contentType: 'image/png',                           // 可选，默认 application/octet-stream
    ),
    MultipartFilePart.fromBytes(
      bytes: pngBytes,
      field: 'thumbnail',
      filename: 'thumb.png',
      contentType: 'image/png',
    ),
  ],
  fields: {'caption': 'hi'},
  onSendProgress: (sent, total) =>
    debugPrint('${(sent / total * 100).toStringAsFixed(1)}%'),
  decoder: (raw) => UploadResp.fromJson(raw as Map<String, dynamic>),
);
```

同 `field` 多文件 → 自动按 `multiCompatible` 列表格式打包。

## 验证

```bash
cd package/flutter_core
flutter test test/network/http/
```

如果改了 interceptor 顺序逻辑，必须跑 `http_retry_interceptor_test.dart` 和 `http_auth_refresh_interceptor_test.dart`。
