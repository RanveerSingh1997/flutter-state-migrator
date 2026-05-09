import 'dart:io';
import 'package:path/path.dart' as p;

class PackageInfo {
  final String name;
  final String rootPath;

  PackageInfo({required this.name, required this.rootPath});
}

class MonorepoManager {
  final String rootPath;

  MonorepoManager(this.rootPath);

  List<PackageInfo> findPackages() {
    final packages = <PackageInfo>[];
    final directory = Directory(rootPath);

    if (!directory.existsSync()) return packages;

    final pubspecs = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => p.basename(f.path) == 'pubspec.yaml');

    for (final pubspec in pubspecs) {
      final packageRoot = p.dirname(pubspec.path);
      final content = pubspec.readAsStringSync();
      final nameMatch = RegExp(r'name:\s+([a-zA-Z0-9_]+)').firstMatch(content);
      if (nameMatch != null) {
        packages.add(
          PackageInfo(name: nameMatch.group(1)!, rootPath: packageRoot),
        );
      }
    }
    return packages;
  }
}
