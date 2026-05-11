import 'dart:io';
import 'package:path/path.dart' as p;

class GeneratedFileManager {
  final String projectPath;

  GeneratedFileManager(this.projectPath);

  /// Returns every `*.g.dart` file under [projectPath], excluding build/ and
  /// hidden directories.
  List<File> listGeneratedFiles() {
    final dir = Directory(projectPath);
    if (!dir.existsSync()) return [];

    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.g.dart'))
        .where((f) => !_isExcluded(f.path))
        .toList();
  }

  /// Returns `*.g.dart` files whose companion source file no longer declares
  /// them via a `part '*.g.dart';` directive — i.e. stale leftovers.
  List<File> findStaleGeneratedFiles() {
    final stale = <File>[];
    for (final gFile in listGeneratedFiles()) {
      final sourcePath = gFile.path.replaceAll('.g.dart', '.dart');
      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) {
        stale.add(gFile);
        continue;
      }
      final sourceContent = sourceFile.readAsStringSync();
      final basename = p.basename(gFile.path);
      final hasPartDirective = RegExp(
        "part\\s+'${RegExp.escape(basename)}'",
      ).hasMatch(sourceContent);
      if (!hasPartDirective) stale.add(gFile);
    }
    return stale;
  }

  /// Deletes stale `*.g.dart` files. Returns the number of files removed.
  /// When [dryRun] is true, only reports; does not delete.
  int cleanStaleFiles({bool dryRun = false}) {
    final stale = findStaleGeneratedFiles();
    for (final f in stale) {
      if (!dryRun) f.deleteSync();
    }
    return stale.length;
  }

  /// Given a list of source files that were rewritten, returns those that now
  /// contain a `part '*.g.dart';` directive and therefore need `build_runner`.
  List<String> pendingBuildRunnerFiles(List<String> modifiedFilePaths) {
    final pending = <String>[];
    for (final path in modifiedFilePaths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final content = file.readAsStringSync();
      if (RegExp(r"part '[^']+\.g\.dart';").hasMatch(content)) {
        pending.add(path);
      }
    }
    return pending;
  }

  static bool _isExcluded(String path) {
    const excluded = {
      'build',
      '.dart_tool',
      '.pub-cache',
      '.git',
      '.fvm',
    };
    return path
        .split(p.separator)
        .any((segment) => excluded.contains(segment));
  }
}
