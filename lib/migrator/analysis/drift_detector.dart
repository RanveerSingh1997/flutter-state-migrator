/// Architecture health drift detection via snapshot comparison.
library;

import 'dart:convert';
import 'dart:io';

import 'architecture_intelligence.dart';
import 'governance_engine.dart';

/// A point-in-time record of architecture health used as a drift baseline.
class DriftSnapshot {
  /// When the snapshot was taken.
  final DateTime timestamp;

  /// Stable `'name:nodeId'` fingerprints for each detected smell.
  final List<String> smellFingerprints;

  /// Stable `'ruleName:nodeId'` fingerprints for each governance violation.
  final List<String> violationFingerprints;
  final double healthScore;

  /// Creates a [DriftSnapshot].
  DriftSnapshot({
    required this.timestamp,
    required this.smellFingerprints,
    required this.violationFingerprints,
    required this.healthScore,
  });

  /// Deserialises a [DriftSnapshot] from [json].
  factory DriftSnapshot.fromJson(Map<String, dynamic> json) => DriftSnapshot(
    timestamp: DateTime.parse(json['timestamp'] as String),
    smellFingerprints: List<String>.from(json['smellFingerprints'] as List),
    violationFingerprints: List<String>.from(
      json['violationFingerprints'] as List,
    ),
    healthScore: (json['healthScore'] as num).toDouble(),
  );

  /// Serialises this snapshot to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'smellFingerprints': smellFingerprints,
    'violationFingerprints': violationFingerprints,
    'healthScore': healthScore,
  };
}

/// The difference between the current analysis and a prior [DriftSnapshot].
class DriftReport {
  /// Smells that are new since the baseline snapshot.
  final List<String> newSmells;

  /// Smells that have been resolved since the baseline snapshot.
  final List<String> resolvedSmells;

  /// Governance violations that are new since the baseline snapshot.
  final List<String> newViolations;

  /// Governance violations that have been resolved since the baseline snapshot.
  final List<String> resolvedViolations;

  /// Change in Architecture Health Score (positive = improvement).
  final double scoreDelta;

  /// Timestamp of the prior snapshot this report was compared against.
  final DateTime comparedAt;

  /// Creates a [DriftReport].
  DriftReport({
    required this.newSmells,
    required this.resolvedSmells,
    required this.newViolations,
    required this.resolvedViolations,
    required this.scoreDelta,
    required this.comparedAt,
  });

  /// True when any smells or violations changed since the prior snapshot.
  bool get hasChanges =>
      newSmells.isNotEmpty ||
      resolvedSmells.isNotEmpty ||
      newViolations.isNotEmpty ||
      resolvedViolations.isNotEmpty;
}

/// Tracks architectural health trends by comparing analysis results against
/// saved snapshots stored in `.migrator_drift/`.
class ArchitectureDriftDetector {
  /// Absolute path to the project root where `.migrator_drift/` is written.
  final String projectRoot;
  static const String _driftDir = '.migrator_drift';
  static const String _snapshotFile = 'snapshot.json';

  /// Creates a detector for the project at [projectRoot].
  ArchitectureDriftDetector(this.projectRoot);

  /// Returns null on the first run (no prior snapshot to compare against).
  DriftReport? compareWithLatest({
    required List<ArchitectureSmell> smells,
    required List<GovernanceViolation> violations,
    required double healthScore,
  }) {
    final prior = _loadSnapshot();
    if (prior == null) return null;

    final currentSmells = _smellFingerprints(smells);
    final currentViolations = _violationFingerprints(violations);
    final priorSmells = prior.smellFingerprints.toSet();
    final priorViolations = prior.violationFingerprints.toSet();

    return DriftReport(
      newSmells: currentSmells.difference(priorSmells).toList()..sort(),
      resolvedSmells: priorSmells.difference(currentSmells).toList()..sort(),
      newViolations: currentViolations.difference(priorViolations).toList()
        ..sort(),
      resolvedViolations: priorViolations.difference(currentViolations).toList()
        ..sort(),
      scoreDelta: healthScore - prior.healthScore,
      comparedAt: prior.timestamp,
    );
  }

  /// Persists the current analysis results as the new baseline snapshot.
  void saveSnapshot({
    required List<ArchitectureSmell> smells,
    required List<GovernanceViolation> violations,
    required double healthScore,
  }) {
    final dir = Directory('$projectRoot/$_driftDir');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final snapshot = DriftSnapshot(
      timestamp: DateTime.now(),
      smellFingerprints: _smellFingerprints(smells).toList()..sort(),
      violationFingerprints: _violationFingerprints(violations).toList()
        ..sort(),
      healthScore: healthScore,
    );

    File('${dir.path}/$_snapshotFile').writeAsStringSync(
      JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
    );
  }

  DriftSnapshot? _loadSnapshot() {
    final file = File('$projectRoot/$_driftDir/$_snapshotFile');
    if (!file.existsSync()) return null;
    try {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return DriftSnapshot.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Set<String> _smellFingerprints(List<ArchitectureSmell> smells) {
    return smells.map((s) => '${s.name}:${s.nodeId}').toSet();
  }

  Set<String> _violationFingerprints(List<GovernanceViolation> violations) {
    return violations.map((v) => '${v.ruleName}:${v.nodeId}').toSet();
  }
}
