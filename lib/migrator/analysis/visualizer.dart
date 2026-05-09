import 'dart:io';
import '../models/ir_models.dart';

class ProviderVisualizer {
  String generateMermaid(List<ProviderNode> nodes) {
    final buffer = StringBuffer();
    buffer.writeln('graph TD');
    
    final logicUnits = nodes.whereType<LogicUnitNode>().toList();
    final declarations = nodes.whereType<ProviderDeclarationNode>().toList();
    final consumers = nodes.whereType<ConsumerNode>().toList();
    final selectors = nodes.whereType<SelectorNode>().toList();
    final providerOfs = nodes.whereType<ProviderOfNode>().toList();

    // 1. Draw logic units and their providers
    for (final node in logicUnits) {
      final safeName = _sanitize(node.name);
      buffer.writeln('  $safeName[${node.name} Logic]');
    }

    for (final node in declarations) {
      final safeClass = _sanitize(node.providedClass);
      final providerName = _sanitize('${node.providedClass}Provider');
      buffer.writeln('  $providerName(($providerName))');
      buffer.writeln('  $safeClass --> $providerName');
    }

    // 2. Draw consumers
    for (final node in consumers) {
      final safeConsumer = _sanitize(node.consumedClass);
      final providerName = _sanitize('${node.consumedClass}Provider');
      buffer.writeln('  $providerName -.-> ConsumerWidget');
    }

    for (final node in selectors) {
      final safeConsumer = _sanitize(node.consumedClass);
      final providerName = _sanitize('${node.consumedClass}Provider');
      buffer.writeln('  $providerName -.-> SelectorWidget');
    }

    for (final node in providerOfs) {
      final safeConsumer = _sanitize(node.consumedClass);
      final providerName = _sanitize('${node.consumedClass}Provider');
      buffer.writeln('  $providerName -.-> ContextReadWatch');
    }

    return buffer.toString();
  }

  void saveGraph(String targetPath, String content) {
    final file = File('$targetPath/dependency_graph.mmd');
    file.writeAsStringSync(content);
    print('🎨 Dependency graph saved to: \x1B[33m${file.path}\x1B[0m');
  }

  String _sanitize(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }
}
