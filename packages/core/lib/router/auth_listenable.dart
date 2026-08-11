import 'dart:async';

import 'package:flutter/foundation.dart';

import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

/// Adapts [AuthRepository.authStateChanges] into a [Listenable] so
/// `GoRouter`'s `refreshListenable` can react to sign-in/sign-out.
///
/// Shared by both apps (rather than duplicated per app) so a future fix to
/// this stream-to-listenable bridging happens in one place.
class AuthListenable extends ChangeNotifier {
  AuthListenable(AuthRepository authRepository) {
    _subscription = authRepository.authStateChanges().listen(
      (user) {
        currentUser = user;
        ready = true;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        // _resolveAppUser does an async Firestore read and can throw
        // (network/permission issues). Fail safe: treat as signed-out
        // rather than leaving `ready` stuck false or crashing the app.
        debugPrint('AuthListenable: authStateChanges() error: $error');
        currentUser = null;
        ready = true;
        notifyListeners();
      },
    );
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
