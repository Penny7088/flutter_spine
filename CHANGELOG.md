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
