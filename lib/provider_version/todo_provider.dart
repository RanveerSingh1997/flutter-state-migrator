import 'package:flutter/material.dart';
import '../models/todo.dart';
import 'dart:math';

// TODO(Migrator): Convert TodoProvider to StateNotifier
// TODO(Migrator): Convert TodoProvider to StateNotifier
// TODO(Migrator): Convert TodoProvider to StateNotifier
class TodoProvider extends ChangeNotifier {
  List<Todo> _todos = [];

  List<Todo> get todos => _todos;

  void addTodo(String title) {
    _todos.add(Todo(id: Random().nextDouble().toString(), title: title));
    notifyListeners();
  }

  void toggleTodo(String id) {
    _todos = _todos.map((todo) {
      if (todo.id == id) {
        return todo.copyWith(isCompleted: !todo.isCompleted);
      }
      return todo;
    }).toList();
    notifyListeners();
  }

  void removeTodo(String id) {
    _todos.removeWhere((todo) => todo.id == id);
    notifyListeners();
  }
}
