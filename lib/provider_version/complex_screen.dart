import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'todo_provider.dart';

class ComplexScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return // TODO(Migrator): Remove MultiProvider, Riverpod providers are global. Wrap app in ProviderScope.
    // TODO(Migrator): Remove MultiProvider, Riverpod providers are global. Wrap app in ProviderScope.
    MultiProvider(
      providers: [
        // TODO(Migrator): Replace ChangeNotifierProvider with StateNotifierProvider
        // TODO(Migrator): Replace ChangeNotifierProvider with StateNotifierProvider
        ChangeNotifierProvider(create: (_) => TodoProvider()),
      ],
      child: Scaffold(
        body: // TODO(Migrator): Replace Selector with ref.watch(todoproviderProvider.select(...))
            // TODO(Migrator): Replace Selector with ref.watch(todoproviderProvider.select(...))
            Selector<TodoProvider, int>(
              selector: (_, provider) => provider.todos.length,
              builder: (_, count, __) {
                return Text('Total todos: $count');
              },
            ),
      ),
    );
  }
}
