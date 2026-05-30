/// Architecture governance rule enforcement.
library;

import '../models/graph_models.dart';
import '../models/ir_models.dart';

/// A breach of a configurable architecture contract.
class GovernanceViolation {
  /// ID of the offending component in the [ArchitectureGraph].
  final String nodeId;

  /// Name of the rule that was broken, e.g. `'Forbidden Dependency'`.
  final String ruleName;

  /// Human-readable description of the breach.
  final String message;

  /// Severity level: `'warning'` or `'error'`.
  final String severity;

  /// Creates a [GovernanceViolation] for [nodeId].
  GovernanceViolation({
    required this.nodeId,
    required this.ruleName,
    required this.message,
    this.severity = 'error',
  });
}

/// Validates an [ArchitectureGraph] against configurable architecture contracts.
///
/// Contracts are sourced from `migrator_config.yaml` under the `governance:` key.
/// Supported rules: forbidden layer dependencies, max dependency fan-out,
/// and max dependency depth.
class GovernanceEngine {
  /// The graph to validate.
  final ArchitectureGraph graph;

  /// Parsed `governance:` section from `migrator_config.yaml`.
  final Map<String, dynamic> config;

  /// Creates an engine that validates [graph] against [config].
  GovernanceEngine(this.graph, this.config);

  /// Runs all configured governance rules and returns every violation found.
  List<GovernanceViolation> validate() {
    final violations = <GovernanceViolation>[];

    // 1. Forbidden Dependencies (Layer Isolation)
    final forbiddenImports = config['forbidden_imports'] as List?;
    if (forbiddenImports != null) {
      violations.addAll(_checkForbiddenDependencies(forbiddenImports));
    }

    // 2. Max Dependencies per Feature/Component
    final maxDependencies = config['feature']?['max_dependencies'] as int?;
    if (maxDependencies != null) {
      violations.addAll(_checkMaxDependencies(maxDependencies));
    }

    // 3. Max Dependency Depth
    final maxDepth = config['architecture']?['max_dependency_depth'] as int?;
    if (maxDepth != null) {
      violations.addAll(_checkMaxDependencyDepth(maxDepth));
    }

    return violations;
  }

  List<GovernanceViolation> _checkForbiddenDependencies(List forbidden) {
    final violations = <GovernanceViolation>[];
    for (final rule in forbidden) {
      if (rule is! String) continue;
      final parts = rule.split('->').map((p) => p.trim()).toList();
      if (parts.length != 2) continue;

      final fromRole = parts[0];
      final toRole = parts[1];

      for (final edge in graph.edges) {
        final fromNode = graph.nodes[edge.fromId];
        final toNode = graph.nodes[edge.toId];

        if (fromNode is LogicUnitNode && toNode is LogicUnitNode) {
          if (fromNode.role == fromRole && toNode.role == toRole) {
            violations.add(
              GovernanceViolation(
                nodeId: edge.fromId,
                ruleName: 'Forbidden Dependency',
                message:
                    'Architecture violation: Layer "$fromRole" is not allowed to depend on "$toRole". '
                    'Found dependency: ${fromNode.name} -> ${toNode.name}',
              ),
            );
          }
        }
      }
    }
    return violations;
  }

  List<GovernanceViolation> _checkMaxDependencies(int limit) {
    final violations = <GovernanceViolation>[];
    for (final entry in graph.nodes.entries) {
      final nodeId = entry.key;
      final node = entry.value;

      if (node is LogicUnitNode) {
        final deps = graph.getDependencies(nodeId);
        if (deps.length > limit) {
          violations.add(
            GovernanceViolation(
              nodeId: nodeId,
              ruleName: 'Max Dependencies Exceeded',
              message:
                  'Class ${node.name} has ${deps.length} dependencies, exceeding the limit of $limit.',
              severity: 'warning',
            ),
          );
        }
      }
    }
    return violations;
  }

  List<GovernanceViolation> _checkMaxDependencyDepth(int limit) {
    final violations = <GovernanceViolation>[];
    for (final entry in graph.nodes.entries) {
      final nodeId = entry.key;
      final node = entry.value;

      if (node is LogicUnitNode) {
        final depth = graph.getDependencyDepth(nodeId);
        if (depth > limit) {
          violations.add(
            GovernanceViolation(
              nodeId: nodeId,
              ruleName: 'Max Dependency Depth Exceeded',
              message:
                  'Class ${node.name} has a dependency depth of $depth, exceeding the limit of $limit. '
                  'Deep dependency chains increase instability and make testing harder.',
              severity: 'warning',
            ),
          );
        }
      }
    }
    return violations;
  }
}
