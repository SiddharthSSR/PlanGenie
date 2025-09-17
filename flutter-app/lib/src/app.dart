import 'package:flutter/material.dart';

import '../screens/home.dart';
import '../screens/login.dart';
import '../screens/onboarding.dart';
import 'theme/app_theme.dart';

class PlanGenieApp extends StatelessWidget {
  const PlanGenieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlanGenie',
      debugShowCheckedModeBanner: false,
      theme: PlanGenieTheme.light(),
      initialRoute: '/',
      routes: {
        '/': (context) => const OnboardingScreen(),
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
