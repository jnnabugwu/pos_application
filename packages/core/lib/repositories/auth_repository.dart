import 'package:dartz/dartz.dart';

import '../entities/app_user.dart';
import '../failures/failure.dart';

/// Contract for signing in/out and observing the current user.
///
/// Both apps depend on this abstraction, never on `firebase_auth` directly —
/// the resolved [AppUser.role] is what each app's UI/routing gates on.
abstract class AuthRepository {
  /// Emits the current user (with role resolved), or `null` when signed out.
  Stream<AppUser?> authStateChanges();

  Future<Either<Failure, AppUser>> signIn({
    required String email,
    required String password,
  });

  Future<Either<Failure, Unit>> signOut();
}
