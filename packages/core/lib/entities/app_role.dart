/// A user's role, used both for UI gating and to resolve Firestore write
/// permission in security rules via the matching `users/{uid}.role` field.
enum AppRole {
  admin,
  staff;

  static AppRole fromName(String name) => AppRole.values.firstWhere(
    (role) => role.name == name,
    orElse: () => throw ArgumentError('Unknown AppRole: $name'),
  );
}
