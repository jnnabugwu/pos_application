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
    final item = _findItem(state.items, event.itemId);
    if (item == null) return;

    final target = !item.available;
    // Optimistically apply the target locally (and drop any stale failure
    // from a previous attempt) so a rapid second tap on the same item reads
    // the pending target instead of the last confirmed watchMenu() snapshot
    // — otherwise both taps compute the same !available and the second is
    // a no-op. The live stream reconciles this with the confirmed value
    // moments later.
    emit(
      state.copyWith(items: _withAvailability(state.items, item.id, target)),
    );

    final result = await _menuRepository.setAvailability(item.id, target);
    result.fold(
      (failure) => emit(
        state.copyWith(
          // Roll back: the write failed, so no new watchMenu() snapshot
          // will arrive to correct the optimistic value.
          items: _withAvailability(state.items, item.id, item.available),
          failure: failure,
        ),
      ),
      (_) {},
    );
  }

  MenuItem? _findItem(List<MenuItem> items, String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<MenuItem> _withAvailability(
    List<MenuItem> items,
    String id,
    bool available,
  ) {
    return [
      for (final item in items)
        if (item.id == id) item.copyWith(available: available) else item,
    ];
  }
}
