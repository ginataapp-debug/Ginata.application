import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginata_app/main.dart';
import 'package:ginata_app/screens/login_screen.dart';
import 'package:ginata_app/screens/splash_screen.dart';
import 'package:ginata_app/screens/payment_modal.dart';
import 'package:ginata_app/theme/ginata_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('animated splash assembles the tree and reveals the brand', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final semantics = tester.ensureSemantics();

    var completed = false;
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onComplete: () => completed = true)),
    );

    expect(find.byType(Image), findsWidgets);
    expect(find.text('PROPERTY MANAGEMENT'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/images/logo.png',
      ),
      findsNothing,
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    expect(completed, isTrue);
    expect(find.bySemanticsLabel('Ginata'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('host sign-in screen is usable on a phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(onLoginSuccess: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign In to Host Portal'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    final passwordField = tester.getCenter(
      find.widgetWithText(TextFormField, 'Password *'),
    );
    final forgotPasswordLink = tester.getCenter(
      find.text('Forgot password?'),
    );
    expect(forgotPasswordLink.dy, greaterThan(passwordField.dy));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('host sign-in screen adapts to a wide desktop viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(onLoginSuccess: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('A more\nthoughtful stay\nstarts here.'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign In to Host Portal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app opens with the splash and then the host portal', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    const appLinksChannel = MethodChannel('com.llfbandit.app_links/messages');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'read') return null;
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appLinksChannel, (call) async => null);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appLinksChannel, null);
    });

    await tester.pumpWidget(const GinataApp());
    expect(find.text('PROPERTY MANAGEMENT'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Sign In to Host Portal'), findsOneWidget);
  });

  testWidgets('reduced-motion splash completes exactly once', (tester) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SplashScreen(onComplete: () => completed++),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('payment choices preserve cents and fit a phone', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PaymentModal(
            reservationId: 'test-reservation',
            totalAmount: 1001.50,
            balanceDue: 1001.50,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final amount = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(amount.controller!.text, '1001.50');
    await tester.tap(find.text('Half'));
    await tester.pump();
    expect(amount.controller!.text, '500.75');
    await tester.tap(find.text('Pay in full'));
    await tester.pump();
    expect(amount.controller!.text, '1001.50');
    expect(tester.takeException(), isNull);
  });

  test('KES formatting remains consistent', () {
    final sample = GinataFormatters.formatKES(15000);
    expect(sample, contains('KES'));
    expect(sample, contains('15,000'));
    expect(GinataFormatters.formatKES(1001.50), 'KES 1,001.50');
    expect(GinataFormatters.formatKES(500.75), 'KES 500.75');
  });
}
