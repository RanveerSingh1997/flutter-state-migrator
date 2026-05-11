// Fixture: realistic Cubit app for migration testing.
import 'package:flutter_bloc/flutter_bloc.dart';

// ── Cubit ──────────────────────────────────────────────────────────────────

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);

  void decrement() => emit(state - 1);

  void reset() => emit(0);

  Future<void> loadFromApi() async {
    await Future.delayed(const Duration(milliseconds: 100));
    emit(42);
  }
}

// ── Typed-state Cubit ──────────────────────────────────────────────────────

class ProfileState {
  final String name;
  final bool verified;

  const ProfileState({required this.name, this.verified = false});
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(const ProfileState(name: ''));

  void updateName(String name) => emit(ProfileState(name: name));

  void verify() => emit(ProfileState(name: state.name, verified: true));

  Future<void> fetchProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    emit(ProfileState(name: 'User $userId', verified: true));
  }
}

// ── Bloc ───────────────────────────────────────────────────────────────────

abstract class CounterEvent {}

class IncrementEvent extends CounterEvent {}

class DecrementEvent extends CounterEvent {}

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<IncrementEvent>((event, emit) => emit(state + 1));
    on<DecrementEvent>((event, emit) => emit(state - 1));
  }
}
