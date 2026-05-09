import 'dart:io';
import 'package:args/args.dart';

import '../lib/migrator/scanner/ast_scanner.dart';
import '../lib/migrator/models/ir_models.dart';
import '../lib/migrator/generator/riverpod_generator.dart';
import '../lib/migrator/generator/riverpod_transformer.dart';
import '../lib/migrator/analysis/import_manager.dart';
import '../lib/migrator/analysis/dependency_checker.dart';
import '../lib/migrator/analysis/config_manager.dart';
import '../lib/migrator/analysis/monorepo_manager.dart';
import 'dart:convert';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption(
      'mode',
      allowed: ['safe', 'assisted', 'aggressive'],
      defaultsTo: 'safe',
      help: 'Migration mode',
    )
    ..addFlag(
      'clean-imports',
      defaultsTo: true,
      help: 'Remove unused provider imports in aggressive mode',
    )
    ..addFlag(
      'report',
      defaultsTo: true,
      help: 'Generate migration_report.json',
    )
    ..addFlag(
      'dry-run',
      defaultsTo: false,
      help: 'Preview changes without modifying files',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information',
    );

  final argResults = parser.parse(arguments);

  if (argResults['help'] as bool || argResults.rest.isEmpty) {
    print('Usage: dart run bin/migrator.dart [options] <flutter_project_path>');
    print(parser.usage);
    exit(0);
  }

  final targetPath = argResults.rest.first;
  final mode = argResults['mode'] as String;
  final config = ConfigurationManager.loadConfig(targetPath);
  final cleanImports = argResults['clean-imports'] as bool;
  final generateReport = argResults['report'] as bool;
  final dryRun = argResults['dry-run'] as bool;

  final monorepo = MonorepoManager(targetPath);
  final packages = monorepo.findPackages();

  print(
    '\x1B[1m\x1B[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1B[0m',
  );
  print('🚀 Starting \x1B[1mFlutter State Migrator\x1B[0m...');
  print('📍 Target: \x1B[33m$targetPath\x1B[0m');
  print('📦 Packages found: \x1B[33m${packages.length}\x1B[0m');
  for (final pkg in packages) {
    print('   - ${pkg.name} (\x1B[33m${pkg.rootPath}\x1B[0m)');
  }
  print('🛠️  Mode:   \x1B[33m$mode\x1B[0m');
  print(
    '\x1B[1m\x1B[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1B[0m',
  );

  // Pipeline
  // 1. Scan targetPath for Dart files
  // 2. Parse into AST
  // 3. Extract IR models using ProviderAdapter
  final scanner = AstScanner(targetPath);
  final nodes = scanner.scanProject();

  print('\n📊 Found ${nodes.length} Provider-related elements:');
  for (final node in nodes) {
    if (node is LogicUnitNode) {
      print(
        ' - LogicUnit: ${node.name} (state: ${node.stateVariables}, methods: ${node.methods.map((m) => m.name).toList()})',
      );
    } else if (node is ProviderDeclarationNode) {
      print(' - Declaration: ${node.providerType} -> ${node.providedClass}');
    } else if (node is ConsumerNode) {
      print(' - Consumer: ${node.consumedClass}');
    } else if (node is ProviderOfNode) {
      print(' - Provider.of: ${node.consumedClass}');
    } else if (node is SelectorNode) {
      print(' - Selector: ${node.consumedClass} -> ${node.selectedType}');
    } else if (node is MultiProviderNode) {
      print(' - MultiProvider');
    } else if (node is AsyncProviderNode) {
      print(' - AsyncProvider: ${node.providerType} -> ${node.providedType}');
    }
  }

  print('\n✨ Generating Riverpod Suggestions...');
  final generator = RiverpodGenerator();

  if (mode == 'safe') {
    print('🛡️  Running in Safe Mode: Injecting TODOs into source files...');
    // Group nodes by file
    final nodesByFile = <String, List<ProviderNode>>{};
    for (final node in nodes) {
      nodesByFile.putIfAbsent(node.filePath, () => []).add(node);
    }

    for (final entry in nodesByFile.entries) {
      final file = File(entry.key);
      if (!file.existsSync()) continue;

      String content = file.readAsStringSync();
      // Sort descending by offset to avoid shifting issues when inserting
      final uniqueFileNodes = <int, ProviderNode>{};
      for (final node in entry.value) {
        uniqueFileNodes[node.offset] = node;
      }
      final fileNodes = uniqueFileNodes.values.toList()
        ..sort((a, b) => b.offset.compareTo(a.offset));

      for (final node in fileNodes) {
        String comment = '';
        if (node is LogicUnitNode)
          comment =
              '// TODO(Migrator): Convert ${node.name} to StateNotifier\n';
        else if (node is ProviderDeclarationNode)
          comment =
              '// TODO(Migrator): Replace ${node.providerType} with StateNotifierProvider\n';
        else if (node is ConsumerNode)
          comment =
              '// TODO(Migrator): Change to ConsumerWidget and use ref.watch\n';
        else if (node is ProviderOfNode)
          comment = '// TODO(Migrator): Replace with ref.read or ref.watch\n';
        else if (node is SelectorNode)
          comment =
              '// TODO(Migrator): Replace Selector with ref.watch(${node.consumedClass.toLowerCase()}Provider.select(...))\n';
        else if (node is MultiProviderNode)
          comment =
              '// TODO(Migrator): Remove MultiProvider, Riverpod providers are global. Wrap app in ProviderScope.\n';
        else if (node is AsyncProviderNode)
          comment =
              '// TODO(Migrator): ${node.providerType} exposes AsyncValue. Use .when() to handle data/loading/error states.\n';

        if (comment.isNotEmpty) {
          content = content.replaceRange(node.offset, node.offset, comment);
        }
      }

      file.writeAsStringSync(content);
      print('✅ Updated ${entry.key}');
    }
  } else if (mode == 'assisted') {
    print('🤝 Running in Assisted Mode: Generating partial Riverpod files...');
    final nodesByFile = <String, List<ProviderNode>>{};
    for (final node in nodes) {
      nodesByFile.putIfAbsent(node.filePath, () => []).add(node);
    }

    for (final entry in nodesByFile.entries) {
      final originalFile = File(entry.key);
      if (!originalFile.existsSync()) continue;

      final newFilePath = entry.key.replaceAll('.dart', '_riverpod.dart');
      final newFile = File(newFilePath);

      final buffer = StringBuffer();
      buffer.writeln(
        '// 🚀 Auto-generated Riverpod migration suggestions for ${originalFile.uri.pathSegments.last}',
      );
      buffer.writeln(
        '// You can use these snippets to replace your Provider logic.',
      );
      buffer.writeln();

      final processedTypes = <String>{};
      for (final node in entry.value) {
        if (node is ProviderOfNode) {
          if (processedTypes.contains('ProviderOf:${node.consumedClass}'))
            continue;
          processedTypes.add('ProviderOf:${node.consumedClass}');
        } else if (node is ConsumerNode) {
          if (processedTypes.contains('Consumer:${node.consumedClass}'))
            continue;
          processedTypes.add('Consumer:${node.consumedClass}');
        }
        buffer.writeln(generator.generateSuggestion(node));
        buffer.writeln();
      }

      newFile.writeAsStringSync(buffer.toString());
      print('📄 Generated $newFilePath');
    }
  } else if (mode == 'aggressive') {
    print('🔥 Running in Aggressive Mode: Rewriting source files...');
    final transformer = RiverpodTransformer();
    final importManager = ImportManager();
    int modifiedFilesCount = 0;
    final reportData = {
      'timestamp': DateTime.now().toIso8601String(),
      'target': targetPath,
      'packages': packages.map((p) => {'name': p.name, 'root': p.rootPath}).toList(),
      'modified_files': <String>[],
      'summary': {
        'total_nodes': nodes.length,
        'logic_units': nodes.whereType<LogicUnitNode>().length,
        'widgets': nodes.whereType<WidgetNode>().length,
      },
    };

    final nodesByFile = <String, List<ProviderNode>>{};
    for (final node in nodes) {
      nodesByFile.putIfAbsent(node.filePath, () => []).add(node);
    }

    for (final entry in nodesByFile.entries) {
      final file = File(entry.key);
      if (!file.existsSync()) continue;

      String content = file.readAsStringSync();

      final edits = <TextEdit>[];
      for (final node in entry.value) {
        edits.addAll(transformer.transformNode(node, content));
      }

      // Sort descending by offset
      edits.sort((a, b) => b.offset.compareTo(a.offset));

      bool modified = false;
      for (final edit in edits) {
        content = content.replaceRange(
          edit.offset,
          edit.offset + edit.length,
          edit.replacement,
        );
        modified = true;
      }

      if (modified) {
        // Post-process imports
        content = importManager.processImports(
          content,
          cleanProvider: cleanImports,
        );

        if (dryRun) {
          print('\n👀 Dry Run: Proposed changes for ${entry.key}:');
          final original = File(entry.key).readAsStringSync();
          _printSimpleDiff(original, content);
        } else {
          file.writeAsStringSync(content);
          print('  ✅ Rewrote ${entry.key}');
          modifiedFilesCount++;
          (reportData['modified_files'] as List).add(entry.key);
        }
      }
    }

    if (generateReport && !dryRun) {
      final reportFile = File('$targetPath/migration_report.json');
      reportFile.writeAsStringSync(
        JsonEncoder.withIndent('  ').convert(reportData),
      );
      print('\n📊 Report generated at: ${reportFile.path}');
    }

    print('\n🧹 Running dart format on $targetPath...');
    Process.runSync('dart', ['format', targetPath]);

    print(
      '\n\x1B[1m\x1B[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1B[0m',
    );
    print('✨ \x1B[1m\x1B[32mMigration Complete!\x1B[0m');
    print('📝 Files modified: \x1B[1m$modifiedFilesCount\x1B[0m');
    if (!dryRun) {
      print('📊 Audit log saved to migration_report.json');
    }
    print(
      '\x1B[1m\x1B[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1B[0m\n',
    );
  } else {
    print('❌ Unknown mode: $mode');
  }
}

void _printSimpleDiff(String original, String modified) {
  final originalLines = original.split('\n');
  final modifiedLines = modified.split('\n');

  // Very simple line-based diff for console
  for (int i = 0; i < modifiedLines.length; i++) {
    if (i < originalLines.length) {
      if (originalLines[i] != modifiedLines[i]) {
        print('\x1B[31m- ${originalLines[i]}\x1B[0m');
        print('\x1B[32m+ ${modifiedLines[i]}\x1B[0m');
      }
    } else {
      print('\x1B[32m+ ${modifiedLines[i]}\x1B[0m');
    }
  }
}
