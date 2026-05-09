import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'counter_model.dart';
import 'settings_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => CounterModel())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Provider Migration Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: Consumer<CounterModel>(
          builder: (context, counter, child) => Text(
            'Count: ${counter.count}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Provider.of<CounterModel>(context, listen: false).increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
