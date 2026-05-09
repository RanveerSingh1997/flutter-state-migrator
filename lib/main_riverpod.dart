// 🚀 Auto-generated Riverpod migration suggestions for main.dart
// You can use these snippets to replace your Provider logic.

// 🔄 Suggestion: Replace ChangeNotifierProvider with StateNotifierProvider
final todoproviderProvider =
    StateNotifierProvider<TodoProviderNotifier, TodoProviderState>((ref) {
      return TodoProviderNotifier();
    });
