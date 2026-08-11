import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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

  testWidgets(
    'shows a validation message and does not call signIn when fields are empty',
    (tester) async {
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

      await tester.tap(find.widgetWithText(PrimaryButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Enter both email and password.'), findsOneWidget);
      verifyNever(
        () => authRepository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    },
  );
}
