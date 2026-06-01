// ============================================================
// flutter_state_migrator — Example (BEFORE state)
//
// This app is intentionally written with the Provider package so
// you can run the migrator on it and see the automated conversion.
//
// Try it:
//   dart pub global activate flutter_state_migrator
//
//   # Preview changes without writing (dry run)
//   migrator --mode aggressive --dry-run /path/to/this/example
//
//   # Apply the migration
//   migrator --mode aggressive /path/to/this/example
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'counter_notifier.dart';
import 'todo_notifier.dart';
import 'settings_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CounterNotifier()),
        ChangeNotifierProvider(create: (_) => TodoNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Migrator Example',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
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
        title: const Text('Migrator Example'),
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
      body: Column(
        children: [
          const _CounterSection(),
          const Divider(),
          const Expanded(child: _TodoSection()),
        ],
      ),
    );
  }
}

// ── Counter section (reads a ChangeNotifier via context.watch) ───────────────

class _CounterSection extends StatelessWidget {
  const _CounterSection();

  @override
  Widget build(BuildContext context) {
    final count = context.watch<CounterNotifier>().count;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Count: $count',
              style: Theme.of(context).textTheme.headlineMedium),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => context.read<CounterNotifier>().decrement(),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => context.read<CounterNotifier>().increment(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Todo section (uses Consumer + Selector) ──────────────────────────────────

class _TodoSection extends StatelessWidget {
  const _TodoSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<TodoNotifier>(
      builder: (context, notifier, _) {
        if (notifier.todos.isEmpty) {
          return const Center(child: Text('No todos yet.'));
        }
        return ListView.builder(
          itemCount: notifier.todos.length,
          itemBuilder: (context, i) {
            final todo = notifier.todos[i];
            return ListTile(
              title: Text(todo.title),
              leading: Checkbox(
                value: todo.done,
                onChanged: (_) => context.read<TodoNotifier>().toggle(i),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => context.read<TodoNotifier>().remove(i),
              ),
            );
          },
        );
      },
    );
  }
}
