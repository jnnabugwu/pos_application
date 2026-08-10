import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as fam;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  late GetIt getIt;

  setUp(() {
    getIt = GetIt.asNewInstance();
  });

  tearDown(() {
    getIt.reset();
  });

  test('registers MenuRepository and AuthRepository', () {
    registerCoreDependencies(
      getIt,
      firestore: FakeFirebaseFirestore(),
      auth: fam.MockFirebaseAuth(),
    );

    expect(getIt.isRegistered<MenuRepository>(), isTrue);
    expect(getIt.isRegistered<AuthRepository>(), isTrue);
    expect(getIt<MenuRepository>(), isA<FirestoreMenuDataSource>());
    expect(getIt<AuthRepository>(), isA<FirebaseAuthDataSource>());
  });
}
