# Flutter Architecture Intelligence Platform — Migration Guide

This guide documents every pattern the platform detects, how each is transformed,
and what the output looks like in each migration mode.

---

## 1. State Management Migration

### 1.1 Supported Frameworks

| Framework | Detected patterns |
|-----------|------------------|
| **Provider** | `ChangeNotifier`, `ChangeNotifierProvider`, `Consumer`, `MultiProvider`, `Selector`, `ProxyProvider`, `ChangeNotifierProxyProvider`, `FutureProvider`, `StreamProvider`, `ValueNotifier`, `ValueListenableBuilder`, `Provider.of<T>()`, `context.watch<T>()`, `context.read<T>()`, `context.select<T,R>()` |
| **BLoC / Cubit** | `Bloc<Event, State>`, `Cubit<State>`, `BlocProvider`, `RepositoryProvider`, `MultiBlocProvider`, `MultiRepositoryProvider`, `BlocBuilder`, `BlocListener`, `BlocConsumer`, `BlocSelector` |
| **GetX** | `GetxController` (with `.obs` fields), `Get.put()`, `Get.lazyPut()`, `Get.create()`, `Get.find<T>()`, `GetX<T>`, `GetBuilder<T>`, `Obx`, `GetMaterialApp` |
| **MobX** | Classes with `@observable` / `@computed` / `@action` annotations, `Observer` widget |

---

### 1.2 Provider Framework

#### ChangeNotifier → @riverpod Notifier

**Before:**
```dart
class CounterNotifier extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

// Provided via:
ChangeNotifierProvider(create: (_) => CounterNotifier(), child: MyApp())
```

**After (aggressive mode):**
```dart
@riverpod
class CounterNotifier extends _$CounterNotifier {
  @override
  int build() => 0;

  void increment() {
    state = state + 1;
  }
}

// Root becomes:
ProviderScope(child: MyApp())
```

---

#### ProxyProvider / ChangeNotifierProxyProvider → ref.watch in build()

Provider-to-provider dependencies are the most complex pattern to migrate. The tool
detects the dependency and generates a skeleton Notifier that uses `ref.watch`.

**Before:**
```dart
ChangeNotifierProxyProvider<AuthService, UserNotifier>(
  create: (_) => UserNotifier(),
  update: (_, auth, previous) => previous!..updateAuth(auth),
  child: MyApp(),
)
```

**After (aggressive mode — skeleton generated):**
```dart
// ProviderScope replaces the declaration site
ProviderScope(child: MyApp())

// Skeleton appended — fill in the build() body
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  UserNotifier build() {
    final authService = ref.watch(authServiceProvider);
    // TODO: return UserNotifier using authService
    throw UnimplementedError();
  }
}
```

> The `update:` lambda's dependency becomes a `ref.watch()` call.
> Complete the `build()` body manually.

---

#### Selector → ref.watch(.select())

**Before:**
```dart
Selector<CounterNotifier, int>(
  selector: (_, notifier) => notifier.count,
  builder: (context, count, child) => Text('$count'),
)
```

**After:**
```dart
Consumer(
  builder: (context, ref, child) {
    final count = ref.watch(counterNotifierProvider.select((s) => s.count));
    return Text('$count');
  },
)
```

---

#### context.select → ref.watch(.select())

**Before:**
```dart
Widget build(BuildContext context) {
  final count = context.select<CounterNotifier, int>((n) => n.count);
  return Text('$count');
}
```

**After:**
```dart
Widget build(BuildContext context, WidgetRef ref) {
  final count = ref.watch(counterNotifierProvider.select((n) => n.count));
  return Text('$count');
}
```

---

#### context.watch / context.read / Provider.of

**Before:**
```dart
// Reactive (inside build)
final counter = context.watch<CounterNotifier>();
final counter = Provider.of<CounterNotifier>(context);

// Imperative (callbacks / initState)
final counter = context.read<CounterNotifier>();
final counter = Provider.of<CounterNotifier>(context, listen: false);

// Method call (triggers action on notifier)
context.read<CounterNotifier>().increment();
```

