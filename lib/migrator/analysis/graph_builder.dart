import '../models/ir_models.dart';
import '../models/graph_models.dart';

class GraphBuilder {
  ArchitectureGraph buildGraph(List<ProviderNode> nodes) {
    final graph = ArchitectureGraph();

    // 1. Map component names to their LogicUnitNode IDs for resolution
    final logicUnitMap = <String, String>{};
    final ownerNodesByFile = <String, List<ProviderNode>>{};
    for (final node in nodes) {
      final id = _generateId(node);
      graph.addNode(id, node);
      if (node is LogicUnitNode) {
        logicUnitMap[node.name] = id;
      }
      if (_isOwnerNode(node)) {
        ownerNodesByFile.putIfAbsent(node.filePath, () => []).add(node);
      }
    }

    // 2. Establish relationships (edges)
    for (final node in nodes) {
      final fromId = _generateId(node);

      if (node is ProviderDeclarationNode) {
        // Logic class (providedClass) -> Provider declaration
        final targetId = logicUnitMap[node.providedClass] ?? node.providedClass;
        graph.addEdge(
          DependencyEdge(
            fromId: targetId,
            toId: fromId,
            type: RelationshipType.provides,
            offset: node.offset,
          ),
        );
      } else if (node is ProviderOfNode) {
        // Consumer -> Logic class
        final targetId = logicUnitMap[node.consumedClass] ?? node.consumedClass;
        final sourceId = _resolveOwnerId(node, ownerNodesByFile);
        graph.addEdge(
          DependencyEdge(
            fromId: sourceId ?? fromId,
            toId: targetId,
            type: node.isInBuildMethod
                ? RelationshipType.watches
                : RelationshipType.reads,
            offset: node.offset,
          ),
        );
      } else if (node is ConsumerNode) {
        // Widget/Consumer -> Logic class
        final targetId = logicUnitMap[node.consumedClass] ?? node.consumedClass;
        final sourceId = _resolveOwnerId(node, ownerNodesByFile);
        graph.addEdge(
          DependencyEdge(
            fromId: sourceId ?? fromId,
            toId: targetId,
            type: RelationshipType.watches,
            offset: node.offset,
          ),
        );
      } else if (node is SelectorNode) {
        final targetId = logicUnitMap[node.consumedClass] ?? node.consumedClass;
        final sourceId = _resolveOwnerId(node, ownerNodesByFile);
        graph.addEdge(
          DependencyEdge(
            fromId: sourceId ?? fromId,
            toId: targetId,
            type: RelationshipType.watches,
            offset: node.offset,
          ),
        );
      } else if (node is LogicUnitNode) {
        // Inheritance relationship
        if (node.superClassName != null) {
          final targetId =
              logicUnitMap[node.superClassName!] ?? node.superClassName!;
          graph.addEdge(
            DependencyEdge(
              fromId: fromId,
              toId: targetId,
              type: RelationshipType
                  .calls, // Represents dependency via inheritance/usage
            ),
          );
        }
      }
    }

    return graph;
  }

  String _generateId(ProviderNode node) {
    if (node is LogicUnitNode) return 'logic:${node.name}';
    if (node is WidgetNode) return 'widget:${node.widgetName}';
    if (node is StateNode) return 'state:${node.stateClassName}';
    if (node is HookWidgetNode) return 'hook:${node.widgetName}';

    // For anonymous or usage nodes, use file path + offset to guarantee uniqueness
    return 'usage:${node.filePath}:${node.offset}';
  }

  bool _isOwnerNode(ProviderNode node) {
    return node is LogicUnitNode ||
        node is WidgetNode ||
        node is StateNode ||
        node is HookWidgetNode;
  }

  String? _resolveOwnerId(
    ProviderNode usageNode,
    Map<String, List<ProviderNode>> ownerNodesByFile,
  ) {
    final owners = ownerNodesByFile[usageNode.filePath];
    if (owners == null || owners.isEmpty) {
      return null;
    }

    ProviderNode? bestMatch;
    for (final owner in owners) {
      final ownerStart = owner.offset;
      final ownerEnd = owner.offset + owner.length;
      final usageEnd = usageNode.offset + usageNode.length;
      final containsUsage =
          ownerStart <= usageNode.offset && ownerEnd >= usageEnd;
      if (!containsUsage) {
        continue;
      }

      if (bestMatch == null || owner.length < bestMatch.length) {
        bestMatch = owner;
      }
    }

    return bestMatch == null ? null : _generateId(bestMatch);
  }
}
