import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_app/main.dart';
import 'package:focus_app/services/audio_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // Initialize global audioHandler for testing
  audioHandler = MyAudioHandler();

  testWidgets('ZenTask smoke test and calendar navigation test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ZenTaskApp());

    // Wait for SharedPreferences async load to complete and update UI state
    await tester.pumpAndSettle();

    // Verify that the main sections are loaded
    expect(find.text('Categories'), findsOneWidget);
    expect(find.textContaining('Focus List'), findsOneWidget);
    expect(find.text('Focus Balance'), findsOneWidget);

    // Verify calendar button is present
    final calendarIcon = find.byIcon(Icons.calendar_month_rounded);
    expect(calendarIcon, findsOneWidget);

    // Tap calendar button to open Month Calendar
    await tester.tap(calendarIcon);
    await tester.pumpAndSettle();

    // Verify CalendarScreen is displayed
    expect(find.text('Mindful Calendar'), findsOneWidget);
    expect(find.text('Total Focus'), findsOneWidget);
    expect(find.text('Active Days'), findsOneWidget);
  });
}
