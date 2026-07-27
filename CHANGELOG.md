## 0.2.0

### Added
- **`BaseWsGateway`** — abstract WebSocket gateway for business modules. Delegates connection lifecycle to `WsClient`; subclasses (Market / Asset / Swap) define type-safe subscription APIs and topic encoding.
- **`WsClientConfig.headersProvider`** — dynamic headers callback. Called on every connect / reconnect to fetch the latest token, eliminating the need to rebuild config after auth refresh.
- **`WsClientConfig.queryParamsProvider`** — dynamic query string callback. Same pattern as `headersProvider`, for backends that pass auth tokens via URL query params (`?token=xxx`) instead of HTTP headers. Manual string concatenation avoids Dart SDK `Uri.replace()` port `:0` bug.
- **`WsClientConfig.onAuthExpired` + `isAuthCloseCode`** — token expiry auto-refresh. When the server closes with an auth close code (e.g. 4001), `DefaultWsClient` calls `onAuthExpired` with single-flight guarantee, then reconnects with the new token. Unsuccessful refresh transitions to `WsFailed`.
- **Close code handling in `DefaultWsClient`** — normal close codes (1000, 1001) now transition to `WsDisconnected` without triggering auto-reconnect. All other close codes continue to trigger standard reconnect.
- **Unified `IOWebSocketChannel` in `_defaultFactory`** — always uses `IOWebSocketChannel.connect()`, no longer implicitly switches between `WebSocketChannel.connect()` and `IOWebSocketChannel` based on parameter presence. Behavior is now consistent regardless of whether headers/queryParams are configured.

### Changed
- **Breaking**: `WsClientConfig.headers` replaced by `headersProvider` (`Map<String, dynamic> Function()?`). Existing code must change from `headers: {'key': 'val'}` to `headersProvider: () => {'key': 'val'}`.
- `WsClientConfig` constructor now accepts `headersProvider`, `queryParamsProvider`, `onAuthExpired`, and `isAuthCloseCode` (all optional).
- `_defaultFactory` no longer branches on parameter presence — always constructs `IOWebSocketChannel` for consistent behavior.

### Tests
- 7 new test cases for close code handling and auth refresh (33 total in `test/network/ws/`).

### Example
- **`demo_market_ws/`** — full `MarketWsGateway` implementation: topic encoding/decode (`MarketTopic`), protocol adapter (`marketTopicRouter`), Riverpod `StreamProvider.autoDispose.family` for automatic subscription lifecycle, and interactive lifecycle demo page.
- **`demo_asset_ws/`** & **`demo_swap_ws/`** — showcase multi-module Gateway pattern. All three modules share the same auth/heartbeat/reconnect config via a `_sharedWsConfig` factory in `main.dart`, each overriding only its own `topicRouter`.
- `main.dart` now demonstrates `FlutterSpineConfig.extraOverrides` with per-URI `WsClientConfig` dispatch.

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
