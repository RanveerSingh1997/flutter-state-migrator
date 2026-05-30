/// Structured IDE diagnostics and quick-fix actions for the VS Code extension.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';

import '../models/graph_models.dart';
import '../models/ir_models.dart';
import 'architecture_intelligence.dart';
import 'governance_engine.dart';

/// A quick-fix action surfaced alongside an [IdeDiagnostic] in the VS Code extension.
class IdeQuickFix {
  /// Human-readable label shown in the editor lightbulb menu.
  final String title;

  /// VS Code command identifier that executes the fix.
  final String command;
  /// VS Code code-action kind, e.g. `'quickfix'` or `'refactor'`.
  final String kind;

  /// Optional detail message shown in the action description.
  final String? message;

  /// Creates an [IdeQuickFix].
  const IdeQuickFix({
    required this.title,
    required this.command,
    required this.kind,
    this.message,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'command': command,
    'kind': kind,
    if (message != null) 'message': message,
  };
}

/// A structured diagnostic emitted by [IdeIntelligenceEngine] for the VS Code extension.
///
/// Carries source range, severity, category, message, and optional quick-fixes.
class IdeDiagnostic {
  /// Absolute path to the file this diagnostic belongs to.
  final String filePath;

  /// 0-based line number where the diagnostic starts.
  final int startLine;

  /// 0-based column number where the diagnostic starts.
  final int startColumn;

  /// 0-based line number where the diagnostic ends.
  final int endLine;

  /// 0-based column number where the diagnostic ends.
  final int endColumn;

  /// Diagnostic severity string: `'error'`, `'warning'`, or `'information'`.
  final String severity;

  /// Short machine-readable code identifying the rule, e.g. `'god-component'`.
  final String code;

  /// Publisher string shown in the VS Code Problems panel, e.g. `'flutter_state_migrator'`.
  final String source;

  /// High-level category: `'architecture'` or `'governance'`.
  final String category;

  /// Human-readable description displayed in the editor.
  final String message;

  /// Stable component ID from the [ArchitectureGraph] this diagnostic belongs to.
  final String nodeId;

  /// Optional list of code actions the editor can offer.
  final List<IdeQuickFix> quickFixes;

  /// Creates an [IdeDiagnostic].
  const IdeDiagnostic({
    required this.filePath,
    required this.startLine,
    required this.startColumn,
    required this.endLine,
    required this.endColumn,
    required this.severity,
    required this.code,
    required this.source,
    required this.category,
    required this.message,
    required this.nodeId,
    this.quickFixes = const [],
  });

  /// Serialises this diagnostic to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'startLine': startLine,
    'startColumn': startColumn,
    'endLine': endLine,
    'endColumn': endColumn,
    'severity': severity,
    'code': code,
    'source': source,
    'category': category,
    'message': message,
    'nodeId': nodeId,
    'quickFixes': quickFixes.map((fix) => fix.toJson()).toList(),
  };
}

/// Full diagnostic payload produced by [IdeIntelligenceEngine.buildReport].
///
/// Serialises to the JSON format consumed by the VS Code companion extension.
class IdeAnalysisReport {
  /// Absolute path to the scanned project directory.
  final String targetPath;

  /// Total number of diagnostics across all categories.
  final int totalDiagnostics;

  /// Number of diagnostics in the `'architecture'` category.
  final int architectureDiagnosticCount;

  /// Number of diagnostics in the `'governance'` category.
  final int governanceDiagnosticCount;

  /// Flat list of all [IdeDiagnostic]s.
  final List<IdeDiagnostic> diagnostics;

  /// Creates an [IdeAnalysisReport].
  const IdeAnalysisReport({
    required this.targetPath,
    required this.totalDiagnostics,
    required this.architectureDiagnosticCount,
    required this.governanceDiagnosticCount,
    required this.diagnostics,
  });

  /// Serialises this report to the JSON payload consumed by the VS Code extension.
  Map<String, dynamic> toJson() => {
    'targetPath': targetPath,
    'summary': {
      'totalDiagnostics': totalDiagnostics,
      'architectureDiagnosticCount': architectureDiagnosticCount,
      'governanceDiagnosticCount': governanceDiagnosticCount,
    },
    'diagnostics': diagnostics
        .map((diagnostic) => diagnostic.toJson())
        .toList(),
  };
}

