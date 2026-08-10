import 'package:flutter_test/flutter_test.dart';

import 'package:manager_app/main.dart';

void main() {
  testWidgets('app builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(tester.takeException(), isNull);
  });
}
