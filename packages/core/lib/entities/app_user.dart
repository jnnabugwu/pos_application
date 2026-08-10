import 'package:equatable/equatable.dart';

import 'app_role.dart';

/// The signed-in user, combining their Firebase Auth identity with the role
/// resolved from their `users/{uid}` Firestore doc.
///
/// Like [MenuItem], deliberately has no `cloud_firestore`/`firebase_auth` SDK
/// types on it — see docs/architecture-decisions.md.
class AppUser extends Equatable {
  final String uid;
  final String email;
  final AppRole role;

  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      email: map['email'] as String,
      role: AppRole.fromName(map['role'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role.name,
    };
  }

  @override
  List<Object?> get props => [uid, email, role];
}
