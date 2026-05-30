/// Plugin discovery and registration (experimental placeholder).
library;

import 'dart:io';
import 'plugin_base.dart';

/// Discovers and registers plugins from a project's `migrator/plugins/` directory.
///
/// **Note:** Runtime loading is not yet implemented — plugins must be compiled
/// into the tool. Detection only prints a warning and returns.
class PluginLoader {
  /// Adapters registered via [registerAdapter].
  final List<CustomAdapter> loadedAdapters = [];

  /// Transformers registered via [registerTransformer].
  final List<CustomTransformer> loadedTransformers = [];

  /// Scans [projectPath] for a `migrator/plugins/` directory and prints a
  /// warning when found. Plugin loading is a placeholder for future work.
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

  /// Registers a [CustomAdapter] to be run during each file scan.
  void registerAdapter(CustomAdapter adapter) {
    loadedAdapters.add(adapter);
  }

  /// Registers a [CustomTransformer] to be applied after scanning.
  void registerTransformer(CustomTransformer transformer) {
    loadedTransformers.add(transformer);
  }
}
