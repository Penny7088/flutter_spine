---
name: flutter-core-http-setup
description: Configure HTTP client with Dio, interceptors, retry, 401 auth-refresh, and multipart upload through DioHttpConfig. Use when the user asks about HTTP setup, baseUrl, headers, token, retry, upload, or 401 refresh in flutter_core apps.
---

# HTTP 接入

## 业务侧接入

`main.dart`：

```dart
FlutterCore.runApp(
  config: FlutterCoreConfig(
    http: DioHttpConfig(
      baseUrl: 'https://api.example.com',
      defaultHeaders: const {'Accept': 'application/json'},
      interceptors: [
        // 动态 header：用内置或自定义 Dio Interceptor 控制
        AuthTokenInterceptor(tokenProvider: () => storage.read('token')),
        HttpLoggingInterceptor(),
        EnvelopeUnwrapInterceptor(successCode: 0), // 后端是 {code,msg,data} 的话
      ],
    ),
  ),
  app: (ctx) => MaterialApp(home: const HomePage()),
);
```

> 需要 Retry / AuthRefresh？这些拦截器需要持有 Dio 引用，推荐通过 `DioHttpClient.fromDio` 自行组装——
> 见下方 § RetryInterceptor 和 § AuthRefreshInterceptor。

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
| 加静态 header | `DioHttpConfig(defaultHeaders: {'X-App-Id': 'wallet'})` |
| 加动态 header（如 Bearer token） | `interceptors: [AuthTokenInterceptor(tokenProvider: ...)]` — 或自定义 Dio `Interceptor` |
| 后端有 `{code,message,data}` envelope | `interceptors: [EnvelopeUnwrapInterceptor(successCode: 0)]` |
| 网络错 / 5xx 自动重试 | 见下方 § RetryInterceptor |
| 401 自动 refresh token | 见下方 § AuthRefreshInterceptor |
| 文件上传 | `httpClient.upload(path, files: [MultipartFilePart.fromPath(...)], ...)` |
| 取消请求 | `final ct = httpClient.createCancelToken(); ... ct.cancel();` |
| SSE / 流式响应 | `httpClient.requestStream(method: HttpMethod.get, path: '/events')` — `res.stream` 逐步消费 |

## SSE / 流式响应

```dart
final res = await http.requestStream(
  method: HttpMethod.get,
  path: '/api/chat/stream',
);

await for (final chunk in res.stream) {
  final text = utf8.decode(chunk);
  // 解析 SSE 帧 / JSON 行 / 写入文件
}
```

`requestStream()` 返回 `StreamedHttpResponse`，`res.stream` 是 `Stream<List<int>>`。错误归一与 `request()` 一致——非 2xx / 网络错 / 超时仍抛 `AppException`。

## RetryInterceptor

`RetryInterceptor` 需要持有 Dio 引用，推荐通过 `DioHttpClient.fromDio` 自行组装：

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.add(
  RetryInterceptor(
    dio: dio,
    maxRetries: 3,
    baseDelay: const Duration(milliseconds: 300),
    maxDelay: const Duration(seconds: 5),
    jitterRatio: 0.2,
  ),
);
final client = DioHttpClient.fromDio(dio);
```

### RetryInterceptor 默认行为

- 默认重试：网络错、connect/send/receive timeout、5xx。
- 默认幂等方法：GET / HEAD / OPTIONS / DELETE / PUT —— **POST / PATCH 默认不重试**（防重复扣款类副作用）。
- 想 POST 也重试：`Options.extra[RetryInterceptor.forceIdempotentExtraKey] = true`，业务每次 POST 在 header 里塞唯一 id（后端按 id 去重）。
- 自定义判定：传 `shouldRetry: (DioException e, RequestOptions opts) => bool`。
- 退避：`baseDelay × 2^n`，封顶 `maxDelay`，乘 `(1 ± jitterRatio)` 随机。

## AuthRefreshInterceptor

`AuthRefreshInterceptor` 需要持有 Dio 引用，推荐通过 `DioHttpClient.fromDio` 自行组装：

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.addAll([
  AuthTokenInterceptor(tokenProvider: () => session.token),
  AuthRefreshInterceptor(
    dio: dio,
    refreshToken: () => authRepo.refresh(),
  ),
]);
final client = DioHttpClient.fromDio(dio);
```

### AuthRefreshInterceptor 必看

- 单飞机制：并发 N 个 401 只会触发**一次** refresh，其它请求等同一个 future。
- `refreshToken()` 返回 `String?` —— `null` = 拒绝 refresh，原 401 上抛 `UnauthorizedException`。
- `skipPaths`：refresh 接口本身要排除（`['/auth/refresh']`），否则 401 → refresh → 又 401 → 再 refresh 死循环。
- `shouldRefresh: (DioException e) => bool` 默认只在 401。如果后端用 `{code:401_in_body, status:200}` 这种设计，自定义这个判定 + 上 `EnvelopeUnwrapInterceptor`。
- refresh 成功后**自动 retry 原请求**（用新 token 换掉 header）。

## 不要做的事

- ❌ 业务 Repository 不要 `import 'package:dio/dio.dart';`（`avoid_direct_dio` lint 会拦）。需要 dio 的 `Options` / `CancelToken` 等类型，flutter_core 已经 re-export 了 `CancelToken`；其它能避就避。
- ❌ 不要在 Repository 里 `try { } catch (DioException e) { }` —— `DioHttpClient` 内部已经把 DioException 归一到 `AppException`，业务 catch 拿不到 `DioException`。
- ❌ 不要在 `httpClientProvider` 之外动 dio instance —— `DioHttpClient` 拿到的是同一个实例。

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
