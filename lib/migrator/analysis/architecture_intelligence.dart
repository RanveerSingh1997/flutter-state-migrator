import '../models/graph_models.dart';
import '../models/ir_models.dart';

class ArchitectureSmell {
  final String nodeId;
  final String name;
  final String description;
  final String severity; // 'info', 'warning', 'error'

  ArchitectureSmell({
    required this.nodeId,
    required this.name,
    required this.description,
    this.severity = 'warning',
  });
}

class ArchitectureIntelligenceEngine {
  final ArchitectureGraph graph;

  ArchitectureIntelligenceEngine(this.graph);

  List<ArchitectureSmell> analyze() {
    final smells = <ArchitectureSmell>[];

    for (final entry in graph.nodes.entries) {
      final nodeId = entry.key;
      final node = entry.value;

      if (node is LogicUnitNode) {
        smells.addAll(_analyzeLogicUnit(nodeId, node));
      } else if (node is WidgetNode) {
        smells.addAll(_analyzeWidget(nodeId, node));
      }
    }

    smells.addAll(_analyzeGraphMetrics());

    return smells;
  }

  List<ArchitectureSmell> _analyzeLogicUnit(String id, LogicUnitNode node) {
    final unitSmells = <ArchitectureSmell>[];

    // God Component Smell
    if (node.methods.length > 15) {
      unitSmells.add(
        ArchitectureSmell(
          nodeId: id,
          name: 'God Component',
          description:
              'Class ${node.name} has ${node.methods.length} methods. Consider splitting it into smaller, more focused units.',
          severity: 'warning',
        ),
      );
    }

    if (node.stateFields.length > 10) {
      unitSmells.add(
        ArchitectureSmell(
          nodeId: id,
          name: 'State Explosion',
          description:
              'Class ${node.name} manages ${node.stateFields.length} state fields. This may lead to maintenance complexity and unnecessary rebuilds.',
          severity: 'warning',
        ),
      );
    }

    // High Fan-out
    final dependencies = graph.getDependencies(id);
    if (dependencies.length > 7) {
      unitSmells.add(
        ArchitectureSmell(
          nodeId: id,
          name: 'High Coupling',
          description:
              'Class ${node.name} depends on ${dependencies.length} other components. High coupling makes testing and refactoring difficult.',
          severity: 'warning',
        ),
      );
    }

    // Improper Async Pattern
    final asyncMethods = node.methods.where((m) => m.isAsync).length;
    if (asyncMethods > 3 &&
        node.notifierType != NotifierType.asyncNotifier &&
        node.isNotifier) {
      unitSmells.add(
        ArchitectureSmell(
          nodeId: id,
          name: 'Improper Async Pattern',
          description:
              'Class ${node.name} has several async methods but isn\'t an AsyncNotifier. Consider using Riverpod\'s AsyncNotifier for better lifecycle safety.',
          severity: 'info',
        ),
      );
    }

    return unitSmells;
  }

  List<ArchitectureSmell> _analyzeWidget(String id, WidgetNode node) {
    final widgetSmells = <ArchitectureSmell>[];

    // Logic Leakage Smell (Heuristic: usage nodes associated with this widget file)
    final usageNodes = graph.edges
        .where((e) => e.fromId.startsWith('usage:${node.filePath}'))
        .length;

    if (usageNodes > 10) {
      widgetSmells.add(
        ArchitectureSmell(
          nodeId: id,
          name: 'Logic Leakage',
          description:
              'Widget ${node.widgetName} accesses providers $usageNodes times. Consider refactoring UI-coupled logic into a dedicated Controller or ViewModel.',
          severity: 'warning',
        ),
      );
    }

    return widgetSmells;
  }

  List<ArchitectureSmell> _analyzeGraphMetrics() {
    final graphSmells = <ArchitectureSmell>[];

    // Circular Dependencies
    final cycles = graph.findCycles();
    for (final cycle in cycles) {
      graphSmells.add(
        ArchitectureSmell(
          nodeId: cycle.first,
          name: 'Circular Dependency',
          description: 'A dependency cycle detected: ${cycle.join(' → ')}',
          severity: 'error',
        ),
      );
    }

    return graphSmells;
  }
}
