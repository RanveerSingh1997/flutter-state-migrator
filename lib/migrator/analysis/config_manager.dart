import 'dart:io';

import 'package:yaml/yaml.dart';

class MigratorConfig {
  final String providerNaming;
  final bool autoMergeState;
  final Map<String, dynamic> governance;
  final Map<String, String> architectureRoles;

  MigratorConfig({
    this.providerNaming = 'camelCase',
    this.autoMergeState = true,
    this.governance = const {},
    this.architectureRoles = const {},
  });

  factory MigratorConfig.fromYaml(String yamlString) {
    final doc = loadYaml(yamlString);
    if (doc == null) return MigratorConfig();

    return MigratorConfig(
      providerNaming: doc['provider_naming'] ?? 'camelCase',
      autoMergeState: doc['auto_merge_state'] ?? true,
      governance: doc['governance'] != null
          ? Map<String, dynamic>.from(doc['governance'])
          : const {},
      architectureRoles: doc['architecture_roles'] != null
          ? Map<String, String>.from(doc['architecture_roles'])
          : const {},
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
        print('⚠️ Error parsing migrator_config.yaml: $e. Using defaults.');
      }
    }
    return MigratorConfig();
  }
}
