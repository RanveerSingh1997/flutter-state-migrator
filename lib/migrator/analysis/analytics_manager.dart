/// Architecture Health Score computation and migration analytics.
library;

import '../models/ir_models.dart';
import 'architecture_intelligence.dart';
import 'governance_engine.dart';

/// Computes migration and architecture-health metrics from scanned nodes.
///
/// Produces the Architecture Health Score (0–100), estimated time saved,
/// and other summary statistics surfaced in the interactive dashboard.
class AnalyticsManager {
  /// Calculates migration and health metrics from [nodes], [smells], and [violations].
  ///
  /// [partialMigrations] is the count of files that received TODO placeholders
  /// or UnimplementedError stubs — used to compute an honest success ratio.
  ///
  /// Returns a map with keys: `logic_units_migrated`, `methods_transformed`,
  /// `files_processed`, `estimated_hours_saved`, `boilerplate_reduction_percent`,
  /// `architecture_health_score`, `smells_count`, `violations_count`,
  /// and `migration_success_ratio`.
  Map<String, dynamic> calculateMetrics({
    required List<ProviderNode> nodes,
    required int filesProcessed,
    List<ArchitectureSmell> smells = const [],
    List<GovernanceViolation> violations = const [],
    int partialMigrations = 0,
  }) {
    final logicUnits = nodes.whereType<LogicUnitNode>().length;
    final totalMethods = nodes.whereType<LogicUnitNode>().fold(
      0,
      (sum, node) => sum + node.methods.length,
    );

    // Estimation: 2h per logic unit, 30m per method.
    final estimatedHoursSaved = (logicUnits * 2) + (totalMethods * 0.5);

    // Architecture Health Score — severity-weighted deductions.
    // error smells (e.g. circular dependency) deduct more than info smells.
    double healthScore = 100.0;
    for (final smell in smells) {
      healthScore -= switch (smell.severity) {
        'error' => 10.0,
        'warning' => 2.5,
        _ => 1.0,
      };
    }
    for (final violation in violations) {
      healthScore -= switch (violation.severity) {
        'error' => 8.0,
        _ => 3.0,
      };
    }
    if (healthScore < 0) healthScore = 0.0;

    // Honest migration success ratio — partial migrations count against it.
    final successRatio = filesProcessed > 0
        ? ((filesProcessed - partialMigrations) / filesProcessed)
            .clamp(0.0, 1.0)
        : 1.0;

    return {
      'logic_units_migrated': logicUnits,
      'methods_transformed': totalMethods,
      'files_processed': filesProcessed,
      'estimated_hours_saved': estimatedHoursSaved,
      'boilerplate_reduction_percent':
          (successRatio * 0.15 * 100).toStringAsFixed(1),
      'architecture_health_score': healthScore.toStringAsFixed(1),
      'smells_count': smells.length,
      'violations_count': violations.length,
      'migration_success_ratio': double.parse(successRatio.toStringAsFixed(2)),
    };
  }
}
