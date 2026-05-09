import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/ir_models.dart';
import 'provider_adapter.dart';

class AstScanner {
  final String targetPath;
  
  AstScanner(this.targetPath);

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
        .where((file) => file.path.endsWith('.dart') && !file.path.contains('.g.dart'));

    for (final file in dartFiles) {
      final fileNodes = _scanFile(file);
      irNodes.addAll(fileNodes);
    }
    
    return irNodes;
  }

  List<ProviderNode> _scanFile(File file) {
    try {
      final result = parseString(content: file.readAsStringSync(), path: file.path);
      final adapter = ProviderAdapter(file.path);
      result.unit.visitChildren(adapter);
      return adapter.nodes;
    } catch (e) {
      print('Error parsing ${file.path}: $e');
      return [];
    }
  }
}
