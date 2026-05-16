import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_state_migrator/migrator/analysis/ai_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/analytics_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/architecture_intelligence.dart';
import 'package:flutter_state_migrator/migrator/analysis/config_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/dependency_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/generated_file_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/drift_detector.dart';
import 'package:flutter_state_migrator/migrator/analysis/governance_engine.dart';
import 'package:flutter_state_migrator/migrator/analysis/graph_builder.dart';
import 'package:flutter_state_migrator/migrator/analysis/ide_intelligence.dart';
import 'package:flutter_state_migrator/migrator/analysis/import_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/monorepo_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/snapshot_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/visualizer.dart';
import 'package:flutter_state_migrator/migrator/analysis/wizard.dart';
import 'package:flutter_state_migrator/migrator/generator/riverpod_generator.dart';
import 'package:flutter_state_migrator/migrator/generator/riverpod_transformer.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'package:flutter_state_migrator/migrator/scanner/ast_scanner.dart';
import 'package:flutter_state_migrator/migrator/utils/edit_applier.dart';

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
      'ai',
      negatable: false,
      help: 'Enable AI-assisted architecture guidance and logic refactoring',
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
    )
    ..addFlag(
      'ide-json',
      negatable: false,
      help: 'Emit structured IDE diagnostics as JSON without modifying files',
    )
    ..addFlag(
      'drift',
      negatable: false,
      help: 'Compare architecture health against saved baseline',
    );

  final argResults = parser.parse(arguments);

  String targetPath;
  String mode;
  bool useAi;
  bool dryRun;
  bool visualize;
  bool dashboard;
  bool generateReport;
  bool cleanImports;
  final ideJson = argResults['ide-json'] as bool;

  if (argResults['help'] as bool) {
    print('Usage: dart run bin/migrator.dart [options] <flutter_project_path>');
    print(parser.usage);
    exit(0);
  }

  if (ideJson && argResults.rest.isEmpty) {
    stderr.writeln(
      'A target file or project path is required with --ide-json.',
    );
    exitCode = 64;
    return;
  }

  if (!ideJson && (argResults.rest.isEmpty || argResults['wizard'] as bool)) {
    final wizard = InteractiveWizard();
    final config = wizard.start();
    targetPath = config.targetPath;
    mode = config.mode;
    useAi = config.useAi;
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
    useAi = argResults['ai'] as bool;
  }

  final projectRoot = resolveProjectRoot(targetPath);
  final snapshot = SnapshotManager(projectRoot);

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

  final monorepo = MonorepoManager(projectRoot);
  final packages = monorepo.findPackages();
  final isMonorepo = packages.length > 1;

  if (!dryRun && mode == 'aggressive') {
    await snapshot.createSnapshot();
  }

  if (!ideJson) {
    print(
      '\x1B[1m\x1B[35m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1B[0m',
    );
    print('✨ \x1B[1mFlutter Arch Intelligence Platform v2.1.1\x1B[0m ✨');
    print('🚀 \x1B[1mThe Semantic Architecture Intelligence Suite\x1B[0m');
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
  }

  final projectConfig = ConfigurationManager.loadConfig(projectRoot);

  // 1. Scan targetPath for Dart files
  final scanner = AstScanner(targetPath);
  final nodes = scanner.scanProject();

  // 2. Build semantic architecture graph
  final graphBuilder = GraphBuilder();
  final graph = graphBuilder.buildGraph(nodes);

  // 3. Architecture Intelligence
  final intel = ArchitectureIntelligenceEngine(graph);
  final smells = intel.analyze();
  if (!ideJson) {
    print('\n🧠 Running Architecture Intelligence Engine...');
    if (smells.isNotEmpty) {
      for (final smell in smells) {
        final color = smell.severity == 'error' ? '\x1B[31m' : '\x1B[33m';
        print(
          '   $color${smell.severity.toUpperCase()}\x1B[0m: ${smell.name} - ${smell.description}',
        );
      }
    } else {
      print('   \x1B[32m✓ No architectural smells detected.\x1B[0m');
    }
  }

  // 4. Governance Validation
  final gov = GovernanceEngine(graph, projectConfig.governance);
  final violations = gov.validate();
  if (ideJson) {
    final ideReport = IdeIntelligenceEngine(
      targetPath,
    ).buildReport(graph: graph, smells: smells, violations: violations);
    stdout.write(
      const JsonEncoder.withIndent('  ').convert(ideReport.toJson()),
    );
    return;
  }

  print('\n⚖️  Running Governance Validation...');
  if (violations.isNotEmpty) {
    for (final v in violations) {
      print('   \x1B[31mVIOLATION\x1B[0m: ${v.ruleName} - ${v.message}');
    }
  } else {
    print('   \x1B[32m✓ Governance rules satisfied.\x1B[0m');
  }

  // 5. Architecture Drift Detection
  final healthScore = (100.0 - smells.length * 2.5 - violations.length * 5.0)
      .clamp(0.0, 100.0);
  final driftDetector = ArchitectureDriftDetector(projectRoot);

  if (argResults['drift'] as bool) {
    final driftReport = driftDetector.compareWithLatest(
      smells: smells,
      violations: violations,
      healthScore: healthScore,
    );
    print('\n📈 Architecture Drift Detection...');
    if (driftReport == null) {
      print('   No prior snapshot found — saving initial baseline.');
    } else if (!driftReport.hasChanges && driftReport.scoreDelta == 0.0) {
      print(
        '   \x1B[32m✓ No architecture drift since ${driftReport.comparedAt}.\x1B[0m',
      );
    } else {
      print('   Changes since ${driftReport.comparedAt}:');
      if (driftReport.scoreDelta != 0.0) {
        final sign = driftReport.scoreDelta > 0 ? '+' : '';
        final color = driftReport.scoreDelta > 0 ? '\x1B[32m' : '\x1B[31m';
        print(
          '   Health Score: $color$sign${driftReport.scoreDelta.toStringAsFixed(1)}\x1B[0m',
        );
      }
      for (final s in driftReport.newSmells) {
        print('   \x1B[31m+ New smell:\x1B[0m $s');
      }
      for (final s in driftReport.resolvedSmells) {
        print('   \x1B[32m- Resolved smell:\x1B[0m $s');
      }
      for (final v in driftReport.newViolations) {
        print('   \x1B[31m+ New violation:\x1B[0m $v');
      }
      for (final v in driftReport.resolvedViolations) {
        print('   \x1B[32m- Resolved violation:\x1B[0m $v');
      }
    }
  }
  driftDetector.saveSnapshot(
    smells: smells,
    violations: violations,
    healthScore: healthScore,
  );

  print('\n📊 Found ${nodes.length} architectural elements:');
  if (visualize) {
    final visualizer = ProviderVisualizer();
    final mmd = visualizer.generateMermaid(graph);
    visualizer.saveGraph(projectRoot, mmd);
    print('   📈 Graph summary: ${visualizer.describeSummary(graph)}');
  }

  if (dashboard) {
    print('\n🌐 Launching Migration Dashboard...');
    print('📍 Access here: \x1B[34mhttp://localhost:8080\x1B[0m');
  }

  print('\n✨ Generating Riverpod Suggestions...');
  final generator = RiverpodGenerator();

  if (mode == 'safe') {
    print('🛡️  Running in Safe Mode: Injecting TODOs into source files...');
    final nodesByFile = <String, List<ProviderNode>>{};
    for (final node in nodes) {
      nodesByFile.putIfAbsent(node.filePath, () => []).add(node);
    }

    for (final entry in nodesByFile.entries) {
      final file = File(entry.key);
      if (!file.existsSync()) continue;

      String content = file.readAsStringSync();
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
              '// TODO(Migrator): Convert ${node.name} to @riverpod Notifier\n';
        } else if (node is ProviderDeclarationNode) {
          comment = '// TODO(Migrator): Replace with Riverpod provider\n';
        } else if (node is ConsumerNode) {
          comment =
              '// TODO(Migrator): Change to ConsumerWidget and use ref.watch\n';
        } else if (node is ProviderOfNode) {
          comment = '// TODO(Migrator): Replace with ref.read or ref.watch\n';
        }

        if (comment.isNotEmpty) {
          content = content.replaceRange(node.offset, node.offset, comment);
        }
      }

      file.writeAsStringSync(content);
      print('  ✅ Updated ${entry.key}');
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
      buffer.writeln('// 🚀 Auto-generated Riverpod migration suggestions');
      buffer.writeln();

      final processedTypes = <String>{};
      for (final node in entry.value) {
        if (node is ProviderOfNode) {
          if (processedTypes.contains('ProviderOf:${node.consumedClass}')) {
            continue;
          }
          processedTypes.add('ProviderOf:${node.consumedClass}');
        }
        buffer.writeln(generator.generateSuggestion(node));
        buffer.writeln();
      }

      newFile.writeAsStringSync(buffer.toString());
      print('  📄 Generated $newFilePath');
    }
  } else if (mode == 'aggressive') {
    print('🔥 Running in Aggressive Mode: Rewriting source files...');
    final transformer = RiverpodTransformer();
    final importManager = ImportManager();
    final analyticsManager = AnalyticsManager();
    int modifiedFilesCount = 0;
    final startTime = DateTime.now();

    final roiMetrics = analyticsManager.calculateMetrics(
      nodes: nodes,
      filesProcessed: packages.length,
      smells: smells,
      violations: violations,
    );

    final reportData = {
      'timestamp': DateTime.now().toIso8601String(),
      'targetPath': targetPath,
      'mode': mode,
      'metrics': roiMetrics,
      'modified_files': <String>[],
      'architecture_smells': smells
          .map(
            (s) => {
              'nodeId': s.nodeId,
              'name': s.name,
              'description': s.description,
              'severity': s.severity,
            },
          )
          .toList(),
      'governance_violations': violations
          .map(
            (v) => {
              'nodeId': v.nodeId,
              'ruleName': v.ruleName,
              'message': v.message,
              'severity': v.severity,
            },
          )
          .toList(),
      'summary': {
        'total_nodes': nodes.length,
        'logic_units': nodes.whereType<LogicUnitNode>().length,
        'widgets': nodes.whereType<WidgetNode>().length,
        'health_score': roiMetrics['architecture_health_score'],
        'duration_ms': DateTime.now().difference(startTime).inMilliseconds,
      },
    };

    final nodesByFile = <String, List<ProviderNode>>{};
    for (final node in nodes) {
      nodesByFile.putIfAbsent(node.filePath, () => []).add(node);
    }

    for (final entry in nodesByFile.entries) {
      final file = File(entry.key);
      if (!file.existsSync()) continue;

      final original = file.readAsStringSync();
      final edits = <TextEdit>[];
      for (final node in entry.value) {
        edits.addAll(transformer.transformNode(node, original));
      }

      String content = applyEdits(original, edits);
      if (content != original) {
        content = importManager.processImports(
          content,
          cleanProvider: cleanImports,
        );

        if (dryRun) {
          print('\n👀 Dry Run for ${entry.key}:');
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
      final reportFile = File('$projectRoot/migration_report.json');
      reportFile.writeAsStringSync(
        JsonEncoder.withIndent('  ').convert(reportData),
      );
      print('\n📊 Report generated at: ${reportFile.path}');
    }

    if (useAi) {
        print('\n🤖 Running AI-assisted architecture guidance...');
      final aiManager = AIManager();
        try {
          final architectureGuidance = await aiManager.buildArchitectureGuidance(
            graph: graph,
            smells: smells,
            violations: violations,
          );
          final methodGuidance = <AiGuidance>[];
          for (final node in nodes.whereType<LogicUnitNode>()) {
            for (final method in node.methods.where(
              (m) => m.callsNotifyListeners,
            )) {
              methodGuidance.add(
                await aiManager.refactorMethodBody(
                  className: node.name,
                  stateFields: node.stateVariables,
                  methodName: method.name,
                  methodBody: method.bodySnippet,
                  notifierType: node.notifierType,
                ),
              );
            }
          }

          final allGuidance = [...architectureGuidance, ...methodGuidance];
          if (allGuidance.isEmpty) {
            print('   \x1B[32m✓ No AI guidance candidates detected.\x1B[0m');
          } else {
            for (final guidance in allGuidance) {
              final sourceLabel = guidance.source == AiGuidanceSource.localLlm
                  ? 'LOCAL LLM'
                  : 'FALLBACK';
              final color = guidance.source == AiGuidanceSource.localLlm
                  ? '\x1B[36m'
                  : '\x1B[33m';
              print('   $color$sourceLabel\x1B[0m: ${guidance.title}');
              print('      Why: ${guidance.rationale}');
              print('      Next: ${guidance.recommendation}');
              if (guidance.fallbackReason != null) {
                print('      Note: ${guidance.fallbackReason}');
              }
            }
          }
        } finally {
          aiManager.dispose();
        }
      }

    print('\n🧹 Running dart format...');
    Process.runSync('dart', ['format', targetPath]);

    if (!dryRun) {
      final affectedPkgs = isMonorepo
          ? monorepo.migrateablePackages(
              (reportData['modified_files'] as List).cast<String>(),
            )
          : [PackageInfo(name: 'root', rootPath: projectRoot)];

      for (final pkg in affectedPkgs) {
        final pkgDep = DependencyManager(pkg.rootPath);
        await pkgDep.updateDependencies();
      }

      final genManager = GeneratedFileManager(projectRoot);
      final needsBuildRunner = genManager.pendingBuildRunnerFiles(
        (reportData['modified_files'] as List).cast<String>(),
      );
      if (needsBuildRunner.isNotEmpty) {
        print('\n⚙️  Run build_runner for ${needsBuildRunner.length} file(s).');
      }

      genManager.cleanStaleFiles();
    }

    print('\n✨ Migration Complete!');
    print('📝 Files modified: $modifiedFilesCount');
    print(
      '🧠 Architecture Health Score: ${roiMetrics['architecture_health_score']}/100',
    );
  }
}

void _printSimpleDiff(String original, String modified) {
  final originalLines = original.split('\n');
  final modifiedLines = modified.split('\n');
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

String resolveProjectRoot(String targetPath) {
  final type = FileSystemEntity.typeSync(targetPath, followLinks: false);
  if (type == FileSystemEntityType.file) {
    return File(targetPath).parent.path;
  }
  return targetPath;
}
