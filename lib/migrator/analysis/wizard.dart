import 'dart:io';

class WizardConfig {
  final String targetPath;
  final String mode;
  final bool useAi;
  final bool dryRun;
  final bool cleanImports;
  final bool generateReport;
  final bool visualize;

  WizardConfig({
    required this.targetPath,
    required this.mode,
    required this.useAi,
    this.dryRun = false,
    this.cleanImports = true,
    this.generateReport = true,
    this.visualize = false,
  });

  Map<String, dynamic> toJson() => {
    'targetPath': targetPath,
    'mode': mode,
    'useAi': useAi,
    'dryRun': dryRun,
    'cleanImports': cleanImports,
    'generateReport': generateReport,
    'visualize': visualize,
  };
}

class InteractiveWizard {
  WizardConfig start() {
    _printBanner();

    final targetPath = _prompt(
      '📂 Enter the target path to migrate',
      defaultValue: 'lib',
    );

    final detectedLibs = _detectLibraries(targetPath);
    if (detectedLibs.isNotEmpty) {
      print('\n\x1B[33m🔍 Detected state management libraries:\x1B[0m');
      for (final lib in detectedLibs) {
        print('   • $lib');
      }
      final proceed = _promptYesNo(
        '\nProceed with migrating these to Riverpod?',
        defaultYes: true,
      );
      if (!proceed) {
        print('\x1B[31mMigration cancelled.\x1B[0m');
        exit(0);
      }
    } else {
      print(
        '\n\x1B[90m  (No known state management libraries detected in pubspec.yaml)\x1B[0m',
      );
    }

    print('\n\x1B[1mWhich migration mode would you like to use?\x1B[0m');
    print(
      '  \x1B[36m1.\x1B[0m safe       – Analyze only, inject TODO comments',
    );
    print(
      '  \x1B[36m2.\x1B[0m assisted   – Generate Riverpod files alongside old code',
    );
    print(
      '  \x1B[36m3.\x1B[0m aggressive – Fully rewrite and replace legacy code',
    );
    final modeChoice = _prompt('Select mode (1–3)', defaultValue: '3');
    final mode = _mapMode(modeChoice);

    print('');
    final dryRun = _promptYesNo(
      '👁️  Preview changes without writing files (dry run)?',
    );
    final cleanImports = _promptYesNo(
      '🧹 Auto-clean unused Provider imports after migration?',
      defaultYes: true,
    );
    final generateReport = _promptYesNo(
      '📊 Generate a migration_report.json audit file?',
      defaultYes: true,
    );
    final visualize = _promptYesNo(
      '🗺️  Generate a provider dependency graph (Mermaid format)?',
    );
    final useAi = _promptYesNo(
      '🤖 Enable AI-assisted logic refactoring (requires local LLM)?',
    );

    final config = WizardConfig(
      targetPath: targetPath,
      mode: mode,
      useAi: useAi,
      dryRun: dryRun,
      cleanImports: cleanImports,
      generateReport: generateReport,
      visualize: visualize,
    );

    _saveConfig(config);
    return config;
  }

  void _printBanner() {
    print(
      '\n\x1B[1m\x1B[35m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1B[0m',
    );
    print('\x1B[1m🧙  Flutter State Migrator — Interactive Wizard\x1B[0m');
    print(
      '\x1B[1m\x1B[35m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1B[0m\n',
    );
  }

  List<String> _detectLibraries(String targetPath) {
    final detected = <String>[];
    // Check pubspec.yaml adjacent to the target path, or in cwd
    final candidates = [
      File('$targetPath/../pubspec.yaml'),
      File('pubspec.yaml'),
    ];

    String? content;
    for (final f in candidates) {
      if (f.existsSync()) {
        content = f.readAsStringSync();
        break;
      }
    }

    if (content == null) return detected;

    if (RegExp(r'^\s+provider:', multiLine: true).hasMatch(content)) {
      detected.add('provider');
    }
    if (RegExp(r'^\s+flutter_bloc:', multiLine: true).hasMatch(content)) {
      detected.add('flutter_bloc');
    }
    if (RegExp(r'^\s+get:', multiLine: true).hasMatch(content)) {
      detected.add('get (GetX)');
    }
    if (RegExp(r'^\s+mobx:', multiLine: true).hasMatch(content)) {
      detected.add('mobx');
    }
    return detected;
  }

  String _prompt(String message, {String? defaultValue}) {
    final defaultSuffix = defaultValue != null
        ? ' [\x1B[33m$defaultValue\x1B[0m]'
        : '';
    stdout.write('$message$defaultSuffix: ');
    final input = stdin.readLineSync()?.trim() ?? '';
    return input.isEmpty && defaultValue != null ? defaultValue : input;
  }

  bool _promptYesNo(String message, {bool defaultYes = false}) {
    final hint = defaultYes ? '\x1B[90m[Y/n]\x1B[0m' : '\x1B[90m[y/N]\x1B[0m';
    stdout.write('$message $hint: ');
    final input = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    if (input.isEmpty) return defaultYes;
    return input == 'y' || input == 'yes';
  }

  String _mapMode(String choice) {
    switch (choice) {
      case '1':
        return 'safe';
      case '2':
        return 'assisted';
      default:
        return 'aggressive';
    }
  }

  void _saveConfig(WizardConfig config) {
    final file = File('migrator.yaml');
    final yaml =
        '''
# Auto-generated by Flutter State Migrator Wizard
migrator:
  target_path: ${config.targetPath}
  mode: ${config.mode}
  options:
    dry_run: ${config.dryRun}
    clean_imports: ${config.cleanImports}
    generate_report: ${config.generateReport}
    visualize: ${config.visualize}
  features:
    ai_assisted: ${config.useAi}
''';
    file.writeAsStringSync(yaml);
    print('\n\x1B[32m✅ Configuration saved to migrator.yaml\x1B[0m');
  }
}
