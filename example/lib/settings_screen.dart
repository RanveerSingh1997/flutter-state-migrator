import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'counter_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Selector<CounterModel, int>(
              selector: (_, model) => model.count,
              builder: (context, count, child) =>
                  Text('Count from Selector: $count'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  Provider.of<CounterModel>(context, listen: false).increment(),
              child: const Text('Increment from Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
