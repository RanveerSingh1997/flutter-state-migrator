// Fixture: realistic MobX store app for migration testing.
import 'package:mobx/mobx.dart';

part 'mobx_counter.g.dart';

// ── Simple counter store ───────────────────────────────────────────────────

class CounterStore = _CounterStore with _$CounterStore;

abstract class _CounterStore with Store {
  @observable
  int count = 0;

  @observable
  String label = 'counter';

  @observable
  bool loading = false;

  @action
  void increment() => count++;

  @action
  void decrement() => count--;

  @action
  void reset() {
    count = 0;
    label = 'reset';
  }

  @action
  void addMany(int delta) => count += delta;

  @action
  Future<void> loadFromApi() async {
    loading = true;
    await Future.delayed(const Duration(milliseconds: 100));
    count = 42;
    loading = false;
  }
}

// ── Profile store ──────────────────────────────────────────────────────────

class ProfileStore = _ProfileStore with _$ProfileStore;

abstract class _ProfileStore with Store {
  @observable
  String name = '';

  @observable
  int age = 0;

  @observable
  bool verified = false;

  @action
  void updateName(String newName) => name = newName;

  @action
  void setAge(int newAge) => age = newAge;

  @action
  void verify() => verified = true;

  @action
  Future<void> fetchProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    name = 'User $userId';
    age = 25;
    verified = true;
  }
}
