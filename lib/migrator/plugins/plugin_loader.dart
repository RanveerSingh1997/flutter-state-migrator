import 'dart:io';
import 'plugin_base.dart';

class PluginLoader {
  final List<CustomAdapter> loadedAdapters = [];
  final List<CustomTransformer> loadedTransformers = [];

  void loadPlugins(String projectPath) {
    final pluginDir = Directory('$projectPath/migrator/plugins');
    if (!pluginDir.existsSync()) return;

    print(
      '\x1B[33m⚠️  [EXPERIMENTAL] Plugin directory detected at ${pluginDir.path}.\x1B[0m',
    );
    print(
      '   Plugin loading is not yet implemented. Dart has no runtime .dart file loading;',
    );
    print(
      '   plugins must be compiled into the tool. Skipping plugin discovery.',
    );
  }

  void registerAdapter(CustomAdapter adapter) {
    loadedAdapters.add(adapter);
  }

  void registerTransformer(CustomTransformer transformer) {
    loadedTransformers.add(transformer);
  }
}
