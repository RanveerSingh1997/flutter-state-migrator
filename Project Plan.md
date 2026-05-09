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

### Phase 5: Refinement & Advanced Patterns (🚧 Next Steps)
- [ ] **MultiProvider Support**: Detect and unwrap `MultiProvider`, migrating all grouped providers to global Riverpod scopes.
- [ ] **Selectors**: Automatically convert `Selector<T, R>` patterns to `ref.watch(provider.select((state) => state.r))`.
- [ ] **Async Providers**: Migrate `FutureProvider` and `StreamProvider` to Riverpod equivalents handling `AsyncValue`.
- [ ] **Auto-Formatting**: Integrate `dart format` via a shell execution or formatter API to clean up formatting after aggressive edits.

### Phase 6: Polish & Distribution (📅 Future)
- [ ] Comprehensive unit test suite covering various edge cases.
- [ ] Extensive project documentation (`README.md`, `CONTRIBUTING.md`).
- [ ] Publish the tool to `pub.dev`.

---
*This document serves as the living roadmap for the Flutter State Migrator project.*
