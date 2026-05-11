// Fixture: realistic GetX controller app for migration testing.
import 'package:get/get.dart';

// ── Simple counter ─────────────────────────────────────────────────────────

class CounterController extends GetxController {
  final count = 0.obs;
  final label = 'counter'.obs;
  final loading = false.obs;

  void increment() => count.value++;

  void decrement() => count.value--;

  void reset() {
    count.value = 0;
    label.value = 'reset';
  }

  void addMany(int delta) => count.value += delta;

  Future<void> loadFromApi() async {
    loading.value = true;
    await Future.delayed(const Duration(milliseconds: 100));
    count.value = 42;
    loading.value = false;
  }
}

// ── Profile controller ─────────────────────────────────────────────────────

class ProfileController extends GetxController {
  final name = ''.obs;
  final age = 0.obs;
  final verified = false.obs;

  void updateName(String newName) => name.value = newName;

  void setAge(int newAge) => age.value = newAge;

  void verify() => verified.value = true;

  Future<void> fetchProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    name.value = 'User $userId';
    age.value = 25;
    verified.value = true;
  }
}
