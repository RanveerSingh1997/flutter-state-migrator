import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';

import '../models/ir_models.dart';
import 'provider_adapter.dart';
import 'bloc_adapter.dart';
import 'getx_adapter.dart';
import 'mobx_adapter.dart';
import '../plugins/plugin_loader.dart';

class AstScanner {
  final String targetPath;
  final _pluginLoader = PluginLoader();

  AstScanner(this.targetPath) {
    _pluginLoader.loadPlugins(targetPath);
  }

  List<ProviderNode> scanProject() {
    final irNodes = <ProviderNode>[];
    final directory = Directory(targetPath);

    if (!directory.existsSync()) {
      print('Directory $targetPath does not exist.');
      return irNodes;
    }

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
