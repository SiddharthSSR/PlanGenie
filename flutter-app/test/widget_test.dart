import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plangenie/src/app.dart';

void main() {
  testWidgets('onboarding screen renders first panel',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PlanGenieApp());

    expect(find.text('Travel DNA'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint), findsOneWidget);
  });
}
