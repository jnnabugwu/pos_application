import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/datasources/firestore_menu_datasource.dart';
import 'package:core/entities/menu_item.dart';
import 'package:core/failures/failure.dart';
import 'package:dartz/dartz.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/mock_firestore.dart';

MenuItem _asItem(Either<Failure, MenuItem> result) => (result as Right).value;

void main() {
  setUpAll(registerFirestoreFallbackValues);

  group('happy paths (fake_cloud_firestore)', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreMenuDataSource datasource;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      datasource = FirestoreMenuDataSource(firestore);
    });

    test(
      'createItem writes a new doc with an auto id and returns Right(item)',
      () async {
        final result = await datasource.createItem(
          name: 'Latte',
          priceCents: 450,
          category: 'Drinks',
          stockCount: 20,
        );

        final item = _asItem(result);
        expect(item.id, isNotEmpty);
        expect(item.name, 'Latte');
        expect(item.priceCents, 450);
        expect(item.category, 'Drinks');
        expect(item.available, true);
        expect(item.stockCount, 20);

        final stored = await firestore
            .collection('menuItems')
            .doc(item.id)
            .get();
        expect(stored.exists, true);
        expect(stored.data()!['name'], 'Latte');
        expect(stored.data()!['stockCount'], 20);
      },
    );

    test('updateItem writes the changed fields and bumps updatedAt', () async {
      final created = _asItem(
        await datasource.createItem(
          name: 'Latte',
          priceCents: 450,
          category: 'Drinks',
          stockCount: 20,
        ),
      );

      final result = await datasource.updateItem(
        created.id,
        name: 'Mocha',
        category: created.category,
        priceCents: created.priceCents,
        stockCount: 15,
      );

      expect(result, const Right(unit));
      final stored = await firestore
          .collection('menuItems')
          .doc(created.id)
          .get();
      expect(stored.data()!['name'], 'Mocha');
      expect(stored.data()!['stockCount'], 15);
    });

    test('updateItem does not touch availability even if it changed since '
        'the caller last read the item', () async {
      final created = _asItem(
        await datasource.createItem(
          name: 'Latte',
          priceCents: 450,
          category: 'Drinks',
          stockCount: 20,
        ),
      );
      // Simulates another staff member toggling availability after this
      // update's caller loaded their (now-stale) snapshot.
      await datasource.setAvailability(created.id, false);

      final result = await datasource.updateItem(
        created.id,
        name: 'Mocha',
        category: created.category,
        priceCents: created.priceCents,
        stockCount: created.stockCount,
      );

      expect(result, const Right(unit));
      final stored = await firestore
          .collection('menuItems')
          .doc(created.id)
          .get();
      expect(stored.data()!['available'], false);
    });

    test('createItem rejects a negative price', () async {
      final result = await datasource.createItem(
        name: 'Latte',
        priceCents: -1,
        category: 'Drinks',
        stockCount: 20,
      );

      expect(result, isA<Left>());
      expect((result as Left).value, isA<UnknownFailure>());
    });

    test('createItem rejects negative stock', () async {
      final result = await datasource.createItem(
        name: 'Latte',
        priceCents: 450,
        category: 'Drinks',
        stockCount: -1,
      );

      expect(result, isA<Left>());
      expect((result as Left).value, isA<UnknownFailure>());
    });

    test('updateItem rejects negative stock', () async {
      final created = _asItem(
        await datasource.createItem(
          name: 'Latte',
          priceCents: 450,
          category: 'Drinks',
          stockCount: 20,
        ),
      );

      final result = await datasource.updateItem(
        created.id,
        name: created.name,
        category: created.category,
        priceCents: created.priceCents,
        stockCount: -5,
      );

      expect(result, isA<Left>());
      expect((result as Left).value, isA<UnknownFailure>());
    });

    test('deleteItem removes the doc', () async {
      final created = _asItem(
        await datasource.createItem(
          name: 'Latte',
          priceCents: 450,
          category: 'Drinks',
          stockCount: 20,
        ),
      );

      final result = await datasource.deleteItem(created.id);

      expect(result, const Right(unit));
      final stored = await firestore
          .collection('menuItems')
          .doc(created.id)
          .get();
      expect(stored.exists, false);
    });

    test('setAvailability flips the available field', () async {
      final created = _asItem(
        await datasource.createItem(
          name: 'Latte',
          priceCents: 450,
          category: 'Drinks',
          stockCount: 20,
        ),
      );

      final result = await datasource.setAvailability(created.id, false);

      expect(result, const Right(unit));
      final stored = await firestore
          .collection('menuItems')
          .doc(created.id)
          .get();
      expect(stored.data()!['available'], false);
    });

    test(
      'watchMenu streams items with Timestamp converted to DateTime',
      () async {
        final createdAt = DateTime(2026, 1, 1, 9);
        await firestore.collection('menuItems').doc('item-1').set({
          'name': 'Latte',
          'priceCents': 450,
          'category': 'Drinks',
          'available': true,
          'stockCount': 20,
          'createdAt': Timestamp.fromDate(createdAt),
          'updatedAt': Timestamp.fromDate(createdAt),
        });

        final items = await datasource.watchMenu().first;

        expect(items.single.id, 'item-1');
        expect(items.single.createdAt, createdAt);
        expect(items.single.updatedAt, createdAt);
        expect(items.single.stockCount, 20);
      },
    );

    test(
      'watchMenu defaults stockCount to 0 for docs written before that field existed',
      () async {
        final createdAt = DateTime(2026, 1, 1, 9);
        await firestore.collection('menuItems').doc('item-legacy').set({
          'name': 'Legacy Item',
          'priceCents': 100,
          'category': 'Drinks',
          'available': true,
          'createdAt': Timestamp.fromDate(createdAt),
          'updatedAt': Timestamp.fromDate(createdAt),
        });

        final items = await datasource.watchMenu().first;

        expect(items.single.stockCount, 0);
      },
    );
  });

  group('failure paths (mocktail)', () {
    late MockFirebaseFirestore firestore;
    late MockCollectionReference collection;
    late MockDocumentReference docRef;
    late FirestoreMenuDataSource datasource;

    setUp(() {
      firestore = MockFirebaseFirestore();
      collection = MockCollectionReference();
      docRef = MockDocumentReference();
      datasource = FirestoreMenuDataSource(firestore);

      when(() => firestore.collection('menuItems')).thenReturn(collection);
    });

    group('createItem', () {
      setUp(() {
        when(() => collection.doc()).thenReturn(docRef);
        when(() => docRef.id).thenReturn('mock-id');
      });

      test('maps a FirebaseException to a typed Failure', () async {
        when(() => docRef.set(any())).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );

        final result = await datasource.createItem(
          name: 'Latte',
          priceCents: 450,
          category: 'Drinks',
          stockCount: 20,
        );

        expect(result, const Left(PermissionFailure()));
      });

      test('maps a non-Firebase error to UnknownFailure', () async {
        when(() => docRef.set(any())).thenThrow(StateError('boom'));

        final result = await datasource.createItem(
          name: 'Latte',
          priceCents: 450,
          category: 'Drinks',
          stockCount: 20,
        );

        expect(result, isA<Left>());
        expect((result as Left).value, isA<UnknownFailure>());
      });
    });

    group('updateItem', () {
      setUp(() {
        when(() => collection.doc('item-1')).thenReturn(docRef);
      });

      test('maps a FirebaseException to a typed Failure', () async {
        when(() => docRef.update(any())).thenThrow(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        );

        final result = await datasource.updateItem(
          'item-1',
          name: 'Latte',
          category: 'Drinks',
          priceCents: 450,
          stockCount: 20,
        );

        expect(result, const Left(NetworkFailure()));
      });

      test('maps a non-Firebase error to UnknownFailure', () async {
        when(() => docRef.update(any())).thenThrow(StateError('boom'));

        final result = await datasource.updateItem(
          'item-1',
          name: 'Latte',
          category: 'Drinks',
          priceCents: 450,
          stockCount: 20,
        );

        expect(result, isA<Left>());
        expect((result as Left).value, isA<UnknownFailure>());
      });
    });

    group('deleteItem', () {
      setUp(() {
        when(() => collection.doc('item-1')).thenReturn(docRef);
      });

      test('maps a FirebaseException to a typed Failure', () async {
        when(() => docRef.delete()).thenThrow(
          FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
        );

        final result = await datasource.deleteItem('item-1');

        expect(result, const Left(NotFoundFailure()));
      });

      test('maps a non-Firebase error to UnknownFailure', () async {
        when(() => docRef.delete()).thenThrow(StateError('boom'));

        final result = await datasource.deleteItem('item-1');

        expect(result, isA<Left>());
        expect((result as Left).value, isA<UnknownFailure>());
      });
    });

    group('setAvailability', () {
      setUp(() {
        when(() => collection.doc('item-1')).thenReturn(docRef);
      });

      test('maps a FirebaseException to a typed Failure', () async {
        when(() => docRef.update(any())).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );

        final result = await datasource.setAvailability('item-1', false);

        expect(result, const Left(PermissionFailure()));
      });

      test('maps a non-Firebase error to UnknownFailure', () async {
        when(() => docRef.update(any())).thenThrow(StateError('boom'));

        final result = await datasource.setAvailability('item-1', false);

        expect(result, isA<Left>());
        expect((result as Left).value, isA<UnknownFailure>());
      });
    });
  });

  group(
    'watchMenu error propagation (mocktail, behavioral not required for coverage)',
    () {
      test('a Firestore stream error propagates uncaught', () {
        final firestore = MockFirebaseFirestore();
        final collection = MockCollectionReference();
        final query = MockQuery();
        final datasource = FirestoreMenuDataSource(firestore);

        when(() => firestore.collection('menuItems')).thenReturn(collection);
        when(() => collection.orderBy('category')).thenReturn(query);
        when(() => query.snapshots()).thenAnswer(
          (_) => Stream.error(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          ),
        );

        expect(datasource.watchMenu(), emitsError(isA<FirebaseException>()));
      });
    },
  );
}
