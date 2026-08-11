import 'package:equatable/equatable.dart';

import 'order_line_item.dart';

/// A completed order (a checked-out running tab). No `copyWith` — orders
/// are never edited after creation in this app, so mutability machinery
/// would be dead code.
class Order extends Equatable {
  final String id;
  final List<OrderLineItem> lineItems;
  final int totalCents;
  final String createdByUid;
  final String createdByEmail;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.lineItems,
    required this.totalCents,
    required this.createdByUid,
    required this.createdByEmail,
    required this.createdAt,
  });

  /// Used by the Firestore order datasource to hand back the
  /// already-committed order when a checkout retry's request id matches one
  /// it already wrote — not a general order-reading API.
  factory Order.fromMap(String id, Map<String, dynamic> map) {
    return Order(
      id: id,
      lineItems: (map['lineItems'] as List)
          .map(
            (e) => OrderLineItem.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      totalCents: map['totalCents'] as int,
      createdByUid: map['createdByUid'] as String,
      createdByEmail: map['createdByEmail'] as String,
      createdAt: map['createdAt'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lineItems': [for (final line in lineItems) line.toMap()],
      'totalCents': totalCents,
      'createdByUid': createdByUid,
      'createdByEmail': createdByEmail,
      'createdAt': createdAt,
    };
  }

  @override
  List<Object?> get props => [
    id,
    lineItems,
    totalCents,
    createdByUid,
    createdByEmail,
    createdAt,
  ];
}
