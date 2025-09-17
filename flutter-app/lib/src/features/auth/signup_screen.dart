import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:plangenie/src/widgets/feedback_banner.dart';

import 'services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService(FirebaseAuth.instance);

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _acceptedTerms = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create your account'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer
                  .withAlpha((0.35 * 255).round()),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Create your PlanGenie account',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                         Text(
                           'Unlock personalized trips, collaborative planning, and synced itineraries across devices.',
                           style: theme.textTheme.bodyMedium,
                         ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            FeedbackBanner(
                              message: _errorMessage!,
                              variant: FeedbackBannerVariant.error,
                            ),
                          ],
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _fullNameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your full name.';
                              }
                              if (value.trim().split(' ').length < 2) {
                                return 'Add first and last name for a richer profile.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter an email address.';
                              }
                              final emailPattern = RegExp(r'^.+@.+\..+$');
                              if (!emailPattern.hasMatch(value.trim())) {
                                return 'Enter a valid email.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              hintText: '+1 555 010 1234',
                              prefixIcon: Icon(Icons.phone_iphone),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Add a phone number to stay in the loop.';
                              }
                              if (!value.trim().startsWith('+')) {
                                return 'Use international format starting with + country code.';
                              }
                              if (value.trim().length < 10) {
                                return 'Double-check the phone number length.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.length < 8) {
                                return 'Create a password with at least 8 characters.';
                              }
                              if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                return 'Add at least one uppercase letter.';
                              }
                              if (!RegExp(r'[0-9]').hasMatch(value)) {
                                return 'Add at least one number.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              prefixIcon: const Icon(Icons.verified_user_outlined),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                                ),
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Re-enter your password.';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            value: _acceptedTerms,
                            onChanged: _isLoading
                                ? null
                                : (value) => setState(() => _acceptedTerms = value ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'I agree to the Terms of Service and Privacy Policy.',
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Create account'),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                            child: const Text('Back to sign in'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'We’ll verify your email and phone so travel alerts reach you instantly.',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_acceptedTerms) {
      _setError('Accept the Terms of Service to continue.');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      _setError('Review the highlighted fields to continue.');
      return;
    }

    FocusScope.of(context).unfocus();
    final name = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await _authService.createAccountWithEmail(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(name);
      if (credential.user != null && !(credential.user!.emailVerified)) {
        await credential.user!.sendEmailVerification();
      }

      // TODO: Persist additional profile fields (e.g. phone) to your backend once available.

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        'Account created. Check your email to verify access.',
      );
    } on FirebaseAuthException catch (error) {
      _setError(error.message ?? 'Account creation failed.');
    } catch (error) {
      _setError('Something went wrong. Please try again.');
      debugPrint('Sign up error: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }
}
