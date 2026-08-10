import 'package:firebase_core/firebase_core.dart';

import 'failure.dart';

/// Maps a raw `FirebaseException` (thrown by both `cloud_firestore` and
/// `firebase_auth` — `FirebaseAuthException` is a subtype) to a typed
/// [Failure], so datasources never let the raw exception escape to a
/// repository consumer.
Failure mapFirebaseException(FirebaseException exception) {
  switch (exception.code) {
    case 'permission-denied':
      return const PermissionFailure();
    case 'not-found':
      return const NotFoundFailure();
    case 'unavailable':
    case 'network-request-failed':
      return const NetworkFailure();
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-credential':
    case 'invalid-email':
    case 'user-disabled':
      return const InvalidCredentialsFailure();
    default:
      return UnknownFailure(exception.message ?? exception.code);
  }
}
