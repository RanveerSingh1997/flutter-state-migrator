import 'dart:io';

import 'package:flutter_state_migrator/migrator/analysis/architecture_intelligence.dart';
import 'package:flutter_state_migrator/migrator/analysis/drift_detector.dart';
import 'package:test/test.dart';

void main() {
  group('ArchitectureDriftDetector', () {
    late Directory tempDir;
    late ArchitectureDriftDetector detector;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('drift_test_');
      detector = ArchitectureDriftDetector(tempDir.path);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('compareWithLatest returns null on first run (no prior snapshot)', () {
      final result = detector.compareWithLatest(
        smells: [],
        violations: [],
        healthScore: 100.0,
      );
      expect(result, isNull);
    });

    test('new smell appears in newSmells after baseline', () {
      detector.saveSnapshot(smells: [], violations: [], healthScore: 100.0);

      final smell = ArchitectureSmell(
        nodeId: 'node1',
        name: 'God Component',
        description: 'Too many methods',
      );
      final report = detector.compareWithLatest(
        smells: [smell],
        violations: [],
        healthScore: 97.5,
      );

      expect(report, isNotNull);
      expect(report!.newSmells, contains('God Component:node1'));
      expect(report.resolvedSmells, isEmpty);
    });

    test('resolved smell appears in resolvedSmells', () {
      final smell = ArchitectureSmell(
        nodeId: 'node1',
        name: 'God Component',
        description: 'Too many methods',
      );
      detector.saveSnapshot(smells: [smell], violations: [], healthScore: 97.5);

      final report = detector.compareWithLatest(
        smells: [],
        violations: [],
        healthScore: 100.0,
      );

      expect(report, isNotNull);
      expect(report!.resolvedSmells, contains('God Component:node1'));
      expect(report.newSmells, isEmpty);
    });

    test('scoreDelta is computed correctly', () {
      detector.saveSnapshot(smells: [], violations: [], healthScore: 80.0);

      final report = detector.compareWithLatest(
        smells: [],
        violations: [],
        healthScore: 90.0,
      );

      expect(report, isNotNull);
      expect(report!.scoreDelta, closeTo(10.0, 0.001));
    });
  });
}
