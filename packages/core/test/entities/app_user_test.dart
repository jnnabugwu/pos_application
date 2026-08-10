import 'package:core/entities/app_role.dart';
import 'package:core/entities/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const uid = 'uid-1';
  const map = {'email': 'admin@example.com', 'role': 'admin'};
  const user = AppUser(uid: uid, email: 'admin@example.com', role: AppRole.admin);

  test('fromMap builds an AppUser from a Firestore-shaped map', () {
    expect(AppUser.fromMap(uid, map), user);
  });

  test('toMap round-trips back to the original map', () {
    expect(user.toMap(), map);
  });

  test('two users with the same fields are equal', () {
    expect(
      const AppUser(uid: uid, email: 'admin@example.com', role: AppRole.admin),
      user,
    );
  });

  test('users differing by role are not equal', () {
    expect(
      const AppUser(uid: uid, email: 'admin@example.com', role: AppRole.staff),
      isNot(user),
    );
  });
}