**After:**
```dart
// Reactive
final counter = ref.watch(counterNotifierProvider);

// Imperative
final counter = ref.read(counterNotifierProvider);

// Method call
ref.read(counterNotifierProvider.notifier).increment();
```

---

#### ValueNotifier → @riverpod Notifier

**Before:**
```dart
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light);

  void toggle() {
    value = value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

ValueListenableBuilder<ThemeMode>(
  valueListenable: themeNotifier,
  builder: (context, mode, _) => Text(mode.name),
)
```

**After:**
```dart
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;

  void toggle() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

// ValueListenableBuilder → ConsumerWidget
Consumer(
  builder: (context, ref, child) {
    final mode = ref.watch(themeNotifierProvider);
    return Text(mode.name);
  },
)
```

---

#### FutureProvider / StreamProvider

**Before:**
```dart
FutureProvider<List<Todo>>((ref) async {
  return fetchTodos();
})
```

**After:**
```dart
// TODO: Auto-migrated Riverpod FutureProvider
final listProvider = FutureProvider<List<Todo>>((ref) async {
  return /* TODO: Return Future */;
});
```

> Async providers keep their structure; fill in the implementation body.

---

#### MultiProvider → ProviderScope

**Before:**
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => CounterNotifier()),
    ChangeNotifierProvider(create: (_) => ThemeNotifier()),
  ],
  child: MyApp(),
)
```

**After:**
```dart
ProviderScope(child: MyApp())
// Individual providers are now global @riverpod classes — no nesting needed.
```

---

#### Widget upgrades

| Before | After |
|--------|-------|
| `extends StatelessWidget` | `extends ConsumerWidget` |
| `Widget build(BuildContext context)` | `Widget build(BuildContext context, WidgetRef ref)` |
| `extends StatefulWidget` | `extends ConsumerStatefulWidget` |
| `extends State<T>` | `extends ConsumerState<T>` |
| `extends HookWidget` | `extends HookConsumerWidget` |
| `Widget build(BuildContext context)` (in HookWidget) | `Widget build(BuildContext context, WidgetRef ref)` |

---

### 1.3 BLoC / Cubit Framework

#### Cubit → @riverpod Notifier

**Before:**
```dart
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}

BlocProvider(create: (_) => CounterCubit(), child: MyApp())
```

**After:**
```dart
@riverpod
class CounterCubit extends _$CounterCubit {
  @override
  int build() => 0;

  void increment() {
    state = state + 1;
  }

  void decrement() {
    state = state - 1;
  }
}

ProviderScope(child: MyApp())
```

---

#### Bloc<Event, State> → @riverpod AsyncNotifier

**Before:**
```dart
class TodoBloc extends Bloc<TodoEvent, TodoState> {
  TodoBloc() : super(TodoInitial()) {
    on<LoadTodos>((event, emit) async {
      emit(TodoLoading());
      final todos = await repository.fetchTodos();
      emit(TodoLoaded(todos));
    });
  }
}
```

**After (skeleton):**
```dart
@riverpod
class TodoBloc extends _$TodoBloc {
  @override
  Future<TodoState> build() async {
    // TODO: Return initial async state
    return TodoInitial();
  }
}
// Events become methods on the Notifier.
```

---

#### MultiBlocProvider → ProviderScope

**Before:**
```dart
MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => CounterCubit()),
    BlocProvider(create: (_) => TodoBloc()),
  ],
  child: MyApp(),
)
```

**After:**
```dart
ProviderScope(child: MyApp())
```

---

#### BlocBuilder / BlocConsumer / BlocListener → ConsumerWidget

**Before:**
```dart
BlocBuilder<CounterCubit, int>(
  builder: (context, count) => Text('$count'),
)
```

**After:**
```dart
Consumer(
  builder: (context, ref, child) {
    final count = ref.watch(counterCubitProvider);
    return Text('$count');
  },
)
```

---

#### BlocSelector → ref.watch(.select())

**Before:**
```dart
BlocSelector<CounterCubit, CounterState, int>(
  selector: (state) => state.count,
  builder: (context, count) => Text('$count'),
)
```

**After:**
```dart
Consumer(
  builder: (context, ref, child) {
    final count = ref.watch(counterCubitProvider.select((s) => s.count));
    return Text('$count');
  },
)
```

---

### 1.4 GetX Framework

#### GetxController → @riverpod Notifier

**Before:**
```dart
class CounterController extends GetxController {
  RxInt count = 0.obs;

