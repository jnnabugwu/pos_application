import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/datasources/firebase_auth_datasource.dart';
import 'package:core/entities/app_role.dart';
import 'package:core/entities/app_user.dart';
import 'package:core/failures/failure.dart';
import 'package:dartz/dartz.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
// `firebase_auth_mocks` exports its own `MockFirebaseAuth`, which collides with
// the mocktail-generated one below — alias this import to keep them apart.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as fam;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/mock_firestore.dart';

class MockFirebaseAuth extends Mock implements fb_auth.FirebaseAuth {}

class MockUserCredential extends Mock implements fb_auth.UserCredential {}

class MockFbUser extends Mock implements fb_auth.User {}

fb_auth.FirebaseAuthException authException(String code) =>
    // ignore: invalid_use_of_protected_member
    fb_auth.FirebaseAuthException(code: code);

void main() {
  setUpAll(registerFirestoreFallbackValues);

  group('happy paths (firebase_auth_mocks + fake_cloud_firestore)', () {
    test('authStateChanges emits null when signed out, then the resolved AppUser', () async {
      final mockUser = fam.MockUser(uid: 'uid-1', email: 'staff@example.com');
      final auth = fam.MockFirebaseAuth(mockUser: mockUser, signedIn: false);
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('uid-1').set({
        'email': 'staff@example.com',
        'role': 'staff',
      });
      final datasource = FirebaseAuthDataSource(auth, firestore);

      final expectation = expectLater(
        datasource.authStateChanges(),
        emitsInOrder([
          isNull,
          const AppUser(uid: 'uid-1', email: 'staff@example.com', role: AppRole.staff),
        ]),
      );

      await auth.signInWithEmailAndPassword(email: 'staff@example.com', password: 'whatever');
      await expectation;
    });

    test('signIn resolves the AppUser role from Firestore', () async {
      final mockUser = fam.MockUser(uid: 'uid-1', email: 'admin@example.com');
      final auth = fam.MockFirebaseAuth(mockUser: mockUser, signedIn: false);
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('uid-1').set({
        'email': 'admin@example.com',
        'role': 'admin',
      });
      final datasource = FirebaseAuthDataSource(auth, firestore);

      final result = await datasource.signIn(email: 'admin@example.com', password: 'whatever');

      expect(
        result,
        const Right(AppUser(uid: 'uid-1', email: 'admin@example.com', role: AppRole.admin)),
      );
    });

    test('signOut succeeds', () async {
      final auth = fam.MockFirebaseAuth();
      final datasource = FirebaseAuthDataSource(auth, FakeFirebaseFirestore());

      final result = await datasource.signOut();

      expect(result, const Right(unit));
    });
  });

  group('failure paths (mocktail)', () {
    late MockFirebaseAuth auth;
    late MockFirebaseFirestore firestore;

    setUp(() {
      auth = MockFirebaseAuth();
      firestore = MockFirebaseFirestore();
    });

    group('signIn', () {
      test('maps a FirebaseAuthException to a typed Failure', () async {
        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(authException('wrong-password'));

        final result = await FirebaseAuthDataSource(auth, firestore).signIn(
          email: 'x@example.com',
          password: 'bad',
        );

        expect(result, const Left(InvalidCredentialsFailure()));
      });

      test('maps a signed-in user with no role doc to PermissionFailure', () async {
        final credential = MockUserCredential();
        final user = MockFbUser();
        final collection = MockCollectionReference();
        final docRef = MockDocumentReference();
        final snapshot = MockDocumentSnapshot();

        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => credential);
        when(() => credential.user).thenReturn(user);
        when(() => user.uid).thenReturn('uid-1');
        when(() => firestore.collection('users')).thenReturn(collection);
        when(() => collection.doc('uid-1')).thenReturn(docRef);
        when(() => docRef.get()).thenAnswer((_) async => snapshot);
        when(() => snapshot.data()).thenReturn(null);

        final result = await FirebaseAuthDataSource(auth, firestore).signIn(
          email: 'x@example.com',
          password: 'whatever',
        );

        expect(
          result,
          const Left(PermissionFailure('Signed in, but no role is assigned to this account.')),
        );
      });

      test('maps a Firestore error during role lookup to UnknownFailure', () async {
        final credential = MockUserCredential();
        final user = MockFbUser();
        final collection = MockCollectionReference();
        final docRef = MockDocumentReference();

        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => credential);
        when(() => credential.user).thenReturn(user);
        when(() => user.uid).thenReturn('uid-1');
        when(() => firestore.collection('users')).thenReturn(collection);
        when(() => collection.doc('uid-1')).thenReturn(docRef);
        when(() => docRef.get()).thenThrow(
          FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
        );

        final result = await FirebaseAuthDataSource(auth, firestore).signIn(
          email: 'x@example.com',
          password: 'whatever',
        );

        expect(result, isA<Left>());
        expect((result as Left).value, isA<UnknownFailure>());
      });
    });

    group('signOut', () {
      test('maps a FirebaseAuthException to a typed Failure', () async {
        when(() => auth.signOut()).thenThrow(authException('network-request-failed'));

        final result = await FirebaseAuthDataSource(auth, firestore).signOut();

        expect(result, const Left(NetworkFailure()));
      });

      test('maps a non-Firebase error to UnknownFailure', () async {
        when(() => auth.signOut()).thenThrow(Exception('boom'));

        final result = await FirebaseAuthDataSource(auth, firestore).signOut();

        expect(result, isA<Left>());
        expect((result as Left).value, isA<UnknownFailure>());
      });
    });
  });
}
