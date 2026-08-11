import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'menu_event.dart';
import 'menu_state.dart';

class MenuBloc extends Bloc<MenuEvent, MenuState> {
  MenuBloc(this._menuRepository) : super(const MenuState()) {
    on<WatchMenuStarted>(_onWatchMenuStarted);
    on<ToggleAvailability>(_onToggleAvailability);
    on<CreateItemRequested>(_onCreateItemRequested);
    on<UpdateItemRequested>(_onUpdateItemRequested);
    on<DeleteItemRequested>(_onDeleteItemRequested);
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

  Future<void> _onCreateItemRequested(
    CreateItemRequested event,
    Emitter<MenuState> emit,
  ) async {
    final result = await _menuRepository.createItem(
      name: event.name,
      priceCents: event.priceCents,
      category: event.category,
      stockCount: event.stockCount,
    );
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (_) {},
    );
  }

  Future<void> _onUpdateItemRequested(
    UpdateItemRequested event,
    Emitter<MenuState> emit,
  ) async {
    final result = await _menuRepository.updateItem(event.item);
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (_) {},
    );
  }

  Future<void> _onDeleteItemRequested(
    DeleteItemRequested event,
    Emitter<MenuState> emit,
  ) async {
    final result = await _menuRepository.deleteItem(event.itemId);
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
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
