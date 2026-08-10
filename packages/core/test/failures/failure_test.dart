import 'package:core/failures/failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkFailure', () {
    test('has a default message', () {
      expect(const NetworkFailure().message, 'No network connection.');
    });

    test('accepts a custom message', () {
      expect(const NetworkFailure('timed out').message, 'timed out');
    });
  });

  group('PermissionFailure', () {
    test('has a default message', () {
      expect(
        const PermissionFailure().message,
        "You don't have permission to do that.",
      );
    });

    test('accepts a custom message', () {
      expect(
        const PermissionFailure('no role assigned').message,
        'no role assigned',
      );
    });
  });

  group('NotFoundFailure', () {
    test('has a default message', () {
      expect(const NotFoundFailure().message, 'Not found.');
    });

    test('accepts a custom message', () {
      expect(const NotFoundFailure('item missing').message, 'item missing');
    });
  });

  group('InvalidCredentialsFailure', () {
    test('has a default message', () {
      expect(
        const InvalidCredentialsFailure().message,
        'Incorrect email or password.',
      );
    });

    test('accepts a custom message', () {
      expect(
        const InvalidCredentialsFailure('bad password').message,
        'bad password',
      );
    });
  });

  group('UnknownFailure', () {
    test('requires an explicit message', () {
      expect(const UnknownFailure('boom').message, 'boom');
    });
  });

  test('failures with the same message and type are equal', () {
    expect(const NetworkFailure('x'), const NetworkFailure('x'));
  });

  test(
    'failures with different types are not equal, even with the same message',
    () {
      expect(const NetworkFailure('x'), isNot(const UnknownFailure('x')));
    },
  );
}
