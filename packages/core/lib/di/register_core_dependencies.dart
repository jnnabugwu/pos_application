import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:get_it/get_it.dart';

import '../datasources/firebase_auth_datasource.dart';
import '../datasources/firestore_menu_datasource.dart';
import '../repositories/auth_repository.dart';
import '../repositories/menu_repository.dart';

/// Registers the cross-app singletons both `pos_app` and `manager_app` need:
/// the Firebase SDK instances and the real repository implementations.
///
/// Each app's own `configureDependencies()` should call this first, then
/// layer app-local registrations (router, Blocs) on top.
///
/// [firestore]/[auth] default to `.instance` but can be overridden with fakes
/// (e.g. `FakeFirebaseFirestore`, `MockFirebaseAuth`) so this function itself
/// is unit-testable without a real Firebase project.
void registerCoreDependencies(
  GetIt it, {
  FirebaseFirestore? firestore,
  fb_auth.FirebaseAuth? auth,
}) {
  it.registerLazySingleton<FirebaseFirestore>(
    () => firestore ?? FirebaseFirestore.instance,
  );
  it.registerLazySingleton<fb_auth.FirebaseAuth>(
    () => auth ?? fb_auth.FirebaseAuth.instance,
  );

  it.registerLazySingleton<MenuRepository>(
    () => FirestoreMenuDataSource(it<FirebaseFirestore>()),
  );
  it.registerLazySingleton<AuthRepository>(
    () => FirebaseAuthDataSource(
      it<fb_auth.FirebaseAuth>(),
      it<FirebaseFirestore>(),
    ),
  );
}
