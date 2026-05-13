import 'dart:io';

import '../models/graph_models.dart';
import '../models/ir_models.dart';

class ProviderVisualizer {
  String generateMermaid(ArchitectureGraph graph) {
    final buffer = StringBuffer();
    buffer.writeln('graph TD');

    // 1. Define nodes with semantic labels
    for (final entry in graph.nodes.entries) {
      final id = _escape(entry.key);
      final node = entry.value;

      if (node is LogicUnitNode) {
        final role = node.role.toUpperCase();
        buffer.writeln('  $id["$role: ${node.name}"]');
      } else if (node is WidgetNode) {
        buffer.writeln('  $id["WIDGET: ${node.widgetName}"]');
      } else if (node is ProviderDeclarationNode) {
        buffer.writeln('  $id{{"PROVIDER: ${node.providerType}"}}');
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

  String _escape(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }
}
