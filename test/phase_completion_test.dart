import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_state_migrator/migrator/analysis/body_transformer.dart';
import 'package:flutter_state_migrator/migrator/analysis/ai_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/dependency_checker.dart';
import 'package:flutter_state_migrator/migrator/analysis/dependency_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/generated_file_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/graph_builder.dart';
import 'package:flutter_state_migrator/migrator/analysis/monorepo_manager.dart';
import 'package:flutter_state_migrator/migrator/generator/riverpod_generator.dart';
import 'package:flutter_state_migrator/migrator/generator/riverpod_transformer.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Phase 28 dependency graph', () {
    test('detects circular logic-unit dependencies', () {
      final graph = GraphBuilder().buildGraph([
        LogicUnitNode(
          name: 'CounterModel',
          stateFields: const [],
          methods: const [],
          isNotifier: true,
          filePath: 'lib/counter.dart',
          offset: 0,
          length: 10,
        ),
        LogicUnitNode(
          name: 'SessionModel',
          stateFields: const [],
          methods: const [],
          isNotifier: true,
          filePath: 'lib/session.dart',
          offset: 0,
          length: 10,
        ),
        ProviderOfNode(
          consumedClass: 'SessionModel',
          filePath: 'lib/counter.dart',
          offset: 0,
          length: 1,
        ),
        ProviderOfNode(
          consumedClass: 'CounterModel',
          filePath: 'lib/session.dart',
          offset: 0,
          length: 1,
        ),
      ]);
      final warnings = DependencyChecker().checkCircularDependencies(graph);

      expect(warnings, hasLength(1));
      expect(
        warnings.single,
        contains('CounterModel → SessionModel → CounterModel'),
      );
    });
  });

  group('Phase 29 body transformer', () {
    test('rewrites list mutation and merges multi-step state updates', () {
      final result = BodyTransformer().transformBody(
        '''
{
  _items.add(todo);
  _count++;
  _label = _label ?? fallback;
}
''',
        const [
          FieldInfo(
            rawName: '_items',
            type: 'List<Todo>',
            initializer: 'const []',
          ),
          FieldInfo(rawName: '_count', type: 'int', initializer: '0'),
          FieldInfo(rawName: '_label', type: 'String?', initializer: 'null'),
        ],
      );

      expect(
        result,
        contains(
          'state = state.copyWith(items: [...state.items, todo], count: state.count + 1, label: state.label ?? fallback);',
        ),
      );
    });
  });

  group('Phase 30 code-gen output', () {
    test('generator emits @riverpod code with build runner instructions', () {
      final output = RiverpodGenerator().generateSuggestion(
        LogicUnitNode(
          name: 'CounterModel',
          stateFields: const [
            FieldInfo(rawName: '_count', type: 'int', initializer: '0'),
          ],
          methods: [
            MethodInfo(
              name: 'count',
              callsNotifyListeners: false,
              bodySnippet: '=> _count',
              isGetter: true,
            ),
            MethodInfo(
              name: 'rename',
              callsNotifyListeners: false,
              bodySnippet: '{ _count = value; notifyListeners(); }',
              parameters: [ParamInfo(name: 'value', type: 'int')],
            ),
          ],
          isNotifier: true,
          filePath: 'lib/counter_model.dart',
          offset: 0,
          length: 10,
        ),
      );

      expect(
        output,
        contains(
          'import "package:riverpod_annotation/riverpod_annotation.dart";',
        ),
      );
      expect(output, contains('part "counter_model.g.dart";'));
      expect(
        output,
        contains('dart run build_runner build --delete-conflicting-outputs'),
      );
      expect(output, contains('@riverpod'));
      expect(output, contains('class CounterModel extends _\$CounterModel'));
      expect(output, contains('int build() {'));
      expect(output, contains('return 0;'));
      expect(output, contains('void rename(int value)'));
      expect(output, isNot(contains('count()')));
    });

    test('transformer emits generated-header once and uses notifier reads', () {
      final transformer = RiverpodTransformer();
      const source = '''
class CounterModel extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment(int delta) {
    _count += delta;
    notifyListeners();
  }
}
''';

      final node = LogicUnitNode(
        name: 'CounterModel',
        stateFields: const [
          FieldInfo(rawName: '_count', type: 'int', initializer: '0'),
        ],
        methods: [
          MethodInfo(
            name: 'count',
            callsNotifyListeners: false,
            bodySnippet: '=> _count',
            isGetter: true,
          ),
          MethodInfo(
            name: 'increment',
            callsNotifyListeners: true,
            bodySnippet: '{ _count += delta; notifyListeners(); }',
            parameters: [ParamInfo(name: 'delta', type: 'int')],
          ),
        ],
        isNotifier: true,
        filePath: 'lib/counter_model.dart',
        offset: 0,
        length: source.length,
      );

      final logicEdits = transformer.transformNode(node, source);
      // Two edits: file-level header insert (offset 0, length 0) + class replacement.
      expect(logicEdits, hasLength(2));
      final headerEdit = logicEdits.firstWhere((e) => e.length == 0);
      final classEdit = logicEdits.firstWhere((e) => e.length > 0);
      final allReplacement = logicEdits.map((e) => e.replacement).join('\n');
      expect(
        headerEdit.replacement,
        contains(
          'import "package:riverpod_annotation/riverpod_annotation.dart";',
        ),
      );
      expect(
        'import "package:riverpod_annotation/riverpod_annotation.dart";'
            .allMatches(allReplacement)
            .length,
        1,
      );
      expect(headerEdit.replacement, contains('part "counter_model.g.dart";'));
      expect(classEdit.replacement, contains('return 0;'));
      expect(classEdit.replacement, contains('void increment(int delta)'));
      expect(
        classEdit.replacement,
        contains('state = state.copyWith(count: state.count + delta);'),
      );

      final providerRead = transformer.transformNode(
        ProviderOfNode(
          consumedClass: 'CounterModel',
          filePath: 'lib/counter_model.dart',
          offset: 0,
          length: 'Provider.of<CounterModel>(context, listen: false)'.length,
        ),
        'Provider.of<CounterModel>(context, listen: false)',
      );
      expect(providerRead.single.replacement, 'ref.read(counterModelProvider)');
    });

    test('consumer and selector expression builders become valid block builders', () {
      final transformer = RiverpodTransformer();

      const consumerSource =
          "Consumer<CounterModel>(builder: (context, counter, child) => Text('\${counter.count}'))";
      final consumerEdits = transformer.transformNode(
        ConsumerNode(
          consumedClass: 'CounterModel',
          filePath: 'lib/main.dart',
          offset: 0,
          length: consumerSource.length,
        ),
        consumerSource,
      );
      expect(
        consumerEdits.any(
          (edit) =>
              edit.replacement.contains(
                'final counter = ref.watch(counterModelProvider);',
              ) &&
              edit.replacement.contains("return Text('\${counter.count}')"),
        ),
        isTrue,
      );

      const selectorSource =
          "Selector<CounterModel, int>(selector: (_, model) => model.count, builder: (context, count, child) => Text('\$count'))";
      final selectorEdits = transformer.transformNode(
        SelectorNode(
          consumedClass: 'CounterModel',
          selectedType: 'int',
          selectorSnippet: '(_, model) => model.count',
          filePath: 'lib/main.dart',
          offset: 0,
          length: selectorSource.length,
        ),
        selectorSource,
      );
      expect(
        selectorEdits.any(
          (edit) => edit.replacement.contains(
            'final count = ref.watch(counterModelProvider.select((state) => state.count));',
          ),
        ),
        isTrue,
      );
      expect(
        selectorEdits.any(
          (edit) => edit.replacement.contains("return Text('\$count')"),
        ),
        isTrue,
      );
    });
  });

  group('Phase 33 project-level integration', () {
    late Directory tmpDir;

    setUp(() => tmpDir = Directory.systemTemp.createTempSync('migrator_p33_'));
    tearDown(() => tmpDir.deleteSync(recursive: true));

    // ── DependencyManager ───────────────────────────────────────────────────

    test(
      'DependencyManager adds Riverpod deps and fixes capture-group bug',
      () async {
        final pubspec = File(p.join(tmpDir.path, 'pubspec.yaml'))
          ..writeAsStringSync('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
dev_dependencies:
  flutter_test:
    sdk: flutter
''');

        final result = await DependencyManager(
          tmpDir.path,
        ).updateDependencies();

        final content = pubspec.readAsStringSync();
        expect(
          result.added,
          containsAll(['flutter_riverpod', 'riverpod_annotation']),
        );
        expect(result.commented, contains('provider'));
        expect(content, contains('flutter_riverpod:'));
        expect(content, contains('riverpod_annotation:'));
        // Capture-group replacement must produce `# provider:`, not literal `$1# $2`.
        expect(content, contains('# provider:'));
        expect(content, isNot(contains(r'$1# $2')));
      },
    );

    test(
      'DependencyManager creates dev_dependencies section when absent',
      () async {
        File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: no_dev
dependencies:
  flutter:
    sdk: flutter
''');

        await DependencyManager(tmpDir.path).updateDependencies();

        final content = File(
          p.join(tmpDir.path, 'pubspec.yaml'),
        ).readAsStringSync();
        expect(content, contains('dev_dependencies:'));
        expect(content, contains('riverpod_generator:'));
        expect(content, contains('build_runner:'));
      },
    );

    test('DependencyManager is idempotent on a second run', () async {
      File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: app
dependencies:
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
dev_dependencies:
  riverpod_generator: ^2.6.1
  build_runner: ^2.4.0
''');

      final result = await DependencyManager(tmpDir.path).updateDependencies();
      expect(result.added, isEmpty);
      expect(result.commented, isEmpty);
    });

    // ── GeneratedFileManager ─────────────────────────────────────────────────

    test('GeneratedFileManager finds stale .g.dart files', () {
      // Source with no part directive → stale
      File(
        p.join(tmpDir.path, 'stale.dart'),
      ).writeAsStringSync('void main() {}');
      File(
        p.join(tmpDir.path, 'stale.g.dart'),
      ).writeAsStringSync('// generated');

      // Source with matching part directive → live
      File(
        p.join(tmpDir.path, 'live.dart'),
      ).writeAsStringSync("part 'live.g.dart';");
      File(
        p.join(tmpDir.path, 'live.g.dart'),
      ).writeAsStringSync('// generated');

      final mgr = GeneratedFileManager(tmpDir.path);
      final stale = mgr.findStaleGeneratedFiles();

      expect(stale.map((f) => p.basename(f.path)), contains('stale.g.dart'));
      expect(
        stale.map((f) => p.basename(f.path)),
        isNot(contains('live.g.dart')),
      );
    });

    test('GeneratedFileManager cleans stale files', () {
      File(p.join(tmpDir.path, 'orphan.dart')).writeAsStringSync('void f() {}');
      final gFile = File(p.join(tmpDir.path, 'orphan.g.dart'))
        ..writeAsStringSync('// generated');

      final mgr = GeneratedFileManager(tmpDir.path);
      final count = mgr.cleanStaleFiles();

      expect(count, 1);
      expect(gFile.existsSync(), isFalse);
    });

    test('GeneratedFileManager reports files needing build_runner', () {
      final src = File(p.join(tmpDir.path, 'counter.dart'))
        ..writeAsStringSync("part 'counter.g.dart';\nvoid f() {}");

      final mgr = GeneratedFileManager(tmpDir.path);
      final pending = mgr.pendingBuildRunnerFiles([src.path]);

      expect(pending, contains(src.path));
    });

    // ── MonorepoManager ──────────────────────────────────────────────────────

    test('MonorepoManager finds packages and skips excluded dirs', () {
      // Root package
      File(
        p.join(tmpDir.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: root\n');
      // Sub-package
      final sub = Directory(p.join(tmpDir.path, 'packages', 'sub_pkg'))
        ..createSync(recursive: true);
      File(
        p.join(sub.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: sub_pkg\n');
      // Should be ignored
      final buildDir = Directory(p.join(tmpDir.path, 'build', 'pkg'))
        ..createSync(recursive: true);
      File(
        p.join(buildDir.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: should_be_excluded\n');

      final mgr = MonorepoManager(tmpDir.path);
      final names = mgr.findPackages().map((p) => p.name).toSet();

      expect(names, containsAll(['root', 'sub_pkg']));
      expect(names, isNot(contains('should_be_excluded')));
      expect(mgr.isMonorepo, isTrue);
    });

    test('MonorepoManager.migrateablePackages filters by node file paths', () {
      File(
        p.join(tmpDir.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: root\n');
      final pkgA = Directory(p.join(tmpDir.path, 'packages', 'pkg_a'))
        ..createSync(recursive: true);
      File(
        p.join(pkgA.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: pkg_a\n');
      final pkgB = Directory(p.join(tmpDir.path, 'packages', 'pkg_b'))
        ..createSync(recursive: true);
      File(
        p.join(pkgB.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: pkg_b\n');

      final mgr = MonorepoManager(tmpDir.path);
      final relevant = mgr.migrateablePackages([
        p.join(pkgA.path, 'lib', 'counter.dart'),
      ]);

      expect(relevant.map((p) => p.name), contains('pkg_a'));
      expect(relevant.map((p) => p.name), isNot(contains('pkg_b')));
    });
  });

  group('Phase 44 AI guidance', () {
    test('AIManager provides deterministic fallback guidance', () async {
      final guidance = await AIManager(
        client: MockClient(
          (_) async => http.Response('service unavailable', 503),
        ),
      ).refactorMethodBody(
        className: 'CounterModel',
        stateFields: const ['_count'],
        methodName: 'increment',
        methodBody: '{ _count += 1; notifyListeners(); }',
      );

      expect(guidance.recommendation, isNotEmpty);
      expect(guidance.prompt, contains('CounterModel'));
    });
  });
}
