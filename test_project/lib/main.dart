import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'counter_model.dart';

void main() {
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello'))),
    );
  }
}

// TODO: Auto-migrated Riverpod Provider
final countermodelProvider =
    StateNotifierProvider<CounterModelNotifier, CounterModelState>((ref) {
      return CounterModelNotifier();
    });
