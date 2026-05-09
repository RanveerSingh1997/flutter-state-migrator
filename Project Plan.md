# Project Plan: Flutter State Migrator

## Overview
The **Flutter State Migrator** is an automated Command Line Interface (CLI) tool designed to assist developers in migrating Flutter applications from the `provider` state management package to `riverpod` (specifically, using Riverpod generators and `StateNotifier`).

## Current Status
The core pipeline for the tool has been successfully established and proven on a test project. The AST scanner can detect legacy Provider patterns and the transformer can rewrite source files in place without breaking Dart syntax.

## Milestones and Phases

### Phase 1: Core Parsing & Analysis (✅ Completed)
- [x] Set up Dart `analyzer` package to parse source code.
- [x] Implement the `AstScanner` to traverse directories and parse Dart files.
- [x] Define Intermediate Representation (IR) models (`ProviderNode`, `LogicUnitNode`, `WidgetNode`).

### Phase 2: Pattern Recognition (✅ Completed)
- [x] Create the `ProviderAdapter` (Visitor Pattern) to detect Provider nodes.
- [x] Recognize `ChangeNotifier` and `ChangeNotifierProvider`.
- [x] Recognize `Consumer` and `Provider.of<T>` / `context.read<T>`.
- [x] Handle syntax error suppression during scanning (`throwIfDiagnostics: false`).

### Phase 3: Suggestion & Generation (✅ Completed)
- [x] Develop the `RiverpodGenerator` to output equivalent Riverpod blueprints.
- [x] Implement "Assisted Mode" to generate parallel `_riverpod.dart` suggestion files.
- [x] Implement "Safe Mode" to inject `TODO` comments inline for manual migration.

### Phase 4: Automated Transformation (✅ Completed)
- [x] Build the `RiverpodTransformer` to compute precise `TextEdit` operations.
- [x] Convert `StatelessWidget` to `ConsumerWidget` and update `build` method signatures.
- [x] Unwrap `ChangeNotifierProvider` and preserve the `child` widget tree.
- [x] Append global `StateNotifierProvider` declarations to the source files.
- [x] Validate "Aggressive Mode" end-to-end on a test project.

### Phase 5: Refinement & Advanced Patterns (✅ Completed)
- [x] **MultiProvider Support**: Detected and unwrapped `MultiProvider`, migrating all grouped providers to global Riverpod scopes.
- [x] **Selectors**: Automatically converted `Selector<T, R>` patterns to `ref.watch(provider.select(...))`.
- [x] **Async Providers**: Migrated `FutureProvider` and `StreamProvider` to Riverpod equivalents.
- [x] **Auto-Formatting**: Integrated `dart format` to clean up formatting after aggressive edits.

### Phase 6: Polish & Distribution (✅ Completed)
- [x] Comprehensive unit test suite covering various edge cases.
- [x] Extensive project documentation (`README.md`, `CONTRIBUTING.md`).
- [x] Publish the tool to `pub.dev` (Prepared).

### Phase 7: Advanced Features & Ecosystem (✅ Completed)
- [x] **StatefulWidget Migration**: Automatically convert `StatefulWidget` and `State` to `ConsumerStatefulWidget` and `ConsumerState`.
- [x] **Flutter Hooks Support**: Support migrating `HookWidget` + `Provider` to `HookConsumerWidget`.
- [x] **Automated Test Migration**: Refactor `testWidgets` to use Riverpod's `ProviderScope` and overrides.
- [x] **Code Generation Polish**: Handle `dispose` logic and custom provider parameters.

### Phase 8: Intelligent Refinement & Reporting (✅ Completed)
- [x] **Intelligent Import Management**: Auto-add Riverpod imports and clean up unused Provider imports.
- [x] **Migration Audit Report**: Generate a detailed JSON/Markdown report of all changes made.
- [x] **Dependency Guard**: Detect and warn about circular dependencies between migrated providers.
- [x] **Enhanced CLI**: Add flags for report generation and import cleaning.

### Phase 9: Interactive Dry-run & CI/CD Setup (✅ Completed)
- [x] **Interactive Dry-run**: Show colorized diffs in the console before applying changes.
- [x] **GitHub Actions**: Automated testing on every push/PR.
- [x] **Comprehensive Example**: A multi-file example project for demonstration.
- [x] **CLI Visual Polish**: Refine console output for a premium experience.

## Future Roadmap: Ecosystem Expansion

### Phase 10: Intelligent Refactoring & Monorepos (✅ Completed)
- [x] **Monorepo Support**: Handle cross-package dependencies in large workspaces.
- [x] **Intelligent Logic Mapping**: Refactor `notifyListeners()` to idiomatic state updates.
- [x] **Custom Rule Engine**: Support project-specific migration rules via YAML.

### Phase 11: IDE Integration (VS Code Extension) (✅ Completed)
- [x] **VS Code Context Menu**: "Right-click to migrate" functionality.
- [x] **Inline Previews**: Interactive diffs within the editor.
- [x] **Quick Fix Actions**: Automated resolution of migration `TODO`s.

### Phase 12: Multi-Library Support & Visualizer
- [ ] **BLoC Migrator**: Support for migrating from `flutter_bloc` to Riverpod.
- [ ] **Riverpod Visualizer**: Automated generation of provider dependency graphs.
- [ ] **Migration Dashboard**: Interactive web UI for migration audit reports.

---
*This document serves as the living roadmap for the Flutter State Migrator project.*
