import 'package:flutter/material.dart';
import 'counter_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(countermodelProvider);
    return MaterialApp(
      home: Scaffold(body: Center(child: Text('Count: ${counter.count}'))),
    );
  }
}

// TODO: Auto-migrated Riverpod Provider
final countermodelProvider =
    StateNotifierProvider<CounterModelNotifier, CounterModelState>((ref) {
      return CounterModelNotifier();
    });