/// Converts [ArchitectureSmell]s and [GovernanceViolation]s into structured
/// [IdeDiagnostic]s with source ranges and quick-fix actions.
///
/// Output is consumed by the `--ide-json` CLI flag and the VS Code extension.
class IdeIntelligenceEngine {
  /// Absolute path to the project root, used to resolve file-relative offsets.
  final String targetPath;

  final Map<String, _FileLineLookup> _lineLookups = {};

  /// Creates an [IdeIntelligenceEngine] for the project at [targetPath].
  IdeIntelligenceEngine(this.targetPath);

  /// Builds an [IdeAnalysisReport] from the supplied [graph], [smells], and [violations].
  IdeAnalysisReport buildReport({
    required ArchitectureGraph graph,
    required List<ArchitectureSmell> smells,
    required List<GovernanceViolation> violations,
  }) {
    final diagnostics =
        <IdeDiagnostic>[
          ...smells
              .map((smell) => _fromSmell(graph, smell))
              .whereType<IdeDiagnostic>(),
          ...violations
              .map((violation) => _fromViolation(graph, violation))
              .whereType<IdeDiagnostic>(),
        ]..sort((a, b) {
          final fileCompare = a.filePath.compareTo(b.filePath);
          if (fileCompare != 0) return fileCompare;
          final lineCompare = a.startLine.compareTo(b.startLine);
          if (lineCompare != 0) return lineCompare;
          return a.startColumn.compareTo(b.startColumn);
        });

    return IdeAnalysisReport(
      targetPath: targetPath,
      totalDiagnostics: diagnostics.length,
      architectureDiagnosticCount: diagnostics
          .where((diagnostic) => diagnostic.category == 'architecture')
          .length,
      governanceDiagnosticCount: diagnostics
          .where((diagnostic) => diagnostic.category == 'governance')
          .length,
      diagnostics: diagnostics,
    );
  }

  IdeDiagnostic? _fromSmell(ArchitectureGraph graph, ArchitectureSmell smell) {
    final node = graph.nodes[smell.nodeId];
    if (node == null) return null;
    final location = _resolveLocation(node);

    return IdeDiagnostic(
      filePath: location.filePath,
      startLine: location.startLine,
      startColumn: location.startColumn,
      endLine: location.endLine,
      endColumn: location.endColumn,
      severity: smell.severity,
      code: smell.name,
      source: 'flutter-migrator',
      category: 'architecture',
      message: smell.description,
      nodeId: smell.nodeId,
      quickFixes: _quickFixesForSmell(smell, node),
    );
  }

  IdeDiagnostic? _fromViolation(
    ArchitectureGraph graph,
    GovernanceViolation violation,
  ) {
    final node = graph.nodes[violation.nodeId];
    if (node == null) return null;
    final location = _resolveLocation(node);

    return IdeDiagnostic(
      filePath: location.filePath,
      startLine: location.startLine,
      startColumn: location.startColumn,
      endLine: location.endLine,
      endColumn: location.endColumn,
      severity: violation.severity,
      code: violation.ruleName,
      source: 'flutter-migrator',
      category: 'governance',
      message: violation.message,
      nodeId: violation.nodeId,
      quickFixes: _quickFixesForViolation(violation, node),
    );
  }

  List<IdeQuickFix> _quickFixesForSmell(
    ArchitectureSmell smell,
    ProviderNode node,
  ) {
    return [
      IdeQuickFix(
        title: _smellFixTitle(smell.name),
        command: 'flutter-migrator.showRecommendation',
        kind: 'guidance',
        message: _smellRecommendation(smell),
      ),
      if (_isFileScoped(node))
        const IdeQuickFix(
          title: 'Run migration for this file',
          command: 'flutter-migrator.migrateFile',
          kind: 'refactor',
        ),
      const IdeQuickFix(
        title: 'Open migration guide',
        command: 'flutter-migrator.openMigrationGuide',
        kind: 'documentation',
      ),
    ];
  }

