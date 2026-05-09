import 'dart:convert';
import 'dart:io';

class SnapshotManager {
  final String projectPath;
  static const String _snapshotDir = '.migrator_snapshots';
  static const String _manifestName = 'manifest.json';

  // Directories to skip when scanning for files to back up.
  static const List<String> _skipDirs = [
    '.migrator_snapshots',
    '.dart_tool',
    '.git',
    'build',
    '.idea',
    '.vscode',
  ];

  SnapshotManager(this.projectPath);

  /// Copies every `.dart` and `pubspec.yaml` file under [projectPath] into a
  /// timestamped snapshot directory and writes a manifest for rollback.
  /// Returns the path of the created snapshot directory.
  Future<String> createSnapshot() async {
    final snapshotsRoot = Directory('$projectPath/$_snapshotDir');
    if (!snapshotsRoot.existsSync()) {
      snapshotsRoot.createSync(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupDir = Directory('${snapshotsRoot.path}/$timestamp');
    backupDir.createSync();

    print('🛡️  Creating project snapshot...');

    final files = _collectFiles(Directory(projectPath));
    final manifest = <String, String>{};

    for (final file in files) {
      final relative = _relativePath(file.path);
      final dest = File('${backupDir.path}/$relative');
      dest.parent.createSync(recursive: true);
      file.copySync(dest.path);
      manifest[relative] = dest.path;
    }

    final manifestFile = File('${backupDir.path}/$_manifestName');
    manifestFile.writeAsStringSync(
      JsonEncoder.withIndent('  ').convert({
        'timestamp': DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String(),
        'projectPath': projectPath,
        'fileCount': files.length,
        'files': manifest,
      }),
    );

    print('✅ Snapshot created: ${files.length} files → ${backupDir.path}');
    return backupDir.path;
  }

  /// Restores the project from the latest (or a specific) snapshot.
  Future<void> rollback({String? snapshotPath}) async {
    final target = snapshotPath != null
        ? Directory(snapshotPath)
        : _latestSnapshot();

    if (target == null) {
      print('❌ No snapshots found. Run a migration first.');
      return;
    }

    final manifestFile = File('${target.path}/$_manifestName');
    if (!manifestFile.existsSync()) {
      print('❌ Snapshot manifest missing at ${target.path}');
      return;
    }

    final data = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final files = data['files'] as Map<String, dynamic>;
    final ts = data['timestamp'] as String;

    print('⏪ Rolling back to snapshot from $ts...');

    int restored = 0;
    for (final entry in files.entries) {
      final dest = File('$projectPath/${entry.key}');
      final src = File(entry.value as String);
      if (src.existsSync()) {
        dest.parent.createSync(recursive: true);
        src.copySync(dest.path);
        restored++;
      }
    }

    print('✅ Rollback complete: $restored/${files.length} files restored.');
  }

  /// Returns metadata for every available snapshot, newest first.
  List<Map<String, dynamic>> listSnapshots() {
    final snapshotsRoot = Directory('$projectPath/$_snapshotDir');
    if (!snapshotsRoot.existsSync()) return [];

    final dirs = snapshotsRoot
        .listSync()
        .whereType<Directory>()
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    final result = <Map<String, dynamic>>[];
    for (final dir in dirs) {
      final mf = File('${dir.path}/$_manifestName');
      if (!mf.existsSync()) continue;
      final data = jsonDecode(mf.readAsStringSync()) as Map<String, dynamic>;
      result.add({
        'path': dir.path,
        'timestamp': data['timestamp'],
        'fileCount': data['fileCount'],
      });
    }
    return result;
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  List<File> _collectFiles(Directory dir) {
    final results = <File>[];
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = _relativePath(entity.path);
      if (_skipDirs.any((d) => rel.startsWith('$d/'))) continue;
      if (entity.path.endsWith('.dart') ||
          entity.path.endsWith('pubspec.yaml') ||
          entity.path.endsWith('pubspec.lock')) {
        results.add(entity);
      }
    }
    return results;
  }

  String _relativePath(String absolutePath) {
    final base = projectPath.endsWith('/') ? projectPath : '$projectPath/';
    return absolutePath.startsWith(base)
        ? absolutePath.substring(base.length)
        : absolutePath;
  }

  Directory? _latestSnapshot() {
    final snapshotsRoot = Directory('$projectPath/$_snapshotDir');
    if (!snapshotsRoot.existsSync()) return null;
    final dirs = snapshotsRoot
        .listSync()
        .whereType<Directory>()
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return dirs.isEmpty ? null : dirs.first;
  }
}
