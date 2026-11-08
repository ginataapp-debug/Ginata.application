import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginata_app/main.dart';
import 'package:ginata_app/theme/ginata_theme.dart';

void main() {
  testWidgets('GinataApp smoke test - verifies brand title, KES formatting, and navigation tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build the Ginata app
    await tester.pumpWidget(const GinataApp());
    await tester.pumpAndSettle();

    // Verify brand title and dashboard elements
    expect(find.text('GINATA'), findsWidgets);
    expect(find.text('Good morning, Clara'), findsOneWidget);
    expect(find.text('SUPERHOST'), findsOneWidget);

    // Verify KES currency formatting
    final sampleKES = GinataFormatters.formatKES(15000);
    expect(sampleKES, contains('KES'));
    expect(sampleKES, contains('15,000'));

    // Verify navigation bar items exist
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Stays'), findsWidgets);
    expect(find.text('Forms'), findsWidgets);
    expect(find.text('Studio'), findsWidgets);
    expect(find.text('Branding'), findsWidgets);

    // Tap on Calendar tab in dock
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(find.text('Unified Calendar'), findsOneWidget);

    // Tap on Stays tab in dock
    await tester.tap(find.text('Stays').last);
    await tester.pumpAndSettle();
    expect(find.text('Reservations'), findsOneWidget);

    // Tap on Forms tab in dock
    await tester.tap(find.text('Forms').last);
    await tester.pumpAndSettle();
    expect(find.text('Guest Form Builder & Inbox'), findsOneWidget);

    // Tap on Studio tab in dock
    await tester.tap(find.text('Studio').last);
    await tester.pumpAndSettle();
    expect(find.text('Invoice & Receipt Document Studio'), findsOneWidget);
  });
}
