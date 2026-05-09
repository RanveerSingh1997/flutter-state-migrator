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
        appBar: AppBar(title: const Text('Provider Test App')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('You have pushed the button this many times:'),
              Consumer(
                builder: (context, ref, child) {
    final counter = ref.watch(countermodelProvider);
                  return Text(
                    '${counter.count}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  );
                },
              ),
              ElevatedButton(
                onPressed: () {
                  ref.read(countermodelProvider).increment();
                },
                child: const Text('Increment using Provider.of'),
              ),
              ElevatedButton(
                onPressed: () {
                  ref.read(countermodelProvider.notifier).increment();
                },
                child: const Text('Increment using context.read'),
              ),
            ],
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
