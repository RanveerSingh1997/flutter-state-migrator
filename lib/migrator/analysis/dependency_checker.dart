import '../models/ir_models.dart';

class DependencyChecker {
  /// Builds a provider→consumers graph and detects cycles via DFS.
  /// Returns a list of human-readable warning strings for each cycle found.
  List<String> checkCircularDependencies(List<ProviderNode> nodes) {
    // Map: provider class name → set of classes it reads/watches
    final graph = <String, Set<String>>{};

    // Every LogicUnit is a node in the graph
    for (final node in nodes) {
      if (node is LogicUnitNode) {
        graph.putIfAbsent(node.name, () => {});
      }
    }

    // ProviderOf / ProviderDeclaration edges: widget or logic unit → consumed class
    // We associate each ProviderOfNode with the LogicUnit whose filePath matches
    final fileToLogicUnit = <String, String>{};
    for (final node in nodes) {
      if (node is LogicUnitNode) {
        fileToLogicUnit[node.filePath] = node.name;
      }
    }

    for (final node in nodes) {
      if (node is ProviderOfNode) {
        final owner = fileToLogicUnit[node.filePath];
        if (owner != null && owner != node.consumedClass) {
          graph.putIfAbsent(owner, () => {}).add(node.consumedClass);
        }
      } else if (node is ProviderDeclarationNode) {
        final owner = fileToLogicUnit[node.filePath];
        if (owner != null && owner != node.providedClass) {
          graph.putIfAbsent(owner, () => {}).add(node.providedClass);
        }
      }
    }

    // DFS cycle detection
    final warnings = <String>[];
    final visited = <String>{};
    final inStack = <String>{};

    void dfs(String current, List<String> path) {
      visited.add(current);
      inStack.add(current);

      for (final neighbor in graph[current] ?? <String>{}) {
        if (!visited.contains(neighbor)) {
          dfs(neighbor, [...path, current]);
        } else if (inStack.contains(neighbor)) {
          final cycleStart = path.indexOf(neighbor);
          final cycle = cycleStart >= 0
              ? [...path.sublist(cycleStart), current, neighbor]
              : [...path, current, neighbor];
          warnings.add(
            '⚠️  Circular dependency detected: ${cycle.join(' → ')}',
          );
        }
      }

      inStack.remove(current);
    }

    for (final node in graph.keys) {
      if (!visited.contains(node)) {
        dfs(node, []);
      }
    }

    return warnings;
  }
}
