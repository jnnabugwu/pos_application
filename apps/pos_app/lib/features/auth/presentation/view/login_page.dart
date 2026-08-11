import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _validationError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    // Not trimmed: a password's leading/trailing whitespace is part of the
    // credential Firebase Auth checks against, unlike an email address.
    final password = _passwordController.text;

    if (email.isEmpty || password.trim().isEmpty) {
      setState(() => _validationError = 'Enter both email and password.');
      return;
    }

    setState(() => _validationError = null);
    context.read<AuthBloc>().add(
      SignInRequested(email: email, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final loading = state.status == AuthStatus.loading;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Sign in').h2,
                    const Gap(4),
                    const Text('Staff access to the live menu').muted,
                    const Gap(24),
                    TextField(
                      controller: _emailController,
                      placeholder: const Text('Email'),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !loading,
                    ),
                    const Gap(12),
                    TextField(
                      controller: _passwordController,
                      placeholder: const Text('Password'),
                      obscureText: true,
                      enabled: !loading,
                      onSubmitted: (_) => loading ? null : _submit(),
                    ),
                    if (_validationError != null ||
                        state.status == AuthStatus.failure) ...[
                      const Gap(12),
                      Text(
                        _validationError ??
                            state.failure?.message ??
                            'Sign in failed.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.destructive,
                        ),
                      ).textSmall,
                    ],
                    const Gap(20),
                    PrimaryButton(
                      onPressed: loading ? null : _submit,
                      child: Text(loading ? 'Signing in…' : 'Sign in'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
