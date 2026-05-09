import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'counter_model.dart';

void main() {
  runApp(
    /* TODO: Replace with Riverpod ProviderScope and global provider:
final countermodelProvider = StateNotifierProvider<CounterModelNotifier, CounterModelState>((ref) {
  return CounterModelNotifier();
});
Original Provider:
ChangeNotifierProvider(
      create: (context) => CounterModel(),
      child: const MyApp(),
    )
*/,
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
              Consumer<CounterModel>(
                builder: (context, counter, child) {
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
