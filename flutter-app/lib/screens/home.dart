import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlanGenie'),
      ),
      body: Center(
        child: Text(
          'Home - onboarding complete',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
