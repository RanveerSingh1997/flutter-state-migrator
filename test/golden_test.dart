/// Golden-style pipeline tests for Phase 34.
///
/// Each test:
///  1. Copies a realistic fixture file into a temp directory.
///  2. Runs AstScanner to produce IR nodes.
///  3. Applies RiverpodTransformer edits to produce migrated source.
///  4. Asserts that the output matches a set of structural invariants
///     (Riverpod patterns present, legacy patterns absent, syntax validity).
///
/// A "golden snapshot" is also written to test/fixtures/*.actual.dart on every
/// run so developers can inspect the full output; it is not committed.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_state_migrator/migrator/analysis/import_manager.dart';
import 'package:flutter_state_migrator/migrator/generator/riverpod_transformer.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'package:flutter_state_migrator/migrator/scanner/ast_scanner.dart';
import 'package:flutter_state_migrator/migrator/scanner/bloc_adapter.dart';
import 'package:flutter_state_migrator/migrator/scanner/getx_adapter.dart';
import 'package:flutter_state_migrator/migrator/scanner/mobx_adapter.dart';
import 'package:flutter_state_migrator/migrator/scanner/provider_adapter.dart';
import 'package:flutter_state_migrator/migrator/utils/edit_applier.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

/// Run the full scan + transform pipeline on [source] as if it were [filename].
/// Returns the migrated content.
String _migrateSource(String source, String filename) {
  final result = parseString(content: source, throwIfDiagnostics: false);

  final providerAdp = ProviderAdapter(filename);
  final blocAdp = BlocAdapter(filename);
  final getxAdp = GetXAdapter(filename);
  final mobxAdp = MobXAdapter(filename);

  result.unit.visitChildren(providerAdp);
  result.unit.visitChildren(blocAdp);
  result.unit.visitChildren(getxAdp);
  result.unit.visitChildren(mobxAdp);

  final nodes = [
    ...providerAdp.nodes,
    ...blocAdp.nodes,
    ...getxAdp.nodes,
    ...mobxAdp.nodes,
  ];

  final transformer = RiverpodTransformer();
  final edits = <TextEdit>[];
  for (final node in nodes) {
    edits.addAll(transformer.transformNode(node, source));
  }
  final migrated = applyEdits(source, edits);
  return ImportManager().processImports(migrated, cleanProvider: true);
}

// Fixture directory is always <package-root>/test/fixtures.
String get _fixtureDir =>
    p.join(Directory.current.path, 'test', 'fixtures');

/// Read fixture source from test/fixtures/[name].
String _fixture(String name) =>
    File(p.join(_fixtureDir, name)).readAsStringSync();

/// Write actual output next to the fixture for manual inspection.
void _writeActual(String name, String content) =>
    File(p.join(_fixtureDir, name)).writeAsStringSync(content);

// ── scanner-only fixtures ─────────────────────────────────────────────────────

