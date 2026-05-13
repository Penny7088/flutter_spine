## [Unreleased]

### Added
- Open source readiness: LICENSE (MIT), CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md.
- CI/CD: GitHub Actions workflow for analyze and test.
- Issue and PR templates.
- `homepage`, `repository`, `issue_tracker` metadata in pubspec.yaml.

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