  List<IdeQuickFix> _quickFixesForViolation(
    GovernanceViolation violation,
    ProviderNode node,
  ) {
    return [
      IdeQuickFix(
        title: 'Show governance recommendation',
        command: 'flutter-migrator.showRecommendation',
        kind: 'guidance',
        message:
            '${violation.message} Review architecture contracts before accepting further changes.',
      ),
      if (_isFileScoped(node))
        const IdeQuickFix(
          title: 'Run migration for this file',
          command: 'flutter-migrator.migrateFile',
          kind: 'refactor',
        ),
      const IdeQuickFix(
        title: 'Run migration for the project',
        command: 'flutter-migrator.migrateProject',
        kind: 'refactor',
      ),
    ];
  }

  bool _isFileScoped(ProviderNode node) => node.filePath.isNotEmpty;

  String _smellFixTitle(String smellName) {
    switch (smellName) {
      case 'God Component':
        return 'Show component-splitting recommendation';
      case 'State Explosion':
        return 'Show state consolidation recommendation';
      case 'High Coupling':
        return 'Show dependency-reduction recommendation';
      case 'Improper Async Pattern':
        return 'Show AsyncNotifier recommendation';
      case 'Circular Dependency':
        return 'Show cycle-breaking recommendation';
      default:
        return 'Show architecture recommendation';
    }
  }

  String _smellRecommendation(ArchitectureSmell smell) {
    switch (smell.name) {
      case 'God Component':
        return 'Split this class into smaller logic units and move unrelated responsibilities into dedicated services or notifiers.';
      case 'State Explosion':
        return 'Group related fields into cohesive state models so rebuilds and copyWith transitions stay manageable.';
      case 'High Coupling':
        return 'Introduce interfaces or boundaries to reduce the number of direct dependencies owned by this component.';
      case 'Improper Async Pattern':
        return 'Promote this logic to AsyncNotifier or isolate loading/error states so async transitions remain explicit.';
      case 'Circular Dependency':
        return 'Break the cycle by introducing an abstraction, event boundary, or orchestration layer between the two components.';
      default:
        return smell.description;
    }
  }

  _ResolvedLocation _resolveLocation(ProviderNode node) {
    final lookup = _lineLookups.putIfAbsent(
      node.filePath,
      () => _FileLineLookup.forPath(node.filePath),
    );
    return lookup.resolve(node.offset, node.length);
  }
}

class _ResolvedLocation {
  final String filePath;
  final int startLine;
  final int startColumn;
  final int endLine;
  final int endColumn;

  const _ResolvedLocation({
    required this.filePath,
    required this.startLine,
    required this.startColumn,
    required this.endLine,
    required this.endColumn,
  });
}

class _FileLineLookup {
  final String filePath;
  final List<int> lineStarts;

  const _FileLineLookup({required this.filePath, required this.lineStarts});

  factory _FileLineLookup.forPath(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return _FileLineLookup(filePath: filePath, lineStarts: const [0]);
    }

    final result = parseString(
      content: file.readAsStringSync(),
      path: filePath,
      throwIfDiagnostics: false,
    );
    return _FileLineLookup(
      filePath: filePath,
      lineStarts: result.lineInfo.lineStarts,
    );
  }

  _ResolvedLocation resolve(int offset, int length) {
    final start = _offsetToLineColumn(offset);
    final safeLength = length <= 0 ? 1 : length;
    final end = _offsetToLineColumn(offset + safeLength);

    return _ResolvedLocation(
      filePath: filePath,
      startLine: start.$1,
      startColumn: start.$2,
      endLine: end.$1,
      endColumn: end.$2,
    );
  }

  (int, int) _offsetToLineColumn(int offset) {
    if (lineStarts.isEmpty) return (1, 1);

    var low = 0;
    var high = lineStarts.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final current = lineStarts[mid];
      if (current == offset) {
        return (mid + 1, 1);
      }
      if (current < offset) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    final lineIndex = high < 0 ? 0 : high;
    final lineStart = lineStarts[lineIndex];
    return (lineIndex + 1, (offset - lineStart) + 1);
  }
}
