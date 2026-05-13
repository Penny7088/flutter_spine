# Contributing

Thank you for considering contributing to `flutter_spine`!

## How to contribute

1. **Fork** the repository and create your branch from `main`.
2. **Install** dependencies:
   ```bash
   dart pub get
   ```
3. **Make your changes** following the project conventions:
   - VM 里不要引用 `BuildContext` / `Navigator` — 一律 `emit(EffectXxx)`
   - 业务页面不要直接继承 `Scaffold` — 选 `AppXxxScaffold`
   - 不要直接 `Dio()` / `WebSocketChannel.connect()` — 走 `HttpClient` / `WsClient`
4. **Run the analyzer** to check for issues:
   ```bash
   dart analyze
   ```
5. **Run tests** to make sure nothing is broken:
   ```bash
   flutter test
   ```
6. **Commit** with a clear message describing the change.
7. **Open a pull request** against `main`.

## Pull request guidelines

- Keep PRs focused on a single concern.
- Include tests for new features or bug fixes.
- Update `CHANGELOG.md` with the change under the `[Unreleased]` section.
- Ensure `dart analyze` passes with zero errors.
- Ensure all tests pass.

## Code style

- This project uses `flutter_lints` — the analyzer is configured in `analysis_options.yaml`.
- Follow the existing code style and naming conventions.
- Document public APIs with `///` doc comments.

## Reporting issues

Use the [GitHub issue tracker](https://github.com/Penny7088/flutter_arch_river_pod/issues) to report bugs or request features.
