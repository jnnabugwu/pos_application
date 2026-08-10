import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pos_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:pos_app/features/auth/presentation/bloc/auth_state.dart';

import '../../../../support/fake_auth_repository.dart';

void main() {
  late MockAuthRepository authRepository;

  const user = AppUser(uid: 'u1', email: 'staff@pos.test', role: AppRole.staff);

  setUp(() {
    authRepository = MockAuthRepository();
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
  });
}
