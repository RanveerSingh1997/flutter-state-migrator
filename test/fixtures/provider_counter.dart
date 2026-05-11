// Fixture: realistic Provider/ChangeNotifier app for migration testing.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ── Logic unit ─────────────────────────────────────────────────────────────

class CounterModel extends ChangeNotifier {
  int _count = 0;
  String _label = 'counter';
  bool _loading = false;

  int get count => _count;
  String get label => _label;
  bool get loading => _loading;

  void increment() {
    _count++;
    notifyListeners();
  }

  void decrement() {
    _count--;
    notifyListeners();
  }

  void reset() {
    _count = 0;
    _label = 'reset';
    notifyListeners();
  }

  void addMany(int delta) {
    _count += delta;
    notifyListeners();
  }

  Future<void> loadFromApi() async {
    _loading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 100));
    _count = 42;
    _loading = false;
    notifyListeners();
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final counter = Provider.of<CounterModel>(context);
    return Scaffold(
      body: Text('${counter.count}'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Provider.of<CounterModel>(context, listen: false)
            .increment(),
      ),
    );
  }
}

class CounterDisplay extends StatelessWidget {
  const CounterDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CounterModel>(
      builder: (context, model, child) => Text('${model.count}'),
    );
  }
}

class LabelDisplay extends StatelessWidget {
  const LabelDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<CounterModel, String>(
      selector: (_, model) => model.label,
      builder: (context, label, child) => Text(label),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CounterModel()),
      ],
      child: MaterialApp(home: CounterPage()),
    );
  }
}
