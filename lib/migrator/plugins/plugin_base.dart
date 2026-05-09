import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import '../models/ir_models.dart';

abstract class MigrationPlugin {
  String get name;
  String get version;
}

abstract class CustomAdapter extends RecursiveAstVisitor<void> {
  List<ProviderNode> get detectedNodes;
  void reset();
}

abstract class CustomTransformer {
  String transform(String source, List<ProviderNode> nodes);
}
