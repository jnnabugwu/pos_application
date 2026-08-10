import 'package:core/failures/failure.dart';
import 'package:core/failures/firebase_failure_mapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

FirebaseException _exception(String code, {String? message}) {
  return FirebaseException(plugin: 'test', code: code, message: message);
}

void main() {
  test('permission-denied maps to PermissionFailure', () {
    expect(mapFirebaseException(_exception('permission-denied')), const PermissionFailure());
  });

  test('not-found maps to NotFoundFailure', () {
    expect(mapFirebaseException(_exception('not-found')), const NotFoundFailure());
  });

  test('unavailable maps to NetworkFailure', () {
    expect(mapFirebaseException(_exception('unavailable')), const NetworkFailure());
  });

  test('network-request-failed maps to NetworkFailure', () {
    expect(mapFirebaseException(_exception('network-request-failed')), const NetworkFailure());
  });

  for (final code in [
    'wrong-password',
    'user-not-found',
    'invalid-credential',
    'invalid-email',
    'user-disabled',
  ]) {
    test('$code maps to InvalidCredentialsFailure', () {
      expect(mapFirebaseException(_exception(code)), const InvalidCredentialsFailure());
    });
  }

  test('an unrecognized code with a message maps to UnknownFailure(message)', () {
    final failure = mapFirebaseException(_exception('some-other-code', message: 'weird error'));
    expect(failure, isA<UnknownFailure>());
    expect(failure.message, 'weird error');
  });

  test('an unrecognized code with no message falls back to UnknownFailure(code)', () {
    final failure = mapFirebaseException(_exception('some-other-code'));
    expect(failure, isA<UnknownFailure>());
    expect(failure.message, 'some-other-code');
  });
}
