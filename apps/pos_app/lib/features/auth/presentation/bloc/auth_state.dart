import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

enum AuthStatus { initial, loading, success, failure }

class AuthState extends Equatable {
  const AuthState({this.status = AuthStatus.initial, this.user, this.failure});

  final AuthStatus status;
  final AppUser? user;
  final Failure? failure;

  AuthState copyWith({AuthStatus? status, AppUser? user, Failure? failure}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      // Deliberately not `failure ?? this.failure` — a fresh sign-in attempt
      // must be able to clear a stale error from a previous attempt.
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, user, failure];
}
