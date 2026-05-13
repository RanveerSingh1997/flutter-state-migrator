import 'ir_models.dart';

enum RelationshipType { provides, watches, reads, creates, navigates, calls }

class DependencyEdge {
  final String fromId;
  final String toId;
  final RelationshipType type;
  final int offset;

  DependencyEdge({
    required this.fromId,
    required this.toId,
    required this.type,
    this.offset = 0,
  });
}

class ArchitectureGraph {
  /// Map of unique component ID to its IR node.
  final Map<String, ProviderNode> nodes = {};

  /// List of semantic relationships.
  final List<DependencyEdge> edges = [];

  void addNode(String id, ProviderNode node) {
    nodes[id] = node;
  }

  void addEdge(DependencyEdge edge) {
    edges.add(edge);
  }

  /// Finds all components that depend on (watch/read) the given node ID.
  List<String> getDependents(String nodeId) {
    return edges
        .where(
          (e) =>
              e.toId == nodeId &&
              (e.type == RelationshipType.watches ||
                  e.type == RelationshipType.reads),
        )
        .map((e) => e.fromId)
        .toList();
  }

  /// Finds all components that the given node ID depends on.
  List<String> getDependencies(String nodeId) {
    return edges.where((e) => e.fromId == nodeId).map((e) => e.toId).toList();
  }

  /// Returns the longest dependency chain reachable from [nodeId].
  int getDependencyDepth(String nodeId) {
    final memo = <String, int>{};

    int dfs(String currentId, Set<String> path) {
      if (path.contains(currentId)) {
        return 0;
      }
      final cached = memo[currentId];
      if (cached != null) {
        return cached;
      }

      final nextPath = {...path, currentId};
      final dependencies = getDependencies(currentId);
      if (dependencies.isEmpty) {
        memo[currentId] = 0;
        return 0;
      }

      final depth = dependencies
          .map((dependency) => 1 + dfs(dependency, nextPath))
          .reduce((a, b) => a > b ? a : b);
      memo[currentId] = depth;
      return depth;
    }

    return dfs(nodeId, const {});
  }

  /// Detects circular dependencies in the graph.
  List<List<String>> findCycles() {
    final cycles = <List<String>>[];
    final visited = <String>{};
    final stack = <String>{};
    final currentPath = <String>[];

    void dfs(String nodeId) {
      visited.add(nodeId);
      stack.add(nodeId);
      currentPath.add(nodeId);

      for (final dependency in getDependencies(nodeId)) {
        if (stack.contains(dependency)) {
          final cycleStart = currentPath.indexOf(dependency);
          if (cycleStart != -1) {
            cycles.add(
              List.from(currentPath.sublist(cycleStart))..add(dependency),
            );
          }
        } else if (!visited.contains(dependency)) {
          dfs(dependency);
        }
      }

      stack.remove(nodeId);
      currentPath.removeLast();
    }

    for (final nodeId in nodes.keys) {
      if (!visited.contains(nodeId)) {
        dfs(nodeId);
      }
    }

    return cycles;
  }
}