  void increment() => count++;
}

// Registration
Get.put(CounterController());
Get.lazyPut<CounterController>(() => CounterController());
Get.create<CounterController>(() => CounterController());

// Access
Get.find<CounterController>().increment();
```

**After:**
```dart
@riverpod
class CounterController extends _$CounterController {
  @override
  int build() => 0;

  void increment() {
    state = state + 1;
  }
}

// All registration variants map to a global @riverpod provider.
// Access via:
ref.read(counterControllerProvider.notifier).increment();
```

---

#### GetX / GetBuilder / Obx → ConsumerWidget

**Before:**
```dart
GetX<CounterController>(
  builder: (controller) => Text('${controller.count}'),
)

Obx(() => Text('${controller.count}'))
```

**After:**
```dart
Consumer(
  builder: (context, ref, child) {
    final count = ref.watch(counterControllerProvider);
    return Text('$count');
  },
)
```

---

### 1.5 MobX Framework

#### Store with @observable / @computed → @riverpod Notifier

**Before:**
```dart
class CartStore = _CartStore with _$CartStore;

abstract class _CartStore with Store {
  @observable
  List<Item> items = [];

  @computed
  int get totalCount => items.length;

  @action
  void addItem(Item item) {
    items.add(item);
  }
}
```

**After:**
```dart
@riverpod
class CartStore extends _$CartStore {
  @override
  CartStoreState build() => CartStoreState(items: const []);

  void addItem(Item item) {
    state = state.copyWith(items: [...state.items, item]);
  }
}

// @computed becomes a derived ref.watch() or .select() call at the consumer site
final totalCount = ref.watch(cartStoreProvider.select((s) => s.items.length));
```

> Both `@observable` and `@computed` fields are captured.
> `@observable` fields become `StateNotifier` state; `@computed` fields become `select()` calls at the widget.

---

#### Observer → ConsumerWidget

**Before:**
```dart
Observer(
  builder: (_) => Text('${store.totalCount}'),
)
```

**After:**
```dart
Consumer(
  builder: (context, ref, child) {
    final total = ref.watch(cartStoreProvider.select((s) => s.items.length));
    return Text('$total');
  },
)
```

---

## 2. Architecture Intelligence

The platform builds a typed semantic graph after scanning and runs smell detection on every component.

### 2.1 Detected Smells

| Smell | Threshold | Severity | Remediation |
|-------|-----------|----------|-------------|
| **God Component** | >15 methods on a logic unit | warning | Split into focused Notifiers |
| **State Explosion** | >10 state fields on a logic unit | warning | Group into a state model, use `copyWith` |
| **High Coupling** | >7 outgoing dependencies | warning | Extract collaborators behind a boundary provider |
| **Improper Async Pattern** | >3 async methods but not `AsyncNotifier` | info | Promote to `AsyncNotifier` |
| **Logic Leakage** | Widget accesses providers >10 times | warning | Move logic to a dedicated ViewModel Notifier |
| **Circular Dependency** | Cycle detected in the dependency graph | error | Introduce abstraction or event boundary |

### 2.2 Architecture Health Score

```
Score = 100 − (smells × 2.5) − (governance_violations × 5.0)
```

Minimum score: 0. Tracked over time via drift snapshots in `.migrator_drift/`.

---

## 3. Migration Modes

| Mode | Flag | Effect |
|------|------|--------|
| **Safe** | `--mode safe` | Injects `// TODO(Migrator):` comments at source offsets; no rewrites |
| **Assisted** | `--mode assisted` | Writes `*_riverpod.dart` side-files with Riverpod equivalents alongside originals |
| **Aggressive** | `--mode aggressive` | Rewrites source files in-place using offset-safe `TextEdit` operations |

