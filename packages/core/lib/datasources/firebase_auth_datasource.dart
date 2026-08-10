import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import '../entities/app_user.dart';
import '../failures/failure.dart';
import '../failures/firebase_failure_mapper.dart';
import '../repositories/auth_repository.dart';

/// Firebase Auth + Firestore-backed implementation of [AuthRepository].
///
/// Firebase Auth only proves *who* signed in; the *role* (`admin`/`staff`)
/// lives in the matching `users/{uid}` Firestore doc — see
/// firestore.rules later, where that doc is `allow write: if false` so a
/// client can never grant itself a role.
class FirebaseAuthDataSource implements AuthRepository {
  FirebaseAuthDataSource(this._auth, this._firestore);

  final fb_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<AppUser?> _resolveAppUser(fb_auth.User? user) async {
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return null;
    return AppUser.fromMap(user.uid, data);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncMap(_resolveAppUser);
  }

  @override
  Future<Either<Failure, AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final appUser = await _resolveAppUser(credential.user);
      if (appUser == null) {
        return const Left(
          PermissionFailure('Signed in, but no role is assigned to this account.'),
        );
      }
      return Right(appUser);
    } on fb_auth.FirebaseAuthException catch (e) {
      return Left(mapFirebaseException(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _auth.signOut();
      return const Right(unit);
    } on fb_auth.FirebaseAuthException catch (e) {
      return Left(mapFirebaseException(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
