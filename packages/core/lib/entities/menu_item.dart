import 'package:equatable/equatable.dart';

/// A menu item shown on the POS app and managed from the Manager app.
///
/// Deliberately has no dependency on `cloud_firestore` (no `DocumentSnapshot`
/// on this type) — see docs/architecture-decisions.md for why the usual
/// separate data/model layer was collapsed into this entity instead.
/// [fromMap]/[toMap] work on plain values only; converting a Firestore
/// `Timestamp` to/from [DateTime] is the datasource's job, not this class's.
class MenuItem extends Equatable {
  final String id;
  final String name;

  /// Price in integer cents (e.g. 550 = $5.50) to avoid floating-point
  /// rounding issues with money.
  final int priceCents;
  final String category;
  final bool available;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MenuItem({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.category,
    required this.available,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuItem.fromMap(String id, Map<String, dynamic> map) {
    return MenuItem(
      id: id,
      name: map['name'] as String,
      priceCents: map['priceCents'] as int,
      category: map['category'] as String,
      available: map['available'] as bool,
      createdAt: map['createdAt'] as DateTime,
      updatedAt: map['updatedAt'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'priceCents': priceCents,
      'category': category,
      'available': available,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  MenuItem copyWith({
    String? name,
    int? priceCents,
    String? category,
    bool? available,
    DateTime? updatedAt,
  }) {
    return MenuItem(
      id: id,
      name: name ?? this.name,
      priceCents: priceCents ?? this.priceCents,
      category: category ?? this.category,
      available: available ?? this.available,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    priceCents,
    category,
    available,
    createdAt,
    updatedAt,
  ];
}
