## 0.2.4

### Changed
- **Breaking**: `DioHttpConfig.authRefresh` and `DioHttpConfig.retry` fields removed. `AuthRefreshInterceptor` and `RetryInterceptor` are no longer auto-registered by `DioHttpClient.fromConfig()`. Business code should explicitly add these interceptors via `DioHttpConfig.interceptors` (for `AuthTokenInterceptor` / `HttpLoggingInterceptor` / `EnvelopeUnwrapInterceptor`) or by assembling a `Dio` instance with `DioHttpClient.fromDio()` (for `AuthRefreshInterceptor` / `RetryInterceptor` which require a Dio reference).
- Built-in interceptor classes (`AuthTokenInterceptor`, `HttpLoggingInterceptor`, `EnvelopeUnwrapInterceptor`, `AuthRefreshInterceptor`, `RetryInterceptor`, `AuthRefreshConfig`, `RetryConfig`) are **preserved** — business may still use them, just must register them explicitly.
- `DioHttpConfig.interceptors` doc updated to clarify it accepts any Dio `Interceptor` (built-in or custom).

### Added
- **`HttpClient.requestStream()`** — streaming request method for SSE / large file downloads / long-poll push. Returns `StreamedHttpResponse` with `statusCode` / `headers` / `stream` (`Stream<List<int>>`). Error normalization matches `request()` — non-2xx / network errors / timeouts throw `AppException`.
- **`StreamedHttpResponse`** — immutable stream response wrapper with `statusCode`, `headers`, `stream`, `isSuccess`, and `header()` lookup.
- **`HttpResponseType.stream`** — new enum value; maps to Dio's `ResponseType.stream`.
- 3 new tests in `dio_http_client_test.dart` covering stream response, 401 error, and cancelToken cancellation.

### Docs
- README §1.5 RetryInterceptor / §1.6 AuthRefreshInterceptor / §1.7 内置 Interceptor 速查 updated to show `DioHttpClient.fromDio()` assembly pattern.
- README §1.8 流式响应 / SSE added.
- `AiHelper/skills/flutter-core-http-setup/SKILL.md` updated: removed `authRefresh`/`retry` fields, added RetryInterceptor/AuthRefreshInterceptor assembly sections, added SSE/stream section.

### Tests
- `http_auth_refresh_interceptor_test.dart` and `http_retry_interceptor_test.dart` refactored to use `DioHttpClient.fromDio()` instead of `DioHttpConfig.authRefresh`/`.retry`.

## 0.2.3

### Fixed
- **`_defaultFactory` URL construction** — switched to pure string operations to avoid Dart SDK `Uri.replace()` port `:0` bug. Added scheme auto-correction (`http→ws`, `https→wss`) and port `:0` removal. Added step-by-step debug logging.
- **`isConnectAuthError` missing from `WsModuleConfig`** — field was added to `WsClientConfig` but not propagated through `WsModuleConfig` constructor, `toConfig()`, and `toConfigWith()`, causing configuration loss when using `WsModuleRegistry`.
- **`WsModuleConfig` missing reconnect fields** — `protocols`, `connectTimeout`, `baseReconnectDelay`, `maxReconnectDelay`, `maxReconnectAttempts`, `reconnectJitterRatio` were not in `WsModuleConfig`, preventing `sharedWsConfig` defaults from reaching the final `WsClientConfig`.
- **Connect auth refresh infinite loop** — `_reconnectAttempt` was reset to 0 on every connect-level auth refresh, preventing `maxReconnectAttempts` from ever being reached.
- **EffectListener double-dispatch** — root-level `EffectListener` now defaults to `handleDefaults: false`. `AppTabChildScaffold` and `AppBottomSheetScaffold` set `handleDefaultEffects: false`. Only `AppPageScaffold` processes built-in effects, eliminating duplicate navigation/toast/dialog triggers.
- **DemosPage double-navigation (example)** — parent route container now sets `handleDefaultEffects: false` to prevent processing effects emitted by child routes' ViewModels.

### Example
- `ws_modules.dart` token extracted to `_currentToken` variable — `onAuthExpired` writes back refreshed token, `queryParamsProvider` reads it on each connect/reconnect.
- `demo_market_ws_page.dart` refactored to use global `marketGatewayProvider` instead of self-built fake channel and hardcoded URL.

## 0.2.2