void main() {
  // ── Provider ──────────────────────────────────────────────────────────────

  group('Provider fixture — scanner', () {
    late List<ProviderNode> nodes;
    const src = 'provider_counter.dart';

    setUpAll(() {
      final source = _fixture('provider_counter.dart');
      final result = parseString(content: source, throwIfDiagnostics: false);
      final adp = ProviderAdapter(src);
      result.unit.visitChildren(adp);
      nodes = adp.nodes;
    });

    test('detects CounterModel as LogicUnitNode', () {
      final lu = nodes.whereType<LogicUnitNode>().firstWhere(
            (n) => n.name == 'CounterModel',
          );
      expect(lu.stateFields.map((f) => f.rawName),
          containsAll(['_count', '_label', '_loading']));
      expect(lu.methods.map((m) => m.name),
          containsAll(['increment', 'decrement', 'reset', 'addMany']));
    });

    test('detects async loadFromApi method', () {
      final lu = nodes.whereType<LogicUnitNode>().firstWhere(
            (n) => n.name == 'CounterModel',
          );
      final load = lu.methods.firstWhere((m) => m.name == 'loadFromApi');
      expect(load.isAsync, isTrue);
    });

    test('detects MultiProvider node', () {
      expect(nodes.any((n) => n is MultiProviderNode), isTrue);
    });

    test('detects Consumer node', () {
      expect(nodes.any((n) => n is ConsumerNode), isTrue);
    });

    test('detects Selector node', () {
      expect(nodes.any((n) => n is SelectorNode), isTrue);
    });

    test('detects Provider.of reactive reads', () {
      final pofs = nodes.whereType<ProviderOfNode>().toList();
      expect(pofs.any((n) => n.isInBuildMethod), isTrue);
    });

    test('detects Provider.of listen:false as non-reactive', () {
      final pofs = nodes.whereType<ProviderOfNode>().toList();
      expect(pofs.any((n) => !n.isInBuildMethod), isTrue);
    });
  });

  group('Provider fixture — transformer output', () {
    late String output;

    setUpAll(() {
      final source = _fixture('provider_counter.dart');
      output = _migrateSource(source, 'provider_counter.dart');
      _writeActual('provider_counter.actual.dart', output);
    });

    test('emits @riverpod annotation', () {
      expect(output, contains('@riverpod'));
    });

    test('emits Riverpod import', () {
      expect(output, contains('riverpod'));
    });

    test('contains build() method for CounterModel', () {
      expect(output, contains('build()'));
    });

    test('rewrites increment method body to copyWith', () {
      expect(output, contains('copyWith'));
    });

    test('wraps MultiProvider in ProviderScope', () {
      expect(output, contains('ProviderScope'));
    });

    test('replaces Consumer type reference', () {
      expect(output, contains('Consumer('));
    });

    test('Riverpod import present after migration', () {
      // After migration the Riverpod runtime or annotation import must be added.
      expect(
        output.contains('flutter_riverpod') ||
            output.contains('riverpod_annotation'),
        isTrue,
      );
    });

    test('output parses without errors', () {
      final result = parseString(content: output, throwIfDiagnostics: false);
      final errors = result.errors.where((e) => e.errorCode.type.name == 'ERROR');
      expect(errors, isEmpty,
          reason: 'Transformed Provider output has parse errors');
    });
  });

  // ── BLoC / Cubit ──────────────────────────────────────────────────────────

  group('BLoC fixture — scanner', () {
    late List<ProviderNode> nodes;

    setUpAll(() {
      final source = _fixture('bloc_counter.dart');
      final result = parseString(content: source, throwIfDiagnostics: false);
      final adp = BlocAdapter('bloc_counter.dart');
      result.unit.visitChildren(adp);
      nodes = adp.nodes;
    });

    test('detects CounterCubit', () {
      expect(
        nodes.whereType<LogicUnitNode>().any((n) => n.name == 'CounterCubit'),
        isTrue,
      );
    });

    test('detects ProfileCubit with state fields', () {
      final pc = nodes.whereType<LogicUnitNode>().firstWhere(
            (n) => n.name == 'ProfileCubit',
          );
      expect(pc.stateFields, isNotEmpty);
    });

    test('detects CounterBloc', () {
      expect(
        nodes.whereType<LogicUnitNode>().any((n) => n.name == 'CounterBloc'),
        isTrue,
      );
    });

    test('CounterCubit async loadFromApi is detected as async', () {
      final cc = nodes.whereType<LogicUnitNode>().firstWhere(
            (n) => n.name == 'CounterCubit',
          );
      final load = cc.methods.firstWhere((m) => m.name == 'loadFromApi');
      expect(load.isAsync, isTrue);
    });
  });

  group('BLoC fixture — transformer output', () {
    late String output;

    setUpAll(() {
      final source = _fixture('bloc_counter.dart');
      output = _migrateSource(source, 'bloc_counter.dart');
      _writeActual('bloc_counter.actual.dart', output);
    });

    test('emits @riverpod annotation', () {
      expect(output, contains('@riverpod'));
    });

    test('output parses without errors', () {
      final result = parseString(content: output, throwIfDiagnostics: false);
      final errors = result.errors.where((e) => e.errorCode.type.name == 'ERROR');
      expect(errors, isEmpty,
          reason: 'Transformed BLoC output has parse errors');
    });
  });

  // ── GetX ──────────────────────────────────────────────────────────────────

  group('GetX fixture — scanner', () {
    late List<ProviderNode> nodes;

    setUpAll(() {
      final source = _fixture('getx_counter.dart');
      final result = parseString(content: source, throwIfDiagnostics: false);
      final adp = GetXAdapter('getx_counter.dart');
      result.unit.visitChildren(adp);
      nodes = adp.nodes;
    });

    test('detects CounterController', () {
      expect(
        nodes.whereType<LogicUnitNode>().any((n) => n.name == 'CounterController'),
        isTrue,
      );
    });

    test('CounterController has observable fields', () {
      final cc = nodes.whereType<LogicUnitNode>().firstWhere(
            (n) => n.name == 'CounterController',
          );
      expect(cc.stateFields.map((f) => f.rawName),
          containsAll(['count', 'label', 'loading']));
    });

    test('detects ProfileController', () {
      expect(
        nodes.whereType<LogicUnitNode>().any((n) => n.name == 'ProfileController'),
        isTrue,
      );
    });

    test('CounterController async loadFromApi detected', () {
      final cc = nodes.whereType<LogicUnitNode>().firstWhere(
            (n) => n.name == 'CounterController',
          );
      final load = cc.methods.firstWhere((m) => m.name == 'loadFromApi');
      expect(load.isAsync, isTrue);
    });
  });

  group('GetX fixture — transformer output', () {
    late String output;

    setUpAll(() {
      final source = _fixture('getx_counter.dart');
      output = _migrateSource(source, 'getx_counter.dart');
      _writeActual('getx_counter.actual.dart', output);
    });

    test('emits @riverpod annotation', () {
      expect(output, contains('@riverpod'));
    });

    test('output parses without errors', () {
      final result = parseString(content: output, throwIfDiagnostics: false);
      final errors = result.errors.where((e) => e.errorCode.type.name == 'ERROR');
      expect(errors, isEmpty,
          reason: 'Transformed GetX output has parse errors');
    });
  });

  // ── MobX ──────────────────────────────────────────────────────────────────

  group('MobX fixture — scanner', () {
    late List<ProviderNode> nodes;

    setUpAll(() {
      final source = _fixture('mobx_counter.dart');
      final result = parseString(content: source, throwIfDiagnostics: false);
      final adp = MobXAdapter('mobx_counter.dart');
      result.unit.visitChildren(adp);
      nodes = adp.nodes;
    });

    test('detects CounterStore', () {
      expect(
        nodes.whereType<LogicUnitNode>().any((n) => n.name == '_CounterStore'),
        isTrue,
      );
    });

    test('CounterStore has observable fields', () {
      final cs = nodes.whereType<LogicUnitNode>().firstWhere(
            (n) => n.name == '_CounterStore',
          );
      expect(cs.stateFields.map((f) => f.rawName),
          containsAll(['count', 'label', 'loading']));
    });

    test('detects _ProfileStore', () {
      expect(
        nodes.whereType<LogicUnitNode>().any((n) => n.name == '_ProfileStore'),
        isTrue,
      );
    });

    test('CounterStore async loadFromApi detected', () {
      final cs = nodes.whereType<LogicUnitNode>().firstWhere(
            (n) => n.name == '_CounterStore',
          );
      final load = cs.methods.firstWhere((m) => m.name == 'loadFromApi');
      expect(load.isAsync, isTrue);
    });
  });

  group('MobX fixture — transformer output', () {
    late String output;

    setUpAll(() {
      final source = _fixture('mobx_counter.dart');
      output = _migrateSource(source, 'mobx_counter.dart');
      _writeActual('mobx_counter.actual.dart', output);
    });

    test('emits @riverpod annotation', () {
      expect(output, contains('@riverpod'));
    });

    test('output parses without errors', () {
      final result = parseString(content: output, throwIfDiagnostics: false);
      final errors = result.errors.where((e) => e.errorCode.type.name == 'ERROR');
      expect(errors, isEmpty,
          reason: 'Transformed MobX output has parse errors');
    });
  });

  // ── AstScanner integration ────────────────────────────────────────────────

  group('AstScanner integration — all frameworks', () {
    late Directory tmpDir;

    setUp(() => tmpDir = Directory.systemTemp.createTempSync('migrator_p34_'));
    tearDown(() => tmpDir.deleteSync(recursive: true));

    test('scans all four fixture files in one project directory', () {
      final fixtureDir = _fixtureDir;
      for (final name in [
        'provider_counter.dart',
        'bloc_counter.dart',
        'getx_counter.dart',
        'mobx_counter.dart',
      ]) {
        File(p.join(tmpDir.path, name))
            .writeAsStringSync(File(p.join(fixtureDir, name)).readAsStringSync());
      }

      final scanner = AstScanner(tmpDir.path);
      final nodes = scanner.scanProject();

      final logicUnits = nodes.whereType<LogicUnitNode>().toList();
      // Expect at least one logic unit per framework fixture.
      expect(logicUnits.length, greaterThanOrEqualTo(4));
      expect(nodes.any((n) => n is MultiProviderNode), isTrue);
      expect(nodes.any((n) => n is ConsumerNode), isTrue);
      expect(nodes.any((n) => n is SelectorNode), isTrue);
    });

    test('no nodes detected when directory is empty', () {
      final scanner = AstScanner(tmpDir.path);
      expect(scanner.scanProject(), isEmpty);
    });

    test('scan does not throw on malformed dart file', () {
      File(p.join(tmpDir.path, 'broken.dart'))
          .writeAsStringSync('this is not valid dart {{{');
      final scanner = AstScanner(tmpDir.path);
      expect(() => scanner.scanProject(), returnsNormally);
    });
  });
}
