# Technical Migration Guide

This guide explains the technical mapping used by the **Flutter State Migrator** to transform legacy state management patterns into modern Riverpod code.

## 1. Logic Units (ChangeNotifier / Cubit / Bloc)

The migrator transforms logic classes into **Riverpod Notifiers**.

### Provider (ChangeNotifier)
**Before:**
```dart
class CounterModel extends ChangeNotifier {
  int _count = 0;
  void increment() {
    _count++;
    notifyListeners();
  }
}
```

**After:**
```dart
@riverpod
class CounterModelNotifier extends _$CounterModelNotifier {
  @override
  CounterModelState build() => CounterModelState();

  void increment() {
    // state = ... refactoring hint
  }
}
```

### BLoC / Cubit
**Before:**
```dart
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
}
```

**After:**
```dart
@riverpod
class CounterCubitNotifier extends _$CounterCubitNotifier {
  @override
  int build() => 0;

  void increment() {
    // state = ... refactoring hint
  }
}
```

---

## 2. Widgets & Consumption

The migrator transforms your widget tree to use Riverpod's `WidgetRef`.

### StatelessWidget -> ConsumerWidget
**Before:**
```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = Provider.of<CounterModel>(context).count;
    return Text('$count');
  }
}
```

**After:**
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterModelProvider).count;
    return Text('$count');
  }
}
```

### Selector -> ref.watch(select)
The migrator intelligently converts `Selector` widgets into granular Riverpod watches:
```dart
final count = ref.watch(counterModelProvider.select((s) => s.count));
```

---

## 3. Dependency Injection

### MultiProvider -> ProviderScope
Legacy `MultiProvider` setups are replaced by a single global `ProviderScope` at the root of your application, as Riverpod providers are global by design.

---

## 4. Testing

Automated migration of `testWidgets` includes injecting `ProviderScope` into the `pumpWidget` call:

**Before:**
```dart
await tester.pumpWidget(MaterialApp(home: MyWidget()));
```

**After:**
```dart
await tester.pumpWidget(ProviderScope(child: MaterialApp(home: MyWidget())));
```
