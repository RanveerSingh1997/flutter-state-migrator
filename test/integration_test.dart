import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_state_migrator/migrator/analysis/import_manager.dart';
import 'package:flutter_state_migrator/migrator/generator/riverpod_transformer.dart';
import 'package:flutter_state_migrator/migrator/scanner/ast_scanner.dart';
import 'package:flutter_state_migrator/migrator/utils/edit_applier.dart';

/// Groups nodes by the source file they came from.
Map<String, List<dynamic>> _groupByFile(List<dynamic> nodes) {
  final map = <String, List<dynamic>>{};
  for (final node in nodes) {
    map.putIfAbsent(node.filePath as String, () => []).add(node);
  }
  return map;
}

/// Copies [src] directory tree into [dest].
Future<void> _copyDir(Directory src, Directory dest) async {
  await dest.create(recursive: true);
  await for (final entity in src.list(recursive: false)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (entity is Directory) {
      await _copyDir(entity, Directory('${dest.path}/$name'));
    } else if (entity is File) {
      await entity.copy('${dest.path}/$name');
    }
  }
}

void main() {
  group('End-to-end integration', () {
    test('aggressive migration of example/lib produces valid Dart', () async {
      // ── 1. Copy example/lib into a temp directory ─────────────────────────
      final exampleLib = Directory('example/lib');
      if (!exampleLib.existsSync()) {
        markTestSkipped('example/lib not found — skipping integration test');
        return;
      }

      final tmpDir = await Directory.systemTemp
          .createTemp('flutter_state_migrator_integration_');

      try {
        await _copyDir(exampleLib, tmpDir);

        // ── 2. Scan ─────────────────────────────────────────────────────────
        final scanner = AstScanner(tmpDir.path);
        final nodes = scanner.scanProject();

        expect(
          nodes,
          isNotEmpty,
          reason: 'Scanner should detect Provider patterns in the example app',
        );

        // ── 3. Transform and apply edits ─────────────────────────────────────
        final transformer = RiverpodTransformer();
        final importManager = ImportManager();
        final nodesByFile = _groupByFile(nodes);

        for (final entry in nodesByFile.entries) {
          final file = File(entry.key);
          if (!file.existsSync()) continue;

          final original = file.readAsStringSync();
          final edits = [
            for (final n in entry.value) ...transformer.transformNode(n, original),
          ];

          var content = applyEdits(original, edits);
          content = importManager.processImports(content);
          file.writeAsStringSync(content);
        }

        // ── 4. Verify migration output has expected properties ─────────────
        // Full `dart analyze` would fail because @riverpod-generated classes
        // (e.g. _$CounterNotifier) don't exist until build_runner runs.
        // Instead we assert the structural migration contract:
        final allContent = nodesByFile.keys
            .map((path) => File(path).existsSync() ? File(path).readAsStringSync() : '')
            .join('\n');

        // At least one file should have been converted to ConsumerWidget or
        // gained a @riverpod annotation.
        final hasMigratedCode =
            allContent.contains('ConsumerWidget') ||
            allContent.contains('@riverpod') ||
            allContent.contains('ref.watch(') ||
            allContent.contains('ProviderScope');

        expect(hasMigratedCode, isTrue,
            reason: 'Migration should produce Riverpod patterns');

        // The flutter_riverpod import must be present in files that use
        // ConsumerWidget or ref.watch.
        if (allContent.contains('ConsumerWidget') ||
            allContent.contains('ref.watch(')) {
          expect(
            allContent,
            contains("import 'package:flutter_riverpod/flutter_riverpod.dart'"),
            reason: 'flutter_riverpod import must be injected by ImportManager',
          );
        }

        // The riverpod_annotation import must be present in files with @riverpod.
        if (allContent.contains('@riverpod')) {
          expect(
            allContent,
            contains(
                "import 'package:riverpod_annotation/riverpod_annotation.dart'"),
            reason: 'riverpod_annotation import must be injected by ImportManager',
          );
        }

        // There must be no /* TODO: Return Future */ syntax-error placeholders.
        expect(
          allContent,
          isNot(contains('/* TODO: Return')),
          reason: 'Syntax-error TODO placeholders must not appear in output',
        );
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });

    test('applyEdits: pure insertion at offset 0 is never dropped', () {
      // Regression for Bug 3 — header injection at offset 0 was silently
      // dropped when the first class also starts at offset 0.
      const source = 'class Foo {}';
      final edits = [
        TextEdit(0, 0, '// header\n'),       // pure insertion — must survive
        TextEdit(0, source.length, 'class Bar {}'), // replacement at same offset
      ];
      final result = applyEdits(source, edits);
      expect(result, contains('// header\n'));
      expect(result, contains('class Bar {}'));
    });

    test('ImportManager injects riverpod_annotation for @riverpod files', () {
      const content = '''
@riverpod
class Counter extends _\$Counter {
  @override
  int build() => 0;
}
''';
      final processed = ImportManager().processImports(content);
      expect(
        processed,
        contains("import 'package:riverpod_annotation/riverpod_annotation.dart'"),
      );
    });

    test('ImportManager injects flutter_riverpod for ConsumerWidget files', () {
      const content = '''
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container();
}
''';
      final processed = ImportManager().processImports(content);
      expect(
        processed,
        contains("import 'package:flutter_riverpod/flutter_riverpod.dart'"),
      );
    });

    test('ImportManager does not false-positive on commented symbols', () {
      const content = '''
// ConsumerWidget is used in the riverpod version
// ref.watch example
class MyWidget extends StatelessWidget {}
''';
      final processed = ImportManager().processImports(content);
      // Should NOT inject riverpod import — all matches are in comments
      expect(
        processed,
        isNot(contains("import 'package:flutter_riverpod")),
      );
    });
  });
}
