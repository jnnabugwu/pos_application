import 'package:equatable/equatable.dart';

/// Typed failures returned from repositories as the `Left` of an
/// `Either<Failure, T>`, so UI code never has to catch a raw
/// `FirebaseException`.
sealed class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// No network connection, or a request timed out.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No network connection.']);
}

/// The signed-in user isn't allowed to perform this action (maps from
/// Firestore/Auth `permission-denied`).
class PermissionFailure extends Failure {
  const PermissionFailure([
    super.message = 'You don\'t have permission to do that.',
  ]);
}

/// The requested document doesn't exist.
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Not found.']);
}

/// Invalid credentials on sign-in (wrong password, no such user, etc).
class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure([
    super.message = 'Incorrect email or password.',
  ]);
}

/// Anything else — the message carries whatever detail is available.
class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}
