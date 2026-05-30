import 'dart:io';

import 'package:yaml/yaml.dart';

/// Parsed settings from an optional `migrator_config.yaml` at the project root.
///
/// Keys: `provider_naming`, `auto_merge_state`, `governance`, `architecture_roles`.
/// Safe defaults are used when the file is absent or a key is missing.
class MigratorConfig {
  /// Naming convention for generated providers: `'camelCase'` (default) or `'snake_case'`.
  final String providerNaming;

  /// When true, multi-field state is automatically collapsed into a single state class.
  final bool autoMergeState;

  /// Governance rules map, forwarded directly to [GovernanceEngine].
  final Map<String, dynamic> governance;

  /// Optional overrides mapping class-name suffixes to architecture roles.
  final Map<String, String> architectureRoles;

  /// Creates a [MigratorConfig] with optional overrides; all fields have safe defaults.
  MigratorConfig({
    this.providerNaming = 'camelCase',
    this.autoMergeState = true,
    this.governance = const {},
    this.architectureRoles = const {},
  });

  /// Parses [yamlString] and returns a [MigratorConfig].
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

/// Loads [MigratorConfig] from `migrator_config.yaml` in the project root.
class ConfigurationManager {
  /// Reads and parses `migrator_config.yaml` from [projectPath].
  ///
  /// Returns default config when the file is missing or unparseable.
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
