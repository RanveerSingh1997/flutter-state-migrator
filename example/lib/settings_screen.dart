import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'counter_notifier.dart';
import 'todo_notifier.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // context.select — migrates to ref.watch(provider.select(...))
    final completedCount =
        context.select<TodoNotifier, int>((n) => n.completedCount);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Completed todos: $completedCount'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset counter'),
              // context.read — migrates to ref.read(provider.notifier).reset()
              onPressed: () => context.read<CounterNotifier>().reset(),
            ),
          ],
        ),
      ),
    );
  }
}
