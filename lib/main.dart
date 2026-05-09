import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'provider_version/todo_provider.dart';

void main() {
  runApp(
    // Wrap with Riverpod's ProviderScope at the root
    riverpod.ProviderScope(child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return // TODO(Migrator): Remove MultiProvider, Riverpod providers are global. Wrap app in ProviderScope.
    // TODO(Migrator): Remove MultiProvider, Riverpod providers are global. Wrap app in ProviderScope.
    MultiProvider(
      providers: [
        // TODO(Migrator): Replace ChangeNotifierProvider with StateNotifierProvider
        // TODO(Migrator): Replace ChangeNotifierProvider with StateNotifierProvider
        // TODO(Migrator): Replace ChangeNotifierProvider with StateNotifierProvider
        ChangeNotifierProvider(create: (_) => TodoProvider()),
      ],
      child: MaterialApp(
        title: 'Flutter State Migrator',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
