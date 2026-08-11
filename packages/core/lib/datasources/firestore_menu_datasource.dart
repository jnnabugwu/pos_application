import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../entities/menu_item.dart';
import '../failures/failure.dart';
import '../failures/firebase_failure_mapper.dart';
import '../repositories/menu_repository.dart';

/// Firestore-backed implementation of [MenuRepository].
///
/// `firestore` is injected rather than read from `FirebaseFirestore.instance`
/// so this class stays constructible against a fake/emulated instance in
/// tests (deferred to a later phase — see docs/architecture-decisions.md).
class FirestoreMenuDataSource implements MenuRepository {
  FirestoreMenuDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('menuItems');

  /// Firestore returns `Timestamp` for date fields; [MenuItem.fromMap]
  /// expects plain [DateTime] (see menu_item.dart), so this is the one place
  /// that boundary is crossed.
  MenuItem _fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MenuItem.fromMap(doc.id, {
      ...data,
      'createdAt': (data['createdAt'] as Timestamp).toDate(),
      'updatedAt': (data['updatedAt'] as Timestamp).toDate(),
    });
  }

  @override
  Stream<List<MenuItem>> watchMenu() {
    return _collection
        .orderBy('category')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromSnapshot).toList());
  }

  @override
  Future<Either<Failure, MenuItem>> createItem({
    required String name,
    required int priceCents,
    required String category,
    required int stockCount,
  }) async {
    try {
      final now = DateTime.now();
      final docRef = _collection.doc();
      final item = MenuItem(
        id: docRef.id,
        name: name,
        priceCents: priceCents,
        category: category,
        available: true,
        stockCount: stockCount,
        createdAt: now,
        updatedAt: now,
      );
      await docRef.set(item.toMap());
      return Right(item);
    } on FirebaseException catch (e) {
      return Left(mapFirebaseException(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateItem(MenuItem item) async {
    try {
      final updated = item.copyWith(updatedAt: DateTime.now());
      await _collection.doc(item.id).update(updated.toMap());
      return const Right(unit);
    } on FirebaseException catch (e) {
      return Left(mapFirebaseException(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteItem(String id) async {
    try {
      await _collection.doc(id).delete();
      return const Right(unit);
    } on FirebaseException catch (e) {
      return Left(mapFirebaseException(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> setAvailability(
    String id,
    bool available,
  ) async {
    try {
      await _collection.doc(id).update({
        'available': available,
        'updatedAt': DateTime.now(),
      });
      return const Right(unit);
    } on FirebaseException catch (e) {
      return Left(mapFirebaseException(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
