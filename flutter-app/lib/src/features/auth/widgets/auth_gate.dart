import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:plangenie/screens/onboarding.dart';


import 'package:plangenie/screens/home.dart';


class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);


        if (snapshot.hasData) {
          return const HomePage();
        }

        return const OnboardingScreen();
      },

    return authState.when(
      data: (user) => user != null ? const HomeScreen() : const OnboardingScreen(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const Scaffold(
        body: Center(child: Text('Something went wrong. Please try again.')),
      ),

    );
  }
}
