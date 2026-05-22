import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import 'home_screen.dart';
import 'todo_screen.dart';

// Provider for the app's GoRouter configuration.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/todo', builder: (context, state) => const TodoScreen()),
    ],
  );
});

// Theme mode provider – toggles between light and dark mode.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// Helper widget to toggle theme mode from the UI.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return IconButton(
      icon: Icon(mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
      onPressed: () {
        ref.read(themeModeProvider.notifier).state = mode == ThemeMode.dark
            ? ThemeMode.light
            : ThemeMode.dark;
      },
    );
  }
}
