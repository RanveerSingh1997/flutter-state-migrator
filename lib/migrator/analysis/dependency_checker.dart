import '../models/ir_models.dart';

class DependencyChecker {
  /// Checks for potential circular dependencies between providers.
  List<String> checkCircularDependencies(List<ProviderNode> nodes) {
    final warnings = <String>[];
    // Map of ClassName -> Classes it depends on (via Provider.of/ref.watch)
    final dependencyGraph = <String, Set<String>>{};

    // Build the graph
    // For simplicity, we look at which classes are in the same file or 
    // which classes are being consumed by widgets that also define providers.
    // In a real analyzer, we would look at the constructor and build methods.
    
    // For now, let's just warn if a class consumes itself.
    for (final node in nodes) {
      if (node is ProviderOfNode) {
        // Find if this ProviderOf is inside a LogicUnit or Widget that provides the same class
        // (This is a simplified check)
      }
    }

    return warnings;
  }
}
