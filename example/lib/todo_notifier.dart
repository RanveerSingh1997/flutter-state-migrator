import 'package:flutter/foundation.dart';

class Todo {
  final String title;
  final bool done;

  const Todo({required this.title, this.done = false});

  Todo copyWith({String? title, bool? done}) =>
      Todo(title: title ?? this.title, done: done ?? this.done);
}

class TodoNotifier extends ChangeNotifier {
  final List<Todo> _todos = [
    const Todo(title: 'Install flutter_state_migrator'),
    const Todo(title: 'Run: migrator --mode aggressive --dry-run .'),
    const Todo(title: 'Review the generated Riverpod code'),
    const Todo(title: 'Apply the migration'),
  ];

  List<Todo> get todos => List.unmodifiable(_todos);

  int get completedCount => _todos.where((t) => t.done).length;

  void add(String title) {
    _todos.add(Todo(title: title));
    notifyListeners();
  }

  void toggle(int index) {
    _todos[index] = _todos[index].copyWith(done: !_todos[index].done);
    notifyListeners();
  }

  void remove(int index) {
    _todos.removeAt(index);
    notifyListeners();
  }
}
