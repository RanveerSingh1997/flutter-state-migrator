import 'dart:io';

/// Packages to add under `dependencies:` after a Riverpod migration.
const _riverpodDeps = {
  'flutter_riverpod': '^2.6.1',
  'riverpod_annotation': '^2.6.1',
};

/// Packages to add under `dev_dependencies:` after a Riverpod migration.
const _riverpodDevDeps = {
  'riverpod_generator': '^2.6.1',
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

class DependencyUpdateResult {
  final List<String> added;
  final List<String> commented;

  const DependencyUpdateResult({
    required this.added,
    required this.commented,
  });

  bool get hasChanges => added.isNotEmpty || commented.isNotEmpty;
}

class DependencyManager {
  final String projectPath;

  DependencyManager(this.projectPath);

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
    return DependencyUpdateResult(added: added, commented: commented);
  }

  /// Returns true if [name] already appears as a non-commented dep key.
  bool _hasDep(String content, String name) {
    return RegExp('^\\s+${RegExp.escape(name)}:', multiLine: true)
        .hasMatch(content);
  }

  String _addDependency(String content, String name, String version) {
    final idx = content.indexOf(RegExp(r'^dependencies:', multiLine: true));
    if (idx == -1) return content;
    final eol = content.indexOf('\n', idx);
    return content.replaceRange(eol + 1, eol + 1, '  $name: $version\n');
  }

  String _addDevDependency(String content, String name, String version) {
    final idx = content.indexOf(
      RegExp(r'^dev_dependencies:', multiLine: true),
    );
    if (idx == -1) return content;
    final eol = content.indexOf('\n', idx);
    return content.replaceRange(eol + 1, eol + 1, '  $name: $version\n');
  }
}
