import 'dart:io';

/// Packages to add under `dependencies:` after a Riverpod migration.
const _riverpodDeps = {
  'flutter_riverpod': '^3.3.1',
  'riverpod_annotation': '^3.3.1',
};

/// Packages to add under `dev_dependencies:` after a Riverpod migration.
const _riverpodDevDeps = {
  'riverpod_generator': '^3.3.1',
  'build_runner': '^2.4.0',
};

/// Legacy framework packages that should be commented-out after migration.
const _legacyDeps = [
  'provider',
  'flutter_bloc',
  'bloc',
  'get',
  'getx',
  'mobx',
  'flutter_mobx',
];

/// Result of a [DependencyManager.updateDependencies] call.
class DependencyUpdateResult {
  /// Packages that were added to `pubspec.yaml`.
  final List<String> added;

  /// Packages that were commented out in `pubspec.yaml`.
  final List<String> commented;

  /// True when `flutter pub get` completed successfully after the update.
  final bool pubGetSucceeded;

  /// Creates a [DependencyUpdateResult].
  const DependencyUpdateResult({
    required this.added,
    required this.commented,
    this.pubGetSucceeded = false,
  });

  /// True when any packages were added or commented.
  bool get hasChanges => added.isNotEmpty || commented.isNotEmpty;
}

/// Adds Riverpod packages to `pubspec.yaml` and comments out legacy framework deps.
///
/// Adds `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`,
/// and `build_runner`; comments out `provider`, `flutter_bloc`, `get`, `mobx`, etc.
class DependencyManager {
  /// Absolute path to the project whose `pubspec.yaml` will be updated.
  final String projectPath;

  /// Creates a [DependencyManager] for the project at [projectPath].
  DependencyManager(this.projectPath);

  /// Updates `pubspec.yaml` and returns a summary of changes made.
  Future<DependencyUpdateResult> updateDependencies() async {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      return const DependencyUpdateResult(added: [], commented: []);
    }

    String content = pubspecFile.readAsStringSync();
    final added = <String>[];
    final commented = <String>[];

    // Ensure dev_dependencies section exists before inserting into it.
    if (!content.contains('dev_dependencies:')) {
      content = '$content\ndev_dependencies:\n';
    }

    for (final entry in _riverpodDeps.entries) {
      if (!_hasDep(content, entry.key)) {
        content = _addDependency(content, entry.key, entry.value);
        added.add(entry.key);
      }
    }
    for (final entry in _riverpodDevDeps.entries) {
      if (!_hasDep(content, entry.key)) {
        content = _addDevDependency(content, entry.key, entry.value);
        added.add(entry.key);
      }
    }

    // Comment out legacy deps using replaceAllMapped so capture groups work.
    for (final pkg in _legacyDeps) {
      final pattern = RegExp(
        '^(\\s+)(${RegExp.escape(pkg)}:)',
        multiLine: true,
      );
      if (pattern.hasMatch(content)) {
        content = content.replaceAllMapped(
          pattern,
          (m) => '${m.group(1)}# ${m.group(2)}',
        );
        commented.add(pkg);
      }
    }

    pubspecFile.writeAsStringSync(content);

    // Run `flutter pub get` so the project compiles immediately after migration.
    bool pubGetOk = false;
    if (added.isNotEmpty || commented.isNotEmpty) {
      try {
        final result = await Process.run(
          'flutter',
          ['pub', 'get'],
          workingDirectory: projectPath,
        );
        pubGetOk = result.exitCode == 0;
        if (!pubGetOk) {
          stderr.writeln(
            '[Migrator] WARNING: flutter pub get failed '
            '(exit ${result.exitCode}). Run it manually.\n'
            '${result.stderr}',
          );
        }
      } catch (e) {
        stderr.writeln('[Migrator] WARNING: Could not run flutter pub get: $e');
      }
    }

    return DependencyUpdateResult(
      added: added,
      commented: commented,
      pubGetSucceeded: pubGetOk,
    );
  }

  /// Returns true if [name] already appears as a non-commented dep key.
  bool _hasDep(String content, String name) {
    return RegExp(
      '^\\s+${RegExp.escape(name)}:',
      multiLine: true,
    ).hasMatch(content);
  }

  String _addDependency(String content, String name, String version) {
    final idx = content.indexOf(RegExp(r'^dependencies:', multiLine: true));
    if (idx == -1) return content;
    final eol = content.indexOf('\n', idx);
    return content.replaceRange(eol + 1, eol + 1, '  $name: $version\n');
  }

  String _addDevDependency(String content, String name, String version) {
    final idx = content.indexOf(RegExp(r'^dev_dependencies:', multiLine: true));
    if (idx == -1) return content;
    final eol = content.indexOf('\n', idx);
    return content.replaceRange(eol + 1, eol + 1, '  $name: $version\n');
  }
}
