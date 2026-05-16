# Changelog

All notable changes to this project will be documented in this file.

## [2.2.2] - 2026-05-16

### Fixed
- `dart format` applied to all `lib/` and `bin/` files — resolves pub.dev static-analysis formatting check.
- Repaired broken `example/lib/main.dart` (syntax error in Consumer builder); example now compiles and runs correctly.
- Removed dead `cloud_manager.dart` from `lib/migrator/analysis/` (file was never imported post-2.2.1 cleanup).
- Fixed unresolved doc reference `[Project Plan]` in `README.md` (filename contained a space); renamed to `Project_Plan.md`.
- Added `///` doc comments to all public IR node classes (`ProviderNode`, `LogicUnitNode`, `WidgetNode`, et al.) to meet pub.dev 20% documentation coverage threshold.
- Stripped auto-generated Flutter app boilerplate comments from `pubspec.yaml`.

## [2.2.1] - 2026-05-16

### Fixed
- `AsyncNotifier` and `StreamNotifier` `build()` now uses the real method body and infers the concrete return type (e.g. `Future<List<User>>`) instead of emitting a `return null; // TODO` placeholder that failed to compile.
- `Selector` transformer now skips nodes where no `selector:` argument was captured, preventing broken Dart output. Generator uses the actual normalised selector snippet instead of a hardcoded `state.someProperty` template.
- Removed the `--sync` flag and `CloudManager` which simulated a fake cloud upload with a fabricated URL.
- `PluginLoader` now prints a clear warning when a `migrator_plugins/` directory is detected rather than silently doing nothing.

### Added
- 13 new tests covering edge cases: generic type parameters, mixin usage, family candidates, widgets with multiple provider accesses, empty/malformed input. Suite: 84 → 97 tests.
- `scripts/publish.sh` — automated release script that bumps version, updates CHANGELOG, tags, pushes, publishes to pub.dev, and opens a dev branch.

## [2.2.0] - 2026-05-13

### Added
- **IDE Intelligence (Phase 40)**: `migrator --ide-json` now emits structured architecture and governance diagnostics for editor integrations.
- **VS Code Diagnostics & Quick Fixes**: The extension now surfaces inline diagnostics, recommendation actions, and migration commands for Dart files.
- **AI Architecture Guidance (Phase 44)**: `AIManager` now produces explainable guidance for architecture smells, governance violations, and complex notifier methods.

### Changed
- `--ai` now prefers a local Ollama-compatible endpoint and falls back to deterministic recommendations when the LLM is unavailable.

## [2.1.1] - 2026-05-11

### Fixed
- Preserved getter signatures and return types in generated Riverpod output instead of emitting method-shaped accessors.
- Preserved method parameter lists during migration so notifier methods keep their original call contract.
- Corrected `Consumer` and `Selector` rewrites to emit valid builder separators and normalized `.select(...)` lambdas.
- Preserved chained provider method calls so imperative actions migrate to `ref.read(...).method()`.
- Removed conflicting Riverpod output patterns by standardizing migrated logic units on the `@riverpod` code generation flow.
- Inferred `build()` return types from typed state fields instead of defaulting to `dynamic`.
- Captured typed state fields in the IR so generated state and notifier code keeps source field types.

## [2.1.0] - 2026-05-10

### Added
- **Notifier Type Selector (Phase 26)**: Adapters now detect async methods and Stream return types to automatically select the correct Riverpod primitive — `AsyncNotifier`, `StreamNotifier`, or `StateNotifier`.
- **Provider Family Detection (Phase 27)**: Constructor parameters (beyond `key`) are detected across all adapters; the generator emits `.family` scaffold with the appropriate provider type and `ArgType` placeholder.
- **Real Dependency Graph (Phase 28)**: `DependencyChecker` now builds a true provider→consumer adjacency map from the IR and uses DFS with `visited`/`inStack` tracking to report all circular dependency chains.

### Fixed
- CI analysis no longer fails on `example/` and `test_project/` sub-projects (excluded via `analysis_options.yaml` and workflow scope).
- All source files reformatted to pass `dart format` check.

## [2.0.0] - 2026-05-09

### Added
- **Universal Migrator**: Support for all major state libraries — Provider, BLoC/Cubit, GetX, and MobX.
- **Interactive CLI Wizard**: Guided onboarding with auto-detection of installed state libraries (`--wizard`).
- **Snapshot & Rollback**: Automatic project snapshots before aggressive migration with one-command rollback.
- **Automated Dependency Management**: Auto-updates `pubspec.yaml` with Riverpod packages after migration.
- **ROI & Analytics Engine**: Migration metrics including complexity scores and estimated engineering hours saved.
- **AI-Assisted Refactoring**: Local LLM integration for complex method body transformation (`--ai`).
- **Deep Body Refactoring**: Automatic rewriting of state mutations to `state.copyWith(...)`.
- **Immutable State Generation**: Auto-generated immutable state classes for migrated notifiers.
- **Flutter Web Dashboard**: Browser-based visual interface for migration reports.
- **Cloud Report Sync**: Upload migration audits to a central dashboard (`--sync`).
- **Custom Plugin System**: Registry-based extensibility via external Dart scripts.
- **Lint-Aware Safety**: Project-level health checks before and after migration.

### Changed
- Description updated: tool now migrates from Provider, BLoC, GetX, and MobX — not just Provider.
- CLI flags reorganised; wizard mode launched automatically when no path is provided.
- `migration_report.json` now includes ROI metrics, node inventory, and modified file list.

---

## [1.0.0] - 2026-05-09

### Added
- **Core Migration Engine**: AST-based scanning and transformation for Flutter projects.
- **Provider Support**: Migration of `ChangeNotifierProvider`, `Consumer`, `Selector`, and `Provider.of`.
- **BLoC & Cubit Support**: Initial migration support for `Bloc` and `Cubit` classes to Riverpod.
- **Interactive Dry-run**: Colorized console diff previews using the `--dry-run` flag.
- **Monorepo Support**: Automatic detection and reporting of multiple packages in a workspace.
- **VS Code Extension**: Explorer context menu integration for "Right-click to migrate".
- **Provider Visualizer**: Generation of Mermaid dependency graphs via the `--visualize` flag.
- **Audit Reporting**: Detailed `migration_report.json` with complexity scores and metrics.
- **Import Management**: Automated handling of `flutter_riverpod` imports and legacy cleanup.
- **CI/CD**: GitHub Actions pipeline for automated testing and code quality.

### Changed
- Refined CLI UX with polished headers and color-coded status messages.
- Improved intelligent logic mapping for state-changing methods.

---
Initial release of the Flutter State Migrator ecosystem.
