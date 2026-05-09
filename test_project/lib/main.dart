import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'counter_model.dart';

void main() {
  runApp(
    const MyApp(),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Consumer(
            builder: (context, ref, child) => ref.watch(countermodelProvider.select((_, model) => model.count)) Text('$count'),
          ),
        ),
      ),
    );
  }
}

// TODO: Auto-migrated Riverpod Provider
final countermodelProvider = StateNotifierProvider<CounterModelNotifier, CounterModelState>((ref) {
  return CounterModelNotifier();
});
