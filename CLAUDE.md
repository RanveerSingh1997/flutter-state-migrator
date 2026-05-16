# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run all tests
flutter test

# Run a single test file
flutter test test/scanner_test.dart

# Run specific tests by name pattern
flutter test --name "BlocAdapter"

# Lint / static analysis (must report zero issues before any commit)
dart analyze lib/

# Run the CLI (interactive wizard when no args given)
dart run bin/migrator.dart

# Run CLI on a Flutter project
dart run bin/migrator.dart --mode=aggressive /path/to/flutter/project

# Dry-run aggressive mode (show diff, no writes)
dart run bin/migrator.dart --mode=aggressive --dry-run /path/to/project

# Emit IDE JSON diagnostics
dart run bin/migrator.dart --ide-json /path/to/project
```

## Architecture

The platform follows a strict four-stage pipeline, shared by all features:

```
AST Parsing → Typed Semantic IR → ArchitectureGraph → Intelligence / Migration
```

### Stage 1 — Scanning (`lib/migrator/scanner/`)

`AstScanner` walks Dart files using the `analyzer` package (`parseString`). It delegates to four framework-specific `RecursiveAstVisitor` adapters:

- `ProviderAdapter` — Provider, StatelessWidget, StatefulWidget, State, HookWidget
- `BlocAdapter` — Bloc, Cubit
- `GetXAdapter` — GetxController
- `MobXAdapter` — MobX stores (detected via `@observable`/`@action` annotations)

Each adapter emits typed `ProviderNode` subclasses (defined in `lib/migrator/models/ir_models.dart`). Key subtypes: `LogicUnitNode`, `WidgetNode`, `ProviderDeclarationNode`, `ConsumerNode`, `ProviderOfNode`, `SelectorNode`, `AsyncProviderNode`, `StateNode`, `HookWidgetNode`.

**Critical API note:** `ClassDeclaration.name` is deprecated in analyzer 10.x. Always use `node.namePart.typeName.lexeme` to extract a class name from a `ClassDeclaration`. `NamedType.name.lexeme` (for superclass/mixin type references) is **not** deprecated and stays unchanged. `MethodDeclaration.name.lexeme` is also **not** deprecated.

Shared utilities live in `scanner_utils.dart`: `buildMethodInfo()` and `detectNotifierType()` are used by all adapters and the generator.

Plugins can extend scanning via `lib/migrator/plugins/plugin_base.dart` — implement `CustomAdapter` (a `RecursiveAstVisitor`) and `CustomTransformer`. `PluginLoader` loads them from a `migrator_plugins/` directory in the target project.

### Stage 2 — Semantic Graph (`lib/migrator/models/graph_models.dart`, `lib/migrator/analysis/graph_builder.dart`)

`GraphBuilder.buildGraph()` converts the flat `List<ProviderNode>` into an `ArchitectureGraph` — a map of unique component IDs to nodes and a list of typed `DependencyEdge`s (`provides`, `watches`, `reads`, `creates`, `navigates`, `calls`). The graph is the shared input for all downstream intelligence.

### Stage 3 — Intelligence (`lib/migrator/analysis/`)

All intelligence engines operate on the `ArchitectureGraph`:

- `ArchitectureIntelligenceEngine` — detects God Components, State Explosion, High Coupling, Circular Dependencies, Improper Async Patterns
- `GovernanceEngine` — validates configurable architecture contracts (forbidden layer dependencies, max coupling, max depth) loaded from `migrator_config.yaml`
- `IdeIntelligenceEngine` — produces structured `IdeDiagnostic` + `IdeQuickFix` JSON consumed by the VS Code extension (`vscode-extension/`)
- `AIManager` — LLM-assisted guidance; prefers a local Ollama endpoint (`http://localhost:11434`), falls back deterministically when unavailable
- `ArchitectureDriftDetector` — compares current graph against saved snapshots to track health trends
- `AnalyticsManager` — computes Architecture Health Score (0–100)
- `MonorepoManager` — discovers packages in a monorepo and scopes migration per-package
- `SnapshotManager` — saves/restores full project snapshots before aggressive rewrites

### Stage 4 — Migration / Generation (`lib/migrator/generator/`)

Three migration modes, all controlled via `--mode` in `bin/migrator.dart`:

| Mode | Behavior |
|------|----------|
| `safe` | Injects `// TODO(Migrator):` comments at source offsets |
| `assisted` | Generates `*_riverpod.dart` side-files with Riverpod equivalents |
| `aggressive` | Rewrites source files in-place using `TextEdit` operations |

`RiverpodTransformer` produces `List<TextEdit>` for each node. Edits are applied in reverse-offset order by `applyEdits()` in `lib/migrator/utils/edit_applier.dart`. `BodyTransformer` handles ChangeNotifier→Riverpod method body rewrites. `ImportManager` adds Riverpod imports and optionally removes Provider imports after rewriting.

Configuration is loaded from `migrator_config.yaml` at the project root (optional; safe defaults apply when absent). Keys: `provider_naming`, `auto_merge_state`, `governance` (map), `architecture_roles` (map).

## Test Layout

Tests are in `test/`. Fixture files for regression tests live in `test/fixtures/`. The analyzer excludes `example/`, `test_project/`, and `test/fixtures/` from analysis.

Exit criterion: `dart analyze lib/` must report **zero issues** and `flutter test` must pass **all 97 tests** before any commit or PR.
