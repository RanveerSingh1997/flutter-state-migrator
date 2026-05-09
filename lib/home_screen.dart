import 'package:flutter/material.dart';
import 'provider_version/provider_todo_screen.dart';
import 'riverpod_version/riverpod_todo_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('State Migrator Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProviderTodoScreen()),
                );
              },
              child: const Text('Open Provider Implementation'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RiverpodTodoScreen()),
                );
              },
              child: const Text('Open Riverpod Implementation'),
            ),
          ],
        ),
      ),
    );
  }
}
