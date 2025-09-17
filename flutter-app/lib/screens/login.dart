import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    // TODO: Integrate Firebase Auth Google Sign-In here.
    await _runAuthFlow(() => _simulateAuthFlow('Google'));
  }

  Future<void> _handleAppleSignIn() async {
    // TODO: Integrate Firebase Auth Apple Sign-In here using sign_in_with_apple.
    await _runAuthFlow(() => _simulateAuthFlow('Apple'));
  }

  Future<void> _handleEmailSignIn() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    form.save();
    // TODO: Integrate Firebase Auth email/password sign-in here.
    await _runAuthFlow(() => _simulateAuthFlow('Email'));
  }

  Future<void> _runAuthFlow(Future<bool> Function() action) async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final success = await action();
      if (!mounted) {
        return;
      }
      if (success) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _showAuthFailure();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool> _simulateAuthFlow(String provider) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    // TODO: Replace this simulation with real authentication logic for the selected provider.
    return true;
  }

  void _showAuthFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to sign in. Please try again.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showAppleButton = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pick the best way to continue',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Semantics(
                button: true,
                label: 'Continue with Google',
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleGoogleSignIn,
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Continue with Google'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (showAppleButton) ...[
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: 'Continue with Apple',
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _handleAppleSignIn,
                    icon: const Icon(Icons.apple),
                    label: const Text('Continue with Apple'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Text(
                'Or sign in with email',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      button: true,
                      label: 'Sign in with email and password',
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleEmailSignIn,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Text('Sign in'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
