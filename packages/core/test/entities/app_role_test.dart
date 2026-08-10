import 'package:core/entities/app_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRole.fromName', () {
    test('resolves admin', () {
      expect(AppRole.fromName('admin'), AppRole.admin);
    });

    test('resolves staff', () {
      expect(AppRole.fromName('staff'), AppRole.staff);
    });

    test('throws ArgumentError on an unknown name', () {
      expect(() => AppRole.fromName('owner'), throwsArgumentError);
    });
  });
}
