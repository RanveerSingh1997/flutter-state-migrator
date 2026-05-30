import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';

import '../models/ir_models.dart';
import 'provider_adapter.dart';
import 'bloc_adapter.dart';
import 'getx_adapter.dart';
import 'mobx_adapter.dart';
import '../plugins/plugin_loader.dart';

/// Entry-point scanner that walks Dart files under [targetPath] and emits
/// [ProviderNode] IR nodes by running all four framework adapters in sequence.
///
/// Accepts both a single `.dart` file and a directory (scanned recursively).
/// Generated files (`*.g.dart`) are automatically excluded.
class AstScanner {
  /// Path to the Flutter project directory or a single `.dart` file to scan.
  final String targetPath;
  final _pluginLoader = PluginLoader();

  /// Creates an [AstScanner] and initialises any plugins found under [targetPath].
  AstScanner(this.targetPath) {
    _pluginLoader.loadPlugins(targetPath);
  }

  /// Scans [targetPath] and returns the flat list of detected [ProviderNode]s.
  List<ProviderNode> scanProject() {
    final irNodes = <ProviderNode>[];
    final targetType = FileSystemEntity.typeSync(
      targetPath,
      followLinks: false,
    );

    if (targetType == FileSystemEntityType.notFound) {
      print('Directory $targetPath does not exist.');
      return irNodes;
    }

    if (targetType == FileSystemEntityType.file) {
      return _scanFile(File(targetPath));
    }

    final directory = Directory(targetPath);

    final dartFiles = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.dart') && !file.path.contains('.g.dart'),
        );

    for (final file in dartFiles) {
      final fileNodes = _scanFile(file);
      irNodes.addAll(fileNodes);
    }

    return irNodes;
  }

  List<ProviderNode> _scanFile(File file) {
    try {
      final result = parseString(
        content: file.readAsStringSync(),
        path: file.path,
        throwIfDiagnostics: false,
      );
      final adapter = ProviderAdapter(file.path);
      final blocAdapter = BlocAdapter(file.path);
      final getxAdapter = GetXAdapter(file.path);
      final mobxAdapter = MobXAdapter(file.path);

      result.unit.visitChildren(adapter);
      result.unit.visitChildren(blocAdapter);
      result.unit.visitChildren(getxAdapter);
      result.unit.visitChildren(mobxAdapter);

      final customNodes = <ProviderNode>[];
      for (final customAdapter in _pluginLoader.loadedAdapters) {
        customAdapter.reset();
        result.unit.visitChildren(customAdapter);
        customNodes.addAll(customAdapter.detectedNodes);
      }

      return [
        ...adapter.nodes,
        ...blocAdapter.nodes,
        ...getxAdapter.nodes,
        ...mobxAdapter.nodes,
        ...customNodes,
      ];
    } catch (e) {
      print('Error parsing ${file.path}: $e');
      return [];
    }
  }
}
