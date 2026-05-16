import 'dart:io';
import 'package:path/path.dart' as p;

/// Directory names that are never scanned for packages.
const _excludedDirs = {
  'build',
  '.dart_tool',
  '.pub-cache',
  '.pub',
  '.git',
  '.fvm',
  '.idea',
  '.vscode',
};

class PackageInfo {
  final String name;
  final String rootPath;

  PackageInfo({required this.name, required this.rootPath});

  @override
  String toString() => '$name ($rootPath)';
}

class MonorepoManager {
  final String rootPath;

  MonorepoManager(this.rootPath);

  /// True when more than one Dart package exists under [rootPath].
  bool get isMonorepo => findPackages().length > 1;

  /// Returns all Dart packages under [rootPath], skipping excluded directories.
  List<PackageInfo> findPackages() {
    final packages = <PackageInfo>[];
    final directory = Directory(rootPath);
    if (!directory.existsSync()) return packages;

    _collectPubspecs(directory, packages);
    return packages;
  }

  /// Filters [findPackages()] to only packages whose source trees contain
  /// files referenced by [nodeFilePaths].
  List<PackageInfo> migrateablePackages(Iterable<String> nodeFilePaths) {
    final nodeFiles = nodeFilePaths.toSet();
    return findPackages().where((pkg) {
      return nodeFiles.any((f) => f.startsWith(pkg.rootPath));
    }).toList();
  }

  void _collectPubspecs(Directory dir, List<PackageInfo> out) {
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      return;
    }

    for (final entry in entries) {
      final name = p.basename(entry.path);
      if (_excludedDirs.contains(name)) continue;

      if (entry is Directory) {
        _collectPubspecs(entry, out);
      } else if (entry is File && name == 'pubspec.yaml') {
        final packageRoot = p.dirname(entry.path);
        final content = entry.readAsStringSync();
        final match = RegExp(
          r'^name:\s+([a-zA-Z0-9_]+)',
          multiLine: true,
        ).firstMatch(content);
        if (match != null) {
          out.add(PackageInfo(name: match.group(1)!, rootPath: packageRoot));
        }
      }
    }
  }
}
