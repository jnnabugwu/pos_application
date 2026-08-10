// cloud_firestore's Query/DocumentReference/DocumentSnapshot carry package:meta's
// advisory @sealed annotation (not Dart 3's `sealed` keyword) — it's a lint, not a
// compile error, and mocktail implementing them to engineer failure paths is a
// standard, widely-used pattern in the Flutter ecosystem.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';

/// Shared mocktail doubles for engineering Firestore failure paths — see
/// docs/architecture-decisions.md for why these are only used for `Left(...)`
/// paths, with `fake_cloud_firestore` covering the `Right(...)` happy paths.
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// `Query.orderBy()` returns `Query<T>`, not `CollectionReference<T>`, so this
// needs to be a distinct mock type from MockCollectionReference.
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

/// Registers the map shapes mocktail's `any()` matcher needs to know about:
/// `set()` takes `Map<String, dynamic>`, `update()` takes `Map<Object, Object?>`.
void registerFirestoreFallbackValues() {
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(<Object, Object?>{});
}