### Added
- **`BaseWsGateway`** — abstract WebSocket gateway for business modules. Delegates connection lifecycle to `WsClient`; subclasses (Market / Asset / Swap) define type-safe subscription APIs and topic encoding.
- **`WsClientConfig.headersProvider`** — dynamic headers callback. Called on every connect / reconnect to fetch the latest token, eliminating the need to rebuild config after auth refresh.
- **`WsClientConfig.queryParamsProvider`** — dynamic query string callback. Same pattern as `headersProvider`, for backends that pass auth tokens via URL query params (`?token=xxx`) instead of HTTP headers. Manual string concatenation avoids Dart SDK `Uri.replace()` port `:0` bug.
- **`WsClientConfig.onAuthExpired` + `isAuthCloseCode`** — token expiry auto-refresh. When the server closes with an auth close code (e.g. 4001), `DefaultWsClient` calls `onAuthExpired` with single-flight guarantee, then reconnects with the new token. Unsuccessful refresh transitions to `WsFailed`.
- **`WsClientConfig.isConnectAuthError`** — connection-level auth error detection. Handles HTTP 401/403 rejection during WebSocket upgrade handshake (complements `isAuthCloseCode` which handles post-connect close frames). Defined externally via predicate so backend-specific error formats are not hardcoded.
- **Close code handling in `DefaultWsClient`** — normal close codes (1000, 1001) now transition to `WsDisconnected` without triggering auto-reconnect. All other close codes continue to trigger standard reconnect.
- **Unified `IOWebSocketChannel` in `_defaultFactory`** — always uses `IOWebSocketChannel.connect()`, no longer implicitly switches between `WebSocketChannel.connect()` and `IOWebSocketChannel` based on parameter presence. Behavior is now consistent regardless of whether headers/queryParams are configured.
- **`WsTopicRouter.simple()`** — factory constructor for standard pub/sub protocols where channel name equals topic name. Auto-generates `topicExtractor`, `subscribeFrameBuilder`, and `unsubscribeFrameBuilder` from a single `channelKey` parameter.
- **`WsModuleRegistry` + `WsModuleConfig`** — registration pattern for WebSocket modules. Each business module defines a `WsModuleConfig` instance; `WsModuleRegistry.build()` maps URIs to configs, replacing hand-written if-else chains in `wsConfigBuilderProvider` overrides.
- **CLI `ws-gateway` command** — `flutter_spine:new ws-gateway <name>` generates topic / topic_router / ws_gateway / providers four-file scaffold.

### Changed
- **Breaking**: `WsClientConfig.headers` replaced by `headersProvider` (`Map<String, dynamic> Function()?`). Existing code must change from `headers: {'key': 'val'}` to `headersProvider: () => {'key': 'val'}`.
- `WsClientConfig` constructor now accepts `headersProvider`, `queryParamsProvider`, `onAuthExpired`, and `isAuthCloseCode` (all optional).
- `_defaultFactory` no longer branches on parameter presence — always constructs `IOWebSocketChannel` for consistent behavior.

### Tests
- 9 new test cases for close code handling, auth refresh, and connect-level auth detection (40 total in `test/network/ws/`).

### Example
- **`demo_market_ws/`** — full `MarketWsGateway` implementation: topic encoding/decode (`MarketTopic`), protocol adapter (`marketTopicRouter`), Riverpod `StreamProvider.autoDispose.family` for automatic subscription lifecycle, and interactive lifecycle demo page.
- **`demo_asset_ws/`** & **`demo_swap_ws/`** — showcase multi-module Gateway pattern. All three modules share the same auth/heartbeat/reconnect config via a `_sharedWsConfig` factory in `main.dart`, each overriding only its own `topicRouter`.
- `main.dart` now demonstrates `FlutterSpineConfig.extraOverrides` with `WsModuleRegistry.build()` replacing the if-else chain.

## 0.1.2

### Added
- `PagedListView.scrollViewBuilder` — embed the list in a `CustomScrollView` with extra slivers.
- `PagedListView.enableLoadMore` — disable load-more footer, keep only pull-to-refresh.
- `AppListPageScaffold.scrollViewBuilder` / `enableLoadMore` — forwarded to `PagedListView`.
- `PagedScrollViewBuilder` typedef.
- Example demo pages: `/demos/paged-list`, `/demos/app-list`.

### Fixed
- `DioExceptionType.transformTimeout` not found with dio 5.9.x — replaced with `default` / `_` fallback for forward compatibility.

## 0.1.1

### Added
- Scaffold CLI (`flutter_spine:new`).
- `generator_templates.dart` — riverpod_generator support.
- `FeatureCommand` — `flutter_spine:new feature` one-key whole feature generation.
- `BootstrapCommand` — `flutter_spine:new bootstrap` app skeleton.
- `FlutterCoreDiagnosticsBanner`.
- `MaterialDefaultEffectHandler` ctor overrides.
- `mixin`-based API: `ViewModelMixin`, `AsyncViewModelMixin`, family variants.

### Changed
- CLI templates now use `{{Name}}` / `{{name}}` / `{{name_snake}}` / `{{name-kebab}}` / `{{Title}}` naming conventions.
- Renamed `FlutterCore` to `FlutterSpine`, `FlutterCoreConfig` to `FlutterSpineConfig`.

## 0.1.0

- Initial release.
- `error/`: sealed `AppException` hierarchy + `safeApiCall` normalization.
- `network/`: `ChannelClient` MethodChannel wrapper.
- `pagination/`: `PagedState` + `PagedNotifierMixin` (family + noArg).
- `filter/`: `FilterNotifier` base class.
- `presentation/`: `AsyncBuilder` + `AsyncValue` extensions.
- `logging/`: `AppLogger` interface + `PrettyAppLogger` implementation.
- `observers/`: `ErrorObserver` (toast callback injection) + `LogObserver`.
- `storage/`: `KeyValueStorage` abstraction + `HiveStorage` + `keyValueStorageProvider`.
- `theme/`: `AppThemeExtension` + `ThemeModeNotifier`.
- `utils/`: `num_ext`, `string_ext`, `date_ext`, `iterable_ext`, `context_ext`.
