import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'menu_event.dart';
import 'menu_state.dart';

class MenuBloc extends Bloc<MenuEvent, MenuState> {
  MenuBloc(this._menuRepository) : super(const MenuState()) {
    on<WatchMenuStarted>(_onWatchMenuStarted);
    on<ToggleAvailability>(_onToggleAvailability);
  }

  final MenuRepository _menuRepository;

  Future<void> _onWatchMenuStarted(
    WatchMenuStarted event,
    Emitter<MenuState> emit,
  ) async {
    emit(state.copyWith(status: MenuStatus.loading));
    await emit.forEach<List<MenuItem>>(
      _menuRepository.watchMenu(),
      onData: (items) =>
          state.copyWith(status: MenuStatus.success, items: items),
      onError: (error, stackTrace) => state.copyWith(
        status: MenuStatus.failure,
        failure: UnknownFailure(error.toString()),
      ),
    );
  }

  Future<void> _onToggleAvailability(
    ToggleAvailability event,
    Emitter<MenuState> emit,
  ) async {
    MenuItem? item;
    for (final candidate in state.items) {
      if (candidate.id == event.itemId) {
        item = candidate;
        break;
      }
    }
    if (item == null) return;
    // No optimistic local update: the live watchMenu() stream above pushes
    // the confirmed state moments later (Firestore's realtime propagation).
    await _menuRepository.setAvailability(item.id, !item.available);
  }
}
