# Flutter Architecture Intelligence Platform

[![CI/CD](https://github.com/RanveerSingh1997/flutter-state-migrator/actions/workflows/dart_test.yml/badge.svg)](https://github.com/RanveerSingh1997/flutter-state-migrator/actions/workflows/dart_test.yml)
[![Pub Version](https://img.shields.io/pub/v/flutter_state_migrator)](https://pub.dev/packages/flutter_state_migrator)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-grade CLI that migrates Flutter apps from **Provider, BLoC/Cubit, GetX, and MobX** to modern **Riverpod** — and keeps your architecture healthy after the migration.

---

## What Gets Migrated

### Provider

| Pattern | Riverpod equivalent |
|---------|---------------------|
| `class X extends ChangeNotifier` | `@riverpod class X extends _$X` |
| `class X extends ValueNotifier<T>` | `@riverpod class X extends _$X` with `value` state |
| `ChangeNotifierProvider(create: ...)` | Global `@riverpod` class + `ProviderScope` at root |
| `ProxyProvider<T, R>` | `@riverpod` class whose `build()` calls `ref.watch(tProvider)` |
| `ChangeNotifierProxyProvider<T, R>` | `@riverpod` Notifier with `ref.watch(baseProvider)` dependency |
| `Consumer<T>(builder: ...)` | `ConsumerWidget` with `ref.watch(tProvider)` |
| `ValueListenableBuilder<T>` | `Consumer` with `ref.watch(tProvider)` |
| `Selector<T, R>(selector: ...)` | `ref.watch(tProvider.select(...))` |
| `MultiProvider(providers: [...])` | `ProviderScope` (all providers become global) |
| `FutureProvider<T>` / `StreamProvider<T>` | Riverpod async provider skeleton |
| `Provider.of<T>(context)` | `ref.watch(tProvider)` |
| `context.watch<T>()` | `ref.watch(tProvider)` |
| `context.read<T>()` | `ref.read(tProvider)` |
| `context.select<T, R>(fn)` | `ref.watch(tProvider.select(fn))` |
| `StatelessWidget` | `ConsumerWidget` |
| `StatefulWidget` / `State<T>` | `ConsumerStatefulWidget` / `ConsumerState<T>` |
| `HookWidget` | `HookConsumerWidget` |

### BLoC / Cubit

| Pattern | Riverpod equivalent |
|---------|---------------------|
| `class X extends Cubit<S>` | `@riverpod class X extends _$X` |
| `class X extends Bloc<E, S>` | `@riverpod class X extends _$X` (AsyncNotifier) |
| `BlocProvider(create: ...)` | Global `@riverpod` class + `ProviderScope` |
| `MultiBlocProvider(providers: [...])` | `ProviderScope` |
| `BlocBuilder<B, S>(builder: ...)` | `Consumer` with `ref.watch(bProvider)` |
| `BlocConsumer<B, S>` | `Consumer` with `ref.watch(bProvider)` |
| `BlocListener<B, S>` | `Consumer` with `ref.watch(bProvider)` |
| `BlocSelector<B, S, T>(selector: ...)` | `ref.watch(bProvider.select(...))` |

### GetX

| Pattern | Riverpod equivalent |
|---------|---------------------|
| `class X extends GetxController` (with `.obs` fields) | `@riverpod class X extends _$X` with typed state |
| `Get.put<T>(...)` | Global `@riverpod` class |
| `Get.lazyPut<T>(() => ...)` | Global `@riverpod` class |
| `Get.create<T>(() => ...)` | Global `@riverpod` class |
| `Get.find<T>()` | `ref.read(tProvider)` / `ref.read(tProvider.notifier)` |
| `GetX<T>(builder: ...)` / `GetBuilder<T>` | `Consumer` with `ref.watch(tProvider)` |
| `Obx(() => ...)` | `Consumer` with `ref.watch(tProvider)` |

### MobX

| Pattern | Riverpod equivalent |
|---------|---------------------|
| `@observable` fields | Immutable state fields in `@riverpod` Notifier |
| `@computed` fields | `ref.watch(storeProvider.select(...))` at the consumer |
| `@action` methods | Methods on the Riverpod Notifier |
| `Observer(builder: ...)` | `Consumer` with `ref.watch(storeProvider)` |

---

## Quick Start

```bash
# Install globally
dart pub global activate flutter_state_migrator
```

```bash
# 1. Analyze — see what will be migrated, no writes
migrator .

# 2. Preview — show diffs without touching files
migrator --mode aggressive --dry-run .

# 3. Migrate — rewrite source files in-place
migrator --mode aggressive .

# 4. Roll back if needed — full snapshot taken before every aggressive run
migrator --rollback .
```

---

## Migration Modes

| Mode | Flag | What it does |
|------|------|--------------|
| **Safe** | `--mode safe` (default) | Injects `// TODO(Migrator):` comments at every detected pattern — no source rewrites |
| **Assisted** | `--mode assisted` | Writes `*_riverpod.dart` side-files with Riverpod equivalents alongside originals |
| **Aggressive** | `--mode aggressive` | Rewrites source files in-place; full snapshot taken first |

---

## Architecture Intelligence

After scanning, the platform builds a semantic dependency graph and detects smells:

| Smell | Trigger | Severity |
|-------|---------|----------|
| God Component | Logic unit with >15 methods | warning |
| State Explosion | Logic unit with >10 state fields | warning |
| High Coupling | Component with >7 dependencies | warning |
| Improper Async Pattern | >3 async methods without `AsyncNotifier` | info |
| Logic Leakage | Widget accessing providers >10 times | warning |
| Circular Dependency | Cycle in the dependency graph | error |

**Architecture Health Score**: starts at 100, deducts 2.5 per smell and 5.0 per governance violation.

---

## Architecture Governance

Define contracts in `migrator_config.yaml` at the project root:

```yaml
governance:
  forbidden_imports:
    - presentation -> data
    - ui -> repository
  feature:
    max_dependencies: 8
  architecture:
    max_dependency_depth: 5

provider_naming: camelCase
auto_merge_state: true
```

Run in CI with `--mode safe` — the CLI exits with code 1 when violations are found.

---

## Additional Commands

```bash
# Visualize the dependency graph as a Mermaid diagram
migrator --visualize .

# Emit structured IDE diagnostics (consumed by the VS Code extension)
migrator --ide-json .

# AI-assisted migration guidance (Ollama local LLM, deterministic fallback)
migrator --ai .
```

---

## Safety Systems

Every aggressive migration is fully reversible:

- **Snapshots** — full project backup in `.migrator_snapshots/<timestamp>/` before any rewrite
- **Manifest** — JSON file inventory for reliable per-file rollback
- **Drift tracking** — architecture health baseline in `.migrator_drift/` for sprint-over-sprint trend analysis
- **Dry-run** — `--dry-run` shows exactly what would change before committing

---

## Documentation

- [Migration Guide](MIGRATION_GUIDE.md) — before/after examples for every supported pattern
- [VS Code Extension](vscode-extension/README.md) — inline diagnostics and quick-fix actions
- [Project Plan](Project_Plan.md) — roadmap and technical vision

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) to get started.

## License

MIT — see [LICENSE](LICENSE).

---

Built with ❤️ for the Flutter community.
