# Flutter Architecture Intelligence Platform — Technical Guide

This guide explains how the platform analyzes, modernizes, and governs Flutter application architectures.

## 1. State Management Migration (Provider/BLoC/GetX/MobX → Riverpod)

The platform uses AST-based transformation to convert legacy patterns into idiomatic Riverpod code using `@riverpod` annotations.

### 1.1 Logic Units
Logic classes (ChangeNotifiers, Cubits, Controllers, Stores) are mapped to Riverpod `Notifier` or `AsyncNotifier` classes.

**Standard Mapping:**
- `notifyListeners()` (Provider) → `state = state.copyWith(...)`
- `emit(newState)` (BLoC) → `state = newState`
- `.obs` (GetX) → Immutable state updates
- `@observable` (MobX) → Immutable state fields

### 1.2 Widget Consumption
- `StatelessWidget` → `ConsumerWidget`
- `StatefulWidget` → `ConsumerStatefulWidget`
- `Provider.of<T>(context)` → `ref.watch(tProvider)`
- `context.read<T>()` → `ref.read(tProvider)`
- `Selector<T, R>` → `ref.watch(tProvider.select((s) => s.property))`

---

## 2. Architecture Intelligence

The platform builds a semantic dependency graph to detect "Architecture Smells" that impact long-term maintainability.

### 2.1 Detected Smells
- **God Component**: Classes with >15 methods.
- **State Explosion**: Logic units with >10 state fields.
- **High Coupling**: Components with >7 outgoing dependencies.
- **Logic Leakage**: UI widgets containing excessive business logic or provider access.
- **Improper Async Pattern**: Logic units with heavy async usage that should be migrated to `AsyncNotifier`.
- **Circular Dependency**: Two or more components depending on each other in a loop.

---

## 3. Architecture Governance

Teams can enforce structural constraints via `migrator_config.yaml`.

### 3.1 Layer Isolation
Prevent invalid dependencies between architectural layers.
```yaml
governance:
  forbidden_imports:
    - presentation -> data
    - ui -> repository
```

### 3.2 Complexity Limits
```yaml
governance:
  feature:
    max_dependencies: 8
  architecture:
    max_dependency_depth: 5
```

---

## 4. Production Readiness

### 4.1 Architecture Health Score
A real-time score (0-100) is calculated for the project. 
- **100**: Perfect architectural integrity.
- **Deductions**: Applied for each smell (-2.5 pts) and governance violation (-5.0 pts).

### 4.2 Drift Detection
The platform compares current analysis against historical snapshots to identify architectural degradation over time (e.g., "Health decreased by 4.2 points in this sprint").

---

## 5. Visual Intelligence
Run `migrator --visualize .` to generate a `architecture_graph.mmd` file, which can be rendered as a Mermaid diagram to visualize component relationships and roles (Services, Repositories, Providers, Widgets).
