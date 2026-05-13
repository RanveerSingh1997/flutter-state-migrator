import '../models/graph_models.dart';
import '../models/ir_models.dart';

class DependencyChecker {
  /// Detects circular dependencies in the architecture graph.
  /// Returns a list of human-readable warning strings.
  List<String> checkCircularDependencies(ArchitectureGraph graph) {
    final cycles = graph.findCycles();
    return cycles.map((cycle) {
      final labels = cycle
          .map((nodeId) => _displayName(graph, nodeId))
          .toList();
      return '⚠️  Circular dependency detected: ${labels.join(' → ')}';
    }).toList();
  }

  String _displayName(ArchitectureGraph graph, String nodeId) {
    final node = graph.nodes[nodeId];
    if (node is LogicUnitNode) {
      return node.name;
    }
    if (node is WidgetNode) {
      return node.widgetName;
    }
    if (node is StateNode) {
      return node.stateClassName;
    }
    if (node is HookWidgetNode) {
      return node.widgetName;
    }
    return nodeId.contains(':') ? nodeId.split(':').last : nodeId;
  }
}
