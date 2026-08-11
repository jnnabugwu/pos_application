import 'package:bloc_test/bloc_test.dart';
import 'package:core/blocs/auth/auth_bloc.dart';
import 'package:core/blocs/auth/auth_event.dart';
import 'package:core/blocs/auth/auth_state.dart';
import 'package:core/entities/app_role.dart';
import 'package:core/entities/app_user.dart';
import 'package:core/failures/failure.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/mock_auth_repository.dart';

void main() {
  late MockAuthRepository authRepository;

  const user = AppUser(uid: 'u1', email: 'staff@pos.test', role: AppRole.staff);

  setUp(() {
    authRepository = MockAuthRepository();
    // AuthBloc subscribes to this in its constructor; tests that care about
    // a specific emission override this stub themselves.
    when(
      () => authRepository.authStateChanges(),
    ).thenAnswer((_) => const Stream.empty());
  });

  group('AuthBloc', () {
    blocTest<AuthBloc, AuthState>(
      'emits loading then success on a successful sign-in',
      setUp: () {
        when(
          () => authRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => const Right(user));
      },
      build: () => AuthBloc(authRepository),
      act: (bloc) => bloc.add(
        const SignInRequested(email: 'staff@pos.test', password: 'password123'),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(status: AuthStatus.success, user: user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits loading then failure on a failed sign-in',
      setUp: () {
        when(
          () => authRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async =>
              const Left(InvalidCredentialsFailure('Bad credentials.')),
        );
      },
      build: () => AuthBloc(authRepository),
      act: (bloc) => bloc.add(
        const SignInRequested(email: 'staff@pos.test', password: 'wrong'),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(
          status: AuthStatus.failure,
          failure: InvalidCredentialsFailure('Bad credentials.'),
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'clears a stale failure on a fresh sign-in attempt',
      setUp: () {
        when(
          () => authRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => const Right(user));
      },
      build: () => AuthBloc(authRepository),
      seed: () => const AuthState(
        status: AuthStatus.failure,
        failure: InvalidCredentialsFailure('Bad credentials.'),
      ),
      act: (bloc) => bloc.add(
        const SignInRequested(email: 'staff@pos.test', password: 'password123'),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(status: AuthStatus.success, user: user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'resets to initial state on sign-out',
      setUp: () {
        when(
          () => authRepository.signOut(),
        ).thenAnswer((_) async => const Right(unit));
      },
      build: () => AuthBloc(authRepository),
      seed: () => const AuthState(status: AuthStatus.success, user: user),
      act: (bloc) => bloc.add(const SignOutRequested()),
      expect: () => [const AuthState()],
    );

    blocTest<AuthBloc, AuthState>(
      'keeps the current user and surfaces a failure when sign-out fails',
      setUp: () {
        when(
          () => authRepository.signOut(),
        ).thenAnswer((_) async => const Left(UnknownFailure('Network error.')));
      },
      build: () => AuthBloc(authRepository),
      seed: () => const AuthState(status: AuthStatus.success, user: user),
      act: (bloc) => bloc.add(const SignOutRequested()),
      expect: () => [
        const AuthState(
          status: AuthStatus.failure,
          user: user,
          failure: UnknownFailure('Network error.'),
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'clears a stale user when sign-in fails',
      setUp: () {
        when(
          () => authRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async =>
              const Left(InvalidCredentialsFailure('Bad credentials.')),
        );
      },
      build: () => AuthBloc(authRepository),
      seed: () => const AuthState(status: AuthStatus.success, user: user),
      act: (bloc) => bloc.add(
        const SignInRequested(email: 'staff@pos.test', password: 'wrong'),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading, user: user),
        const AuthState(
          status: AuthStatus.failure,
          failure: InvalidCredentialsFailure('Bad credentials.'),
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'resolves a restored session from authStateChanges() without an '
      'explicit SignInRequested',
      setUp: () {
        when(
          () => authRepository.authStateChanges(),
        ).thenAnswer((_) => Stream.value(user));
      },
      build: () => AuthBloc(authRepository),
      expect: () => [const AuthState(status: AuthStatus.success, user: user)],
    );

    blocTest<AuthBloc, AuthState>(
      'clears the user when authStateChanges() emits null (signed out '
      'from outside this bloc)',
      setUp: () {
        when(
          () => authRepository.authStateChanges(),
        ).thenAnswer((_) => Stream.value(null));
      },
      build: () => AuthBloc(authRepository),
      seed: () => const AuthState(status: AuthStatus.success, user: user),
      expect: () => [const AuthState()],
    );
  });
}
