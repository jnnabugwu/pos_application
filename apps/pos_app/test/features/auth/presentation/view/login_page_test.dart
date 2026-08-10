import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pos_app/features/auth/presentation/view/login_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../../support/fake_auth_repository.dart';

void main() {
  testWidgets('LoginPage renders email/password fields and a sign-in button', (
    tester,
  ) async {
    final authRepository = MockAuthRepository();
    final bloc = AuthBloc(authRepository);
    addTearDown(bloc.close);

    await tester.pumpWidget(
      ShadcnApp(
        home: BlocProvider<AuthBloc>.value(
          value: bloc,
          child: const LoginPage(),
        ),
      ),
    );

    expect(find.text('Sign in'), findsWidgets);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
