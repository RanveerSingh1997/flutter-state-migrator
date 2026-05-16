// Fixture: edge cases for migration testing — generics, mixins, multiple providers.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ── Generic StateNotifier ─────────────────────────────────────────────────

class ListNotifier<T> extends ChangeNotifier {
  List<T> _items = [];

  List<T> get items => _items;

  void add(T item) {
    _items = [..._items, item];
    notifyListeners();
  }

  void remove(T item) {
    _items = _items.where((e) => e != item).toList();
    notifyListeners();
  }
}

// ── Mixin usage ───────────────────────────────────────────────────────────

mixin LoggingMixin on ChangeNotifier {
  void log(String message) {
    debugPrint('[LOG] $message');
  }
}

class TodoNotifier extends ChangeNotifier with LoggingMixin {
  final List<String> _todos = [];

  List<String> get todos => List.unmodifiable(_todos);

  void addTodo(String todo) {
    _todos.add(todo);
    log('Added: $todo');
    notifyListeners();
  }

  void removeTodo(String todo) {
    _todos.remove(todo);
    log('Removed: $todo');
    notifyListeners();
  }
}

// ── Multiple constructor parameters (family candidate) ────────────────────

class PaginatedNotifier extends ChangeNotifier {
  final String category;
  final int pageSize;
  int _page = 0;
  List<String> _items = [];

  PaginatedNotifier({required this.category, this.pageSize = 20});

  List<String> get items => _items;
  int get page => _page;

  Future<void> loadNextPage() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _page++;
    _items = List.generate(pageSize, (i) => '$category item ${_page * pageSize + i}');
    notifyListeners();
  }
}

// ── Widget accessing multiple providers ───────────────────────────────────

class MultiProviderWidget extends StatelessWidget {
  const MultiProviderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final todos = context.watch<TodoNotifier>().todos;
    final paginated = context.watch<PaginatedNotifier>();
    return Column(
      children: [
        Text('Todos: ${todos.length}'),
        Text('Page: ${paginated.page}'),
        ElevatedButton(
          onPressed: () => context.read<TodoNotifier>().addTodo('New'),
          child: const Text('Add'),
        ),
        ElevatedButton(
          onPressed: () => context.read<PaginatedNotifier>().loadNextPage(),
          child: const Text('Load more'),
        ),
      ],
    );
  }
}