Always use `--dry-run` first with aggressive mode to preview the diff without writing:

```bash
migrator --mode aggressive --dry-run /path/to/project
```

A full snapshot is taken before any aggressive rewrite and stored in `.migrator_snapshots/`.
Roll back at any time:

```bash
migrator --rollback /path/to/project
```

---

## 4. Architecture Governance

Define contracts in `migrator_config.yaml` at the project root:

```yaml
# Naming convention for generated providers
provider_naming: camelCase   # or snake_case

# Merge multi-field state into a single state class automatically
auto_merge_state: true

governance:
  # Forbidden layer dependencies
  forbidden_imports:
    - presentation -> data
    - ui -> repository

  feature:
    max_dependencies: 8         # Max outgoing deps per component

  architecture:
    max_dependency_depth: 5     # Max depth of the dependency chain

# Override architecture role inference for specific class suffixes
architecture_roles:
  ViewModel: presentation
  UseCase: domain
```

Run governance checks in CI:

```bash
migrator --mode safe /path/to/project
# Exit code 1 when governance violations are found
```

---

## 5. Architecture Visualization

```bash
migrator --visualize /path/to/project
```

Writes `architecture_graph.mmd` — a Mermaid `graph TD` diagram. Paste it into any
Mermaid renderer or the GitHub Markdown preview to see:

- **Purple nodes**: Logic units (Notifiers, Services, Repositories)
- **Blue nodes**: Widgets
- **Orange nodes**: Provider declarations
- **Labelled edges**: WATCHES, READS, PROVIDES, CALLS

---

## 6. IDE Diagnostics

```bash
migrator --ide-json /path/to/project
```

Emits `ide_diagnostics.json` consumed by the VS Code companion extension.
Each diagnostic carries:

```json
{
  "filePath": "lib/counter/counter_notifier.dart",
  "startLine": 12,
  "startColumn": 2,
  "severity": "warning",
  "code": "god-component",
  "category": "architecture",
  "message": "CounterNotifier has 18 methods. Consider splitting.",
  "quickFixes": [
    { "title": "Migrate this file", "command": "migrator.migrateFile" }
  ]
}
```

---

## 7. AI-Assisted Guidance

```bash
migrator --ai /path/to/project
```

`AIManager` sends prompts to a local [Ollama](https://ollama.ai) endpoint
(`http://localhost:11434/api/generate`, model `llama3.1`). When the model is
unavailable, all guidance is generated deterministically from the semantic graph —
**no internet connection is required**.

Each piece of guidance covers:
- **Logic refactoring**: How to rewrite a specific mutable method for Riverpod.
- **Architecture smells**: Root cause and smallest safe remediation step.
- **Governance violations**: Which contract is breached and how to fix it.

---

## 8. Monorepo Support

The platform auto-discovers Dart packages within a workspace:

```bash
migrator --mode aggressive /path/to/monorepo/root
```

Each package is scanned independently. Only packages whose source files contain
detectable patterns are migrated; others are skipped automatically.

---

## 9. Safety Systems

| System | Storage | Purpose |
|--------|---------|---------|
| **Snapshot** | `.migrator_snapshots/<timestamp>/` | Full project backup before aggressive mode |
| **Manifest** | `.migrator_snapshots/<timestamp>/manifest.json` | File inventory for reliable rollback |
| **Drift** | `.migrator_drift/snapshot.json` | Architecture health baseline for trend tracking |
| **Generated file cleanup** | — | Detects stale `*.g.dart` files after source renames |
