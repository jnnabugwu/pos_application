import 'package:equatable/equatable.dart';

import '../../entities/app_user.dart';
import '../../failures/failure.dart';

enum AuthStatus { initial, loading, success, failure }

class AuthState extends Equatable {
  const AuthState({this.status = AuthStatus.initial, this.user, this.failure});

  final AuthStatus status;
  final AppUser? user;
  final Failure? failure;

  static const _unset = Object();

  // `user` defaults to a sentinel (not null) so callers can distinguish
  // "leave user as-is" from "explicitly clear user" — pass `user: null` to
  // clear it, or omit `user` entirely to keep whatever was already set.
  AuthState copyWith({
    AuthStatus? status,
    Object? user = _unset,
    Failure? failure,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: identical(user, _unset) ? this.user : user as AppUser?,
      // Deliberately not `failure ?? this.failure` — a fresh sign-in attempt
      // must be able to clear a stale error from a previous attempt.
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, user, failure];
}
