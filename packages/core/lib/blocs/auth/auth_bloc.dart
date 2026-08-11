import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../entities/app_user.dart';
import '../../repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._authRepository) : super(const AuthState()) {
    on<SignInRequested>(_onSignInRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<AuthUserChanged>(_onAuthUserChanged);
    // Keeps `state.user` in sync with a session restored on app launch, not
    // just with sign-ins that happened through this bloc's SignInRequested
    // — otherwise a returning admin's role wouldn't resolve until they
    // signed in again in this session (see docs/architecture-decisions.md).
    _authStateSubscription = _authRepository.authStateChanges().listen(
      (user) => add(AuthUserChanged(user)),
    );
  }

  final AuthRepository _authRepository;
  late final StreamSubscription<AppUser?> _authStateSubscription;

  @override
  Future<void> close() {
    _authStateSubscription.cancel();
    return super.close();
  }

  void _onAuthUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    emit(
      state.copyWith(
        status: event.user != null ? AuthStatus.success : AuthStatus.initial,
        user: event.user,
      ),
    );
  }

  Future<void> _onSignInRequested(
    SignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await _authRepository.signIn(
      email: event.email,
      password: event.password,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AuthStatus.failure,
          user: null,
          failure: failure,
        ),
      ),
      (user) => emit(state.copyWith(status: AuthStatus.success, user: user)),
    );
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _authRepository.signOut();
    result.fold(
      (failure) =>
          emit(state.copyWith(status: AuthStatus.failure, failure: failure)),
      (_) => emit(const AuthState()),
    );
  }
}
