import 'package:dartz/dartz.dart';

import '../entities/menu_item.dart';
import '../failures/failure.dart';

/// Contract for reading and writing the shared menu.
///
/// Both apps depend on this abstraction, never on `cloud_firestore`
/// directly — [watchMenu] is what gives both apps live updates without a
/// restart, since Firestore's snapshot stream already does that for free.
abstract class MenuRepository {
  /// Emits the full menu item list every time any item changes.
  Stream<List<MenuItem>> watchMenu();

  Future<Either<Failure, MenuItem>> createItem({
    required String name,
    required int priceCents,
    required String category,
  });

  Future<Either<Failure, Unit>> updateItem(MenuItem item);

  Future<Either<Failure, Unit>> deleteItem(String id);

  Future<Either<Failure, Unit>> setAvailability(String id, bool available);
}
