import 'dart:io';
import 'package:yaml/yaml.dart';

class MigratorConfig {
  final String providerNaming;
  final bool autoMergeState;

  MigratorConfig({
    this.providerNaming = 'camelCase',
    this.autoMergeState = true,
  });

  factory MigratorConfig.fromYaml(String yamlString) {
    final doc = loadYaml(yamlString);
    return MigratorConfig(
      providerNaming: doc['provider_naming'] ?? 'camelCase',
      autoMergeState: doc['auto_merge_state'] ?? true,
    );
  }
}

class ConfigurationManager {
  static MigratorConfig loadConfig(String projectPath) {
    final configFile = File('$projectPath/migrator_config.yaml');
    if (configFile.existsSync()) {
      try {
        return MigratorConfig.fromYaml(configFile.readAsStringSync());
      } catch (e) {
        print('⚠️ Error parsing migrator_config.yaml, using defaults.');
      }
    }
    return MigratorConfig();
  }
}
