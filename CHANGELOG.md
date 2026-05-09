# Changelog

All notable changes to this project will be documented in this file.

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
