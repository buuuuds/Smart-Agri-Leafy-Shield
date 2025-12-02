import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capstone2/main.dart';
import 'package:capstone2/services/app_state_service.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Create app state service
    final appState = AppStateService();
    await appState.initialize();

    // Build the app with required appState parameter
    await tester.pumpWidget(MyApp(appState: appState));

    // Verify that MaterialApp widget exists
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
