import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

/// Adapts [AuthRepository.authStateChanges] into a [Listenable] so
/// [GoRouter]'s `refreshListenable` can react to sign-in/sign-out.
class AuthListenable extends ChangeNotifier {
  AuthListenable(AuthRepository authRepository) {
    _subscription = authRepository.authStateChanges().listen((user) {
      currentUser = user;
      ready = true;
      notifyListeners();
    });
  }

  late final StreamSubscription<AppUser?> _subscription;

  AppUser? currentUser;

  /// Guards against redirecting to /login before the first
  /// authStateChanges() event has arrived.
  bool ready = false;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
