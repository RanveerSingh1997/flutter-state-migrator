/// Base interfaces for compile-time migrator plugins.
library;

import 'package:analyzer/dart/ast/visitor.dart';
import '../models/ir_models.dart';

/// Base interface that every plugin package must implement.
abstract class MigrationPlugin {
  /// Unique human-readable identifier for this plugin.
  String get name;

  /// Semantic version string of the plugin.
  String get version;
}

/// An AST visitor that a plugin uses to detect custom IR nodes.
abstract class CustomAdapter extends RecursiveAstVisitor<void> {
  /// IR nodes found during the most recent visitation.
  List<ProviderNode> get detectedNodes;

  /// Clears [detectedNodes] so the adapter can be reused across files.
  void reset();
}

/// Applies source transformations for nodes detected by a [CustomAdapter].
abstract class CustomTransformer {
  /// Returns the rewritten [source], applying transformations for [nodes].
  String transform(String source, List<ProviderNode> nodes);
}
