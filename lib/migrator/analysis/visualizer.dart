import 'dart:io';

import '../models/graph_models.dart';
import '../models/ir_models.dart';

class GraphVisualizationSnapshot {
  final String mermaid;
  final int nodeCount;
  final int edgeCount;
  final int cycleCount;
  final int logicUnitCount;
  final int widgetCount;

  const GraphVisualizationSnapshot({
    required this.mermaid,
    required this.nodeCount,
    required this.edgeCount,
    required this.cycleCount,
    required this.logicUnitCount,
    required this.widgetCount,
  });
}

class ProviderVisualizer {
  GraphVisualizationSnapshot createSnapshot(ArchitectureGraph graph) {
    return GraphVisualizationSnapshot(
      mermaid: generateMermaid(graph),
      nodeCount: graph.nodes.length,
      edgeCount: graph.edges.length,
      cycleCount: graph.findCycles().length,
      logicUnitCount: graph.nodes.values.whereType<LogicUnitNode>().length,
      widgetCount: graph.nodes.values.whereType<WidgetNode>().length,
    );
  }

  String generateMermaid(ArchitectureGraph graph) {
    final buffer = StringBuffer();
    buffer.writeln('graph TD');
    buffer.writeln('  %% Legend');
    buffer.writeln('  classDef logic fill:#673ab7,stroke:#9575cd,color:#fff');
    buffer.writeln('  classDef widget fill:#1565c0,stroke:#64b5f6,color:#fff');
    buffer.writeln(
      '  classDef provider fill:#ef6c00,stroke:#ffb74d,color:#fff',
    );
    buffer.writeln('  classDef usage fill:#37474f,stroke:#90a4ae,color:#fff');

    // 1. Define nodes with semantic labels
    for (final entry in graph.nodes.entries) {
      final id = _escape(entry.key);
      final node = entry.value;

      if (node is LogicUnitNode) {
        final role = node.role.toUpperCase();
        buffer.writeln('  $id["$role: ${node.name}"]');
        buffer.writeln('  class $id logic');
      } else if (node is WidgetNode) {
        buffer.writeln('  $id["WIDGET: ${node.widgetName}"]');
        buffer.writeln('  class $id widget');
      } else if (node is ProviderDeclarationNode) {
        buffer.writeln('  $id{{"PROVIDER: ${node.providerType}"}}');
        buffer.writeln('  class $id provider');
      } else {
        buffer.writeln('  $id["${_describeNode(node)}"]');
        buffer.writeln('  class $id usage');
      }
    }

    // 2. Define edges
    for (final edge in graph.edges) {
      final from = _escape(edge.fromId);
      final to = _escape(edge.toId);
      switch (edge.type) {
        case RelationshipType.watches:
          buffer.writeln('  $to -.->|WATCHES| $from');
          break;
        case RelationshipType.reads:
          buffer.writeln('  $to -.->|READS| $from');
          break;
        case RelationshipType.provides:
          buffer.writeln('  $from ===>|PROVIDES| $to');
          break;
        case RelationshipType.calls:
          buffer.writeln('  $from -->|CALLS| $to');
          break;
        default:
          buffer.writeln('  $from --> $to');
      }
    }

    return buffer.toString();
  }

  void saveGraph(String targetPath, String content) {
    final file = File('$targetPath/architecture_graph.mmd');
    file.writeAsStringSync(content);
    print('🎨 Architecture graph saved to: \x1B[33m${file.path}\x1B[0m');
  }

  String describeSummary(ArchitectureGraph graph) {
    final snapshot = createSnapshot(graph);
    return 'nodes=${snapshot.nodeCount}, edges=${snapshot.edgeCount}, '
        'logic_units=${snapshot.logicUnitCount}, widgets=${snapshot.widgetCount}, '
        'cycles=${snapshot.cycleCount}';
  }

  String _describeNode(ProviderNode node) {
    if (node is StateNode) return 'STATE: ${node.stateClassName}';
    if (node is HookWidgetNode) return 'HOOK: ${node.widgetName}';
    if (node is ConsumerNode) return 'CONSUMER: ${node.consumedClass}';
    if (node is SelectorNode) return 'SELECTOR: ${node.consumedClass}';
    if (node is AsyncProviderNode) return 'ASYNC: ${node.providerType}';
    return node.runtimeType.toString();
  }

  String _escape(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }
}
