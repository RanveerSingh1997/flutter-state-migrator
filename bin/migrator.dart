import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_state_migrator/migrator/analysis/ai_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/analytics_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/cloud_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/config_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/dependency_checker.dart';
import 'package:flutter_state_migrator/migrator/analysis/dependency_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/generated_file_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/import_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/monorepo_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/snapshot_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/visualizer.dart';
import 'package:flutter_state_migrator/migrator/analysis/wizard.dart';
import 'package:flutter_state_migrator/migrator/generator/riverpod_generator.dart';
import 'package:flutter_state_migrator/migrator/generator/riverpod_transformer.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'package:flutter_state_migrator/migrator/scanner/ast_scanner.dart';

Future<void> main(List<String> arguments) async {
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
      'visualize',
      abbr: 'v',
      negatable: false,
      help: 'Generate a dependency graph (Mermaid format)',
    )
    ..addFlag(
      'dashboard',
      abbr: 'D',
      negatable: false,
      help: 'Launch the interactive migration dashboard',
    )
    ..addFlag(
      'sync',
      abbr: 's',
      negatable: false,
      help: 'Synchronize report with the cloud dashboard',
    )
    ..addFlag(
      'ai',
      negatable: false,
      help: 'Enable AI-assisted logic refactoring (requires local LLM)',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information',
    )
    ..addFlag(
      'wizard',
      abbr: 'w',
      negatable: false,
      help: 'Launch the interactive setup wizard',
    )
    ..addFlag(
      'rollback',
      negatable: false,
      help: 'Restore the project from the latest snapshot',
    )
    ..addFlag(
      'snapshots',
      negatable: false,
      help: 'List all available snapshots for the target path',
    )
    ..addOption(
      'rollback-to',
      help: 'Path to a specific snapshot directory to restore from',
    );

  final argResults = parser.parse(arguments);

  String targetPath;
  String mode;
  bool useAi;
  bool syncCloud;
  bool dryRun;
  bool visualize;
  bool dashboard;
  bool generateReport;
  bool cleanImports;

  if (argResults['help'] as bool) {
    print('Usage: dart run bin/migrator.dart [options] <flutter_project_path>');
    print(parser.usage);
    exit(0);
  }

  if (argResults.rest.isEmpty || argResults['wizard'] as bool) {
    final wizard = InteractiveWizard();
    final config = wizard.start();
    targetPath = config.targetPath;
    mode = config.mode;
    useAi = config.useAi;
    syncCloud = config.syncCloud;
    dryRun = config.dryRun;
    visualize = config.visualize;
    dashboard = false;
    generateReport = config.generateReport;
    cleanImports = config.cleanImports;
  } else {
    targetPath = argResults.rest.first;
    mode = argResults['mode'] as String;
    cleanImports = argResults['clean-imports'] as bool;
    generateReport = argResults['report'] as bool;
    dryRun = argResults['dry-run'] as bool;
    visualize = argResults['visualize'] as bool;
    dashboard = argResults['dashboard'] as bool;
    syncCloud = argResults['sync'] as bool;
    useAi = argResults['ai'] as bool;
  }

  final snapshot = SnapshotManager(targetPath);

  // Snapshot management commands — exit early, no migration needed.
  if (argResults['rollback'] as bool) {
    final specificPath = argResults['rollback-to'] as String?;
    await snapshot.rollback(snapshotPath: specificPath);
    return;
  }

  if (argResults['snapshots'] as bool) {
    final snaps = snapshot.listSnapshots();
    if (snaps.isEmpty) {
      print('No snapshots found for $targetPath');
    } else {
      print('\n📸 Available snapshots for $targetPath:\n');
      for (final s in snaps) {
        print('  ${s['timestamp']}  (${s['fileCount']} files)');
        print('  \x1B[90m${s['path']}\x1B[0m\n');
      }
    }
    return;
  }

  final monorepo = MonorepoManager(targetPath);
  final packages = monorepo.findPackages();
  final isMonorepo = packages.length > 1;

  // Pre-migration safety rail: snapshot before any destructive rewrite.
  if (!dryRun && mode == 'aggressive') {
    await snapshot.createSnapshot();
  }

  print(
    '\x1B[1m\x1B[35m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1B[0m',
  );
  print('✨ \x1B[1mFlutter State Migrator v2.0.0\x1B[0m ✨');
  print('🚀 \x1B[1mThe Universal Modernization Suite\x1B[0m');
  print('📍 Target: \x1B[33m$targetPath\x1B[0m');
  print(
    '📦 Packages found: \x1B[33m${packages.length}\x1B[0m'
    '${isMonorepo ? "  \x1B[90m(monorepo)\x1B[0m" : ""}',
  );
  for (final pkg in packages) {
    print('   - ${pkg.name} (\x1B[33m${pkg.rootPath}\x1B[0m)');
  }
  print('🛠️  Mode:   \x1B[33m$mode\x1B[0m');
  print(
    '\x1B[1m\x1B[35m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1B[0m',
  );

  // Load project-level config (migrator_config.yaml) if present.
  final projectConfig = ConfigurationManager.loadConfig(targetPath);
  if (projectConfig.providerNaming != 'camelCase' ||
      !projectConfig.autoMergeState) {
    print(
      '⚙️  Loaded project config: naming=${projectConfig.providerNaming}, autoMerge=${projectConfig.autoMergeState}',
    );
  }

  // Pipeline
  // 1. Scan targetPath for Dart files
  // 2. Parse into AST
  // 3. Extract IR models using ProviderAdapter
  final scanner = AstScanner(targetPath);
  final nodes = scanner.scanProject();

  // Warn about any circular dependencies before transforming.
  final depChecker = DependencyChecker();
  final depWarnings = depChecker.checkCircularDependencies(nodes);
  for (final warning in depWarnings) {
    print('\x1B[33m⚠️  $warning\x1B[0m');
  }

  print('\n📊 Found ${nodes.length} Provider-related elements:');
  if (visualize) {
    final visualizer = ProviderVisualizer();
    final mmd = visualizer.generateMermaid(nodes);
    visualizer.saveGraph(targetPath, mmd);
  }

  if (dashboard) {
    print('\n🌐 Launching Migration Dashboard...');
    print('📍 Access here: \x1B[34mhttp://localhost:8080\x1B[0m');
    print(
      'Note: Ensure the dashboard server is running in the /dashboard directory.',
    );
  }
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
        if (node is LogicUnitNode) {
          comment =
              '// TODO(Migrator): Convert ${node.name} to StateNotifier\n';
        } else if (node is ProviderDeclarationNode) {
          comment =
              '// TODO(Migrator): Replace ${node.providerType} with StateNotifierProvider\n';
        } else if (node is ConsumerNode) {
          comment =
              '// TODO(Migrator): Change to ConsumerWidget and use ref.watch\n';
        } else if (node is ProviderOfNode) {
          comment = '// TODO(Migrator): Replace with ref.read or ref.watch\n';
        } else if (node is SelectorNode) {
          comment =
              '// TODO(Migrator): Replace Selector with ref.watch(${node.consumedClass.toLowerCase()}Provider.select(...))\n';
        } else if (node is MultiProviderNode) {
          comment =
              '// TODO(Migrator): Remove MultiProvider, Riverpod providers are global. Wrap app in ProviderScope.\n';
        } else if (node is AsyncProviderNode) {
          comment =
              '// TODO(Migrator): ${node.providerType} exposes AsyncValue. Use .when() to handle data/loading/error states.\n';
        }

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
          if (processedTypes.contains('ProviderOf:${node.consumedClass}')) {
            continue;
          }
          processedTypes.add('ProviderOf:${node.consumedClass}');
        } else if (node is ConsumerNode) {
          if (processedTypes.contains('Consumer:${node.consumedClass}')) {
            continue;
          }
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
    final startTime = DateTime.now();
    final analyticsManager = AnalyticsManager();
    final roiMetrics = analyticsManager.calculateMetrics(
      nodes,
      packages.length,
    );

    final reportData = {
      'timestamp': DateTime.now().toIso8601String(),
      'targetPath': targetPath,
      'mode': mode,
      'packages': packages
          .map((p) => {'name': p.name, 'root': p.rootPath})
          .toList(),
      'metrics': roiMetrics,
      'modified_files': <String>[],
      'nodes': nodes.map((n) {
        if (n is LogicUnitNode) {
          return {
            'type': 'LogicUnit',
            'name': n.name,
            'file': n.filePath,
            'isNotifier': n.isNotifier,
            'methods': n.methods.length,
          };
        }
        return {'type': 'Unknown'};
      }).toList(),
      'summary': {
        'total_nodes': nodes.length,
        'logic_units': nodes.whereType<LogicUnitNode>().length,
        'widgets': nodes.whereType<WidgetNode>().length,
        'duration_ms': DateTime.now().difference(startTime).inMilliseconds,
      },
      'warnings': depWarnings,
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
      final reportJson = JsonEncoder.withIndent('  ').convert(reportData);
      reportFile.writeAsStringSync(reportJson);
      print('\n📊 Report generated at: ${reportFile.path}');

      if (syncCloud) {
        final cloudManager = CloudManager();
        await cloudManager.uploadReport(reportData);
      }
    }

    if (useAi) {
      print('\n🤖 Running AI-assisted logic refactoring...');
      final aiManager = AIManager();
      final logicNodes = nodes.whereType<LogicUnitNode>().toList();
      for (final node in logicNodes) {
        final complexMethods = node.methods
            .where((m) => m.callsNotifyListeners)
            .toList();
        for (final method in complexMethods) {
          print('   Refactoring ${node.name}.${method.name}...');
          await aiManager.refactorMethodBody(
            className: node.name,
            stateFields: node.stateVariables,
            methodName: method.name,
            methodBody: method.bodySnippet,
          );
          print('   \x1B[32m✓\x1B[0m ${node.name}.${method.name}');
        }
      }
    }

    print('\n🧹 Running dart format on $targetPath...');
    Process.runSync('dart', ['format', targetPath]);

    // Post-migration: update pubspec.yaml for every affected package.
    if (!dryRun) {
      final affectedPkgs = isMonorepo
          ? monorepo.migrateablePackages(
              (reportData['modified_files'] as List).cast<String>(),
            )
          : [PackageInfo(name: 'root', rootPath: targetPath)];

      for (final pkg in affectedPkgs) {
        final pkgDep = DependencyManager(pkg.rootPath);
        final result = await pkgDep.updateDependencies();
        if (result.hasChanges) {
          if (result.added.isNotEmpty) {
            print(
              '📦 [${pkg.name}] Added deps: ${result.added.join(", ")}',
            );
          }
          if (result.commented.isNotEmpty) {
            print(
              '🧹 [${pkg.name}] Commented out: ${result.commented.join(", ")}',
            );
          }
        }
      }

      // Report files that now need build_runner.
      final genManager = GeneratedFileManager(targetPath);
      final modifiedFiles =
          (reportData['modified_files'] as List).cast<String>();
      final needsBuildRunner = genManager.pendingBuildRunnerFiles(
        modifiedFiles,
      );
      if (needsBuildRunner.isNotEmpty) {
        print(
          '\n⚙️  Run build_runner to generate .g.dart files for '
          '${needsBuildRunner.length} file(s):',
        );
        for (final f in needsBuildRunner) {
          print('   $f');
        }
        print(
          '   dart run build_runner build --delete-conflicting-outputs',
        );
      }

      // Clean up stale .g.dart files from previous runs.
      final staleCleaned = genManager.cleanStaleFiles();
      if (staleCleaned > 0) {
        print('🗑️  Removed $staleCleaned stale .g.dart file(s).');
      }

      print('\n🚀 Running "flutter pub get"...');
      // Process.runSync('flutter', ['pub', 'get'], workingDirectory: targetPath);
    }

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
