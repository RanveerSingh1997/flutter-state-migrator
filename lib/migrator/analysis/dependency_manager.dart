import 'dart:io';

class DependencyManager {
  final String projectPath;

  DependencyManager(this.projectPath);

  Future<void> updateDependencies() async {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!pubspecFile.existsSync()) return;

    print('📦 Updating dependencies in pubspec.yaml...');
    String content = pubspecFile.readAsStringSync();

    // 1. Add Riverpod dependencies if missing
    if (!content.contains('flutter_riverpod:')) {
      content = _addDependency(content, 'flutter_riverpod', '^2.0.0');
    }
    if (!content.contains('riverpod_annotation:')) {
      content = _addDependency(content, 'riverpod_annotation', '^2.0.0');
    }
    if (!content.contains('riverpod_generator:')) {
      content = _addDevDependency(content, 'riverpod_generator', '^2.0.0');
    }
    if (!content.contains('build_runner:')) {
      content = _addDevDependency(content, 'build_runner', '^2.3.0');
    }

    // 2. Remove legacy dependencies (optional, but clean)
    // We'll comment them out instead of deleting to be safe
    content = content.replaceAll(RegExp(r'^(\s+)(provider:)', multiLine: true), r'$1# $2');
    content = content.replaceAll(RegExp(r'^(\s+)(flutter_bloc:)', multiLine: true), r'$1# $2');

    pubspecFile.writeAsStringSync(content);
    print('✅ pubspec.yaml updated successfully.');
  }

  String _addDependency(String content, String name, String version) {
    final depIndex = content.indexOf('dependencies:');
    if (depIndex == -1) return content;

    final nextLineIndex = content.indexOf('\n', depIndex) + 1;
    return content.replaceRange(nextLineIndex, nextLineIndex, '  $name: $version\n');
  }

  String _addDevDependency(String content, String name, String version) {
    final depIndex = content.indexOf('dev_dependencies:');
    if (depIndex == -1) return content;

    final nextLineIndex = content.indexOf('\n', depIndex) + 1;
    return content.replaceRange(nextLineIndex, nextLineIndex, '  $name: $version\n');
  }
}
