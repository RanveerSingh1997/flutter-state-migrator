import 'package:test/test.dart';
import 'package:flutter_state_migrator/migrator/scanner/ast_scanner.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'dart:io';

void main() {
  group('Universal Migration Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('migrator_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('Detects Provider ChangeNotifier', () {
      final file = File('${tempDir.path}/counter.dart');
      file.writeAsStringSync('class Counter extends ChangeNotifier { int count = 0; }');
      
      final scanner = AstScanner(tempDir.path);
      final nodes = scanner.scanProject();
      
      expect(nodes.any((n) => n is LogicUnitNode && n.name == 'Counter'), isTrue);
    });

    test('Detects Bloc / Cubit', () {
      final file = File('${tempDir.path}/counter_cubit.dart');
      file.writeAsStringSync('class CounterCubit extends Cubit<int> { CounterCubit() : super(0); }');
      
      final scanner = AstScanner(tempDir.path);
      final nodes = scanner.scanProject();
      
      expect(nodes.any((n) => n is LogicUnitNode && n.name == 'CounterCubit'), isTrue);
    });

    test('Detects GetX Controller', () {
      final file = File('${tempDir.path}/counter_controller.dart');
      file.writeAsStringSync('class CounterController extends GetxController { var count = 0.obs; }');
      
      final scanner = AstScanner(tempDir.path);
      final nodes = scanner.scanProject();
      
      expect(nodes.any((n) => n is LogicUnitNode && n.name == 'CounterController'), isTrue);
    });

    test('Detects MobX Store', () {
      final file = File('${tempDir.path}/counter_store.dart');
      file.writeAsStringSync('''
        class CounterStore {
          @observable
          int count = 0;
          @action
          void increment() => count++;
        }
      ''');
      
      final scanner = AstScanner(tempDir.path);
      final nodes = scanner.scanProject();
      
      expect(nodes.any((n) => n is LogicUnitNode && n.name == 'CounterStore'), isTrue);
    });
  });
}
