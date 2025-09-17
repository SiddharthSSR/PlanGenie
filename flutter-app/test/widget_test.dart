import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plangenie/src/app.dart';

void main() {
  testWidgets('home screen renders intro copy', (WidgetTester tester) async {
    await tester.pumpWidget(const PlanGenieApp());

    expect(find.text('Welcome to PlanGenie'), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
  });
}
