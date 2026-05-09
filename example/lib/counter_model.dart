import 'package:flutter/material.dart';

import "package:riverpod_annotation/riverpod_annotation.dart";
part "counter_model.g.dart";

@riverpod
class CounterModelNotifier extends _$CounterModelNotifier {
  @override
  dynamic build() {
    return null; // TODO: Return initial state
  }

  void count() => _count;

  void increment() {
    state = state.copyWith(count: state.count + 1);
  }
}

/* TODO: Original ChangeNotifier class:
class CounterModel extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}
*/
