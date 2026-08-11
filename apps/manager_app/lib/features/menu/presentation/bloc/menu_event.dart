import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

sealed class MenuEvent extends Equatable {
  const MenuEvent();

  @override
  List<Object?> get props => [];
}

class WatchMenuStarted extends MenuEvent {
  const WatchMenuStarted();
}

class ToggleAvailability extends MenuEvent {
  const ToggleAvailability(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

class CreateItemRequested extends MenuEvent {
  const CreateItemRequested({
    required this.name,
    required this.priceCents,
    required this.category,
    required this.stockCount,
  });

  final String name;
  final int priceCents;
  final String category;
  final int stockCount;

  @override
  List<Object?> get props => [name, priceCents, category, stockCount];
}

class UpdateItemRequested extends MenuEvent {
  const UpdateItemRequested(this.item);

  final MenuItem item;

  @override
  List<Object?> get props => [item];
}

class DeleteItemRequested extends MenuEvent {
  const DeleteItemRequested(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}
