import 'ir_models.dart';

/// The semantic type of a relationship between two architecture components.
enum RelationshipType {
  /// A logic unit is exposed through a provider declaration.
  provides,

  /// A consumer reactively watches a provider's state.
  watches,

  /// A consumer imperatively reads a provider's state once.
  reads,

  /// A widget or logic unit instantiates another component.
  creates,

  /// A component triggers navigation to another route or screen.
  navigates,

  /// A component invokes a method on another component.
  calls,
}

/// A directed relationship between two nodes in the [ArchitectureGraph].
class DependencyEdge {
  /// ID of the source component.
  final String fromId;

  /// ID of the target component.
  final String toId;

  /// Semantic type of the dependency.
  final RelationshipType type;

  /// Source offset where the relationship originates.
  final int offset;

  /// Creates a [DependencyEdge] between [fromId] and [toId].
  DependencyEdge({
    required this.fromId,
    required this.toId,
    required this.type,
    this.offset = 0,
  });
}

/// A semantic graph of all detected components and their dependencies.
///
/// Built by [GraphBuilder] from the flat list of [ProviderNode]s emitted by
/// the scanner adapters. Downstream intelligence engines operate on this graph.
class ArchitectureGraph {
  /// Map of unique component ID to its IR node.
  final Map<String, ProviderNode> nodes = {};

  /// List of semantic relationships.
  final List<DependencyEdge> edges = [];

  /// Registers [node] under [id].
  void addNode(String id, ProviderNode node) {
    nodes[id] = node;
  }

  /// Appends [edge] to the graph.
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
  ///
  /// Returns each cycle as an ordered list of node IDs, with the first node
  /// repeated at the end to close the loop.
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
