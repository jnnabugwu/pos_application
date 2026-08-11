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
