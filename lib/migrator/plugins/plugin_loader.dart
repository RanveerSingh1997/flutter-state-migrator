import 'dart:io';
import 'plugin_base.dart';

class PluginLoader {
  final List<CustomAdapter> loadedAdapters = [];
  final List<CustomTransformer> loadedTransformers = [];

  void loadPlugins(String projectPath) {
    final pluginDir = Directory('$projectPath/migrator/plugins');
    if (!pluginDir.existsSync()) return;

    print('🔌 Loading custom plugins from ${pluginDir.path}...');

    // In a real implementation, we would use something like 'dart:isolate'
    // or a dynamic library loader to instantiate these from .dart files.
    // For this prototype, we'll look for registrations.
  }

  void registerAdapter(CustomAdapter adapter) {
    loadedAdapters.add(adapter);
  }

  void registerTransformer(CustomTransformer transformer) {
    loadedTransformers.add(transformer);
  }
}
