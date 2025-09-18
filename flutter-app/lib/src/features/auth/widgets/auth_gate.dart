import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:plangenie/screens/onboarding.dart';
import 'package:plangenie/src/features/auth/providers/auth_providers.dart';
import 'package:plangenie/screens/home.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) => user != null ? const HomePage() : const OnboardingScreen(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const Scaffold(
        body: Center(child: Text('Something went wrong. Please try again.')),
      ),
    );
  }
}
