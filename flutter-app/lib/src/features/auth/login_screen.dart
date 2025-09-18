import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:plangenie/src/widgets/feedback_banner.dart';

import 'services/auth_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final _authService = AuthService(FirebaseAuth.instance);

  PhoneSignInHandle? _phoneHandle;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _statusMessage;
  FeedbackBannerVariant _statusVariant = FeedbackBannerVariant.success;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer
                  .withAlpha((0.5 * 255).round()),
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
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Plan smarter, travel better',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sign in to sync itineraries, manage bookings, and pick up where you left off.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 32),
                          label: const Text('Continue with Google'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _FormDivider(label: 'or continue with'),
                        const SizedBox(height: 16),
                        _AuthTabs(
                          emailForm: _EmailLoginForm(
                            emailController: _emailController,
                            passwordController: _passwordController,
                            obscurePassword: _obscurePassword,
                            isLoading: _isLoading,
                            onTogglePassword: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                            onSignIn: _signInWithEmail,
                            onCreateAccount: _openSignUpScreen,
                            onForgotPassword: _showResetPasswordDialog,
                          ),
                          phoneForm: _PhoneLoginForm(
                            phoneController: _phoneController,
                            smsCodeController: _smsCodeController,
                            handle: _phoneHandle,
                            isLoading: _isLoading,
                            onSendCode: _startPhoneSignIn,
                            onVerifyCode: _confirmSmsCode,
                            onResendCode: _resendCode,
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          FeedbackBanner(
                            message: _errorMessage!,
                            variant: FeedbackBannerVariant.error,
                          ),
                        ],
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 16),
                          FeedbackBanner(
                            message: _statusMessage!,
                            variant: _statusVariant,
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          'By continuing, you agree to our Terms of Service and confirm you have read our Privacy Policy.',
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
    );
  }

  Future<void> _signInWithGoogle() async {
    await _runAuthFlow(() => _authService.signInWithGoogle());
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Enter both email and password.');
      return;
    }

    await _runAuthFlow(
      () => _authService.signInWithEmail(email: email, password: password),
    );
  }

  Future<void> _startPhoneSignIn() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('Enter a phone number including country code.');
      return;
    }

    await _runAuthFlow(() async {
      final handle = await _authService.startPhoneNumberSignIn(phone);
      if (!mounted) {
        if (handle.completedCredential != null) {
          return handle.completedCredential!;
        }
        throw StateError('Widget disposed before verification.');
      }

      if (handle.isCompleted) {
        setState(() {
          _phoneHandle = handle;
          _smsCodeController.clear();
        });
        return handle.completedCredential!;
      }

      setState(() {
        _phoneHandle = handle;
        _smsCodeController.clear();
      });

      _showStatus(
        'SMS code sent. Enter the code to continue.',
        variant: FeedbackBannerVariant.info,
      );
      throw _PendingPhoneAuth();
    });
  }

  Future<void> _confirmSmsCode() async {
    final code = _smsCodeController.text.trim();
    if (_phoneHandle == null || code.length < 6) {
      _showError('Enter the 6-digit verification code.');
      return;
    }

    await _runAuthFlow(
      () => _authService.confirmSmsCode(_phoneHandle!, code),
    );
  }

  Future<void> _resendCode() async {
    final phone = _phoneController.text.trim();
    if (_phoneHandle == null || phone.isEmpty) {
      _showError('Enter your phone number to resend the code.');
      return;
    }

    await _runAuthFlow(() async {
      final handle = await _authService.startPhoneNumberSignIn(
        phone,
        forceResendToken: _phoneHandle!.resendToken,
      );
      setState(() {
        _phoneHandle = handle;
        _smsCodeController.clear();
      });
      _showStatus(
        'Verification code resent.',
        variant: FeedbackBannerVariant.info,
      );
      throw _PendingPhoneAuth();
    });
  }

  void _openSignUpScreen() {
    if (_isLoading) {
      return;
    }
    Navigator.of(context)
        .push<String>(
          MaterialPageRoute<String>(
            builder: (_) => const SignUpScreen(),
          ),
        )
        .then((message) {
          if (!mounted || message == null) {
            return;
          }
          _showStatus(message);
        });
  }

  Future<void> _runAuthFlow(
    Future<dynamic> Function() action, {
    String? successMessage,
  }) async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _statusVariant = FeedbackBannerVariant.success;
      _errorMessage = null;
    });

    try {
      final result = await action();
      if (result is UserCredential) {
        _showStatus(successMessage ??
            'Welcome back, ${result.user?.displayName ?? 'traveler'}!');
      }
    } on _PendingPhoneAuth {
      // Intermediate step: wait for user to enter SMS code.
    } on FirebaseAuthException catch (error) {
      _showError(error.message ?? 'Authentication failed.');
    } catch (error) {
      _showError('Something went wrong. Please try again.');
      debugPrint('Auth error: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showStatus(
    String message, {
    FeedbackBannerVariant variant = FeedbackBannerVariant.success,
  }) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusVariant = variant;
      _errorMessage = null;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _statusMessage = null;
    });
  }

  void _showResetPasswordDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: const Text(
          'Password reset will be available soon. In the meantime contact support@plangenie.app for manual assistance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _PendingPhoneAuth implements Exception {}

class _FormDivider extends StatelessWidget {
  const _FormDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Divider(color: colorScheme.outlineVariant),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(
          child: Divider(color: colorScheme.outlineVariant),
        ),
      ],
    );
  }
}

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({
    required this.emailForm,
    required this.phoneForm,
  });

  final Widget emailForm;
  final Widget phoneForm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer
                  .withAlpha((0.12 * 255).round()),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: theme.colorScheme.onPrimaryContainer,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                tabs: const [
                  Tab(text: 'Email'),
                  Tab(text: 'Phone number'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: TabBarView(
              children: [
                emailForm,
                phoneForm,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailLoginForm extends StatelessWidget {
  const _EmailLoginForm({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onForgotPassword,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final Future<void> Function() onSignIn;
  final VoidCallback onCreateAccount;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.alternate_email),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: onTogglePassword,
              icon: Icon(
                  obscurePassword ? Icons.visibility : Icons.visibility_off),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: isLoading ? null : onSignIn,
          style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14)),
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign in'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: isLoading ? null : onCreateAccount,
          child: const Text('Create an account'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: isLoading ? null : onForgotPassword,
            child: Text(
              'Forgot password?',
              style: theme.textTheme.labelLarge,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneLoginForm extends StatelessWidget {
  const _PhoneLoginForm({
    required this.phoneController,
    required this.smsCodeController,
    required this.handle,
    required this.isLoading,
    required this.onSendCode,
    required this.onVerifyCode,
    required this.onResendCode,
  });

  final TextEditingController phoneController;
  final TextEditingController smsCodeController;
  final PhoneSignInHandle? handle;
  final bool isLoading;
  final Future<void> Function() onSendCode;
  final Future<void> Function() onVerifyCode;
  final Future<void> Function() onResendCode;

  bool get _codeSent =>
      handle != null &&
      !handle!.isCompleted &&
      (handle!.verificationId != null || handle!.confirmationResult != null);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+1 555 010 1234',
            prefixIcon: Icon(Icons.phone_iphone),
          ),
        ),
        const SizedBox(height: 12),
        if (_codeSent) ...[
          TextField(
            controller: smsCodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'SMS verification code',
              prefixIcon: Icon(Icons.password_outlined),
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: isLoading
              ? null
              : _codeSent
                  ? onVerifyCode
                  : onSendCode,
          style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14)),
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _codeSent ? 'Verify and sign in' : 'Send verification code'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: !isLoading && _codeSent ? onResendCode : null,
          child: const Text('Resend code'),
        ),
        const Spacer(),
        Text(
          'We will send a one-time code to validate your number. Standard carrier rates apply.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

