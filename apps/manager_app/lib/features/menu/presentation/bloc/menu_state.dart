import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

enum MenuStatus { initial, loading, success, failure }

class MenuState extends Equatable {
  const MenuState({
    this.status = MenuStatus.initial,
    this.items = const [],
    this.failure,
  });

  final MenuStatus status;
  final List<MenuItem> items;
  final Failure? failure;

  MenuState copyWith({
    MenuStatus? status,
    List<MenuItem>? items,
    Failure? failure,
  }) {
    return MenuState(
      status: status ?? this.status,
      items: items ?? this.items,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, items, failure];
}
