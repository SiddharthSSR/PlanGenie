import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';
import 'theme/app_theme.dart';

class PlanGenieApp extends StatelessWidget {
  const PlanGenieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlanGenie',
      debugShowCheckedModeBanner: false,
      theme: PlanGenieTheme.light(),
      home: const HomeScreen(),
    );
  }
}
