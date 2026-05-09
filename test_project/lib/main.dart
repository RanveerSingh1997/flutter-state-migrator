import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'counter_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Advanced Provider Test App')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Count via Selector:'),
              Consumer(
                builder: (context, ref, child) {
                  final count = ref.watch(
                    countermodelProvider.select((_, model) => model.count),
                  );
                  return Text(
                    '$count',
                    style: Theme.of(context).textTheme.headlineMedium,
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text('Future Data:'),
              Consumer(
                builder: (context, ref, child) {
                  final data = ref.watch(stringProvider);
                  return Text(data);
                },
              ),
              ElevatedButton(
                onPressed: () {
                  ref.read(countermodelProvider).increment();
                },
                child: const Text('Increment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// TODO: Auto-migrated Riverpod FutureProvider
final stringProvider = FutureProvider<String>((ref) {
  return /* TODO: Return Future */;
});

// TODO: Auto-migrated Riverpod Provider
final countermodelProvider =
    StateNotifierProvider<CounterModelNotifier, CounterModelState>((ref) {
      return CounterModelNotifier();
    });
