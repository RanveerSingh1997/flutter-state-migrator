import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'todo_provider.dart';

class ProviderTodoScreen extends StatelessWidget {
  const ProviderTodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Provider Todo List')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    decoration: const InputDecoration(labelText: 'New Todo'),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        // TODO(Migrator): Replace with ref.read or ref.watch
// TODO(Migrator): Replace with ref.read or ref.watch
// TODO(Migrator): Replace with ref.read or ref.watch
context.read<TodoProvider>().addTodo(value);
                        textController.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (textController.text.isNotEmpty) {
                      // TODO(Migrator): Replace with ref.read or ref.watch
// TODO(Migrator): Replace with ref.read or ref.watch
// TODO(Migrator): Replace with ref.read or ref.watch
context.read<TodoProvider>().addTodo(textController.text);
                      textController.clear();
                    }
                  },
                )
              ],
            ),
          ),
          Expanded(
            child: // TODO(Migrator): Change to ConsumerWidget and use ref.watch
// TODO(Migrator): Change to ConsumerWidget and use ref.watch
// TODO(Migrator): Change to ConsumerWidget and use ref.watch
Consumer<TodoProvider>(
              builder: (context, provider, child) {
                return ListView.builder(
                  itemCount: provider.todos.length,
                  itemBuilder: (context, index) {
                    final todo = provider.todos[index];
                    return ListTile(
                      title: Text(
                        todo.title,
                        style: TextStyle(
                          decoration: todo.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      leading: Checkbox(
                        value: todo.isCompleted,
                        onChanged: (_) {
                          provider.toggleTodo(todo.id);
                        },
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          provider.removeTodo(todo.id);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
