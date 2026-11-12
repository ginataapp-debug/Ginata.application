import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginata_app/screens/template_settings_screen.dart';
import 'package:ginata_app/services/auth_service.dart';
import 'package:ginata_app/services/api_service.dart';
import 'package:ginata_app/theme/ginata_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.client = http.Client();
    ApiService.authToken = 'host-token';
  });

  tearDown(() {
    ApiService.client.close();
    AuthService.client.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('brand settings load, preview, save, and expose password security', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <http.Request>[];
    final passwordRequests = <http.Request>[];
    ApiService.client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/organization')) {
        if (request.method == 'GET') {
          return _json({
            'id': 'org-test',
            'name': 'Garden Estates',
            'email': 'host@example.com',
            'phone': '+254700000000',
            'address': 'Karen Road',
            'city': 'Nairobi',
            'country': 'Kenya',
            'currency': 'KES',
          });
        }
        return _json(jsonDecode(request.body) as Map<String, dynamic>);
      }
      if (request.url.path.endsWith('/templates')) {
        return _json([
          {
            'id': 'template-1',
            'name': 'Default',
            'layout_style': 'minimalist_luxury',
            'font_family': 'Plus Jakarta Sans',
            'primary_color': '#003329',
            'secondary_color': '#466557',
            'payment_instructions': 'Pay by M-Pesa',
            'tax_notes': 'Tax included as applicable',
            'footer_text': 'Thank you for staying.',
            'header_text': 'Garden Estates',
            'is_default': true,
          }
        ]);
      }
      if (request.url.path.endsWith('/templates/template-1')) {
        return _json(jsonDecode(request.body) as Map<String, dynamic>);
      }
      return _json({'detail': 'Not found'}, 404);
    });
    final previousAuthClient = AuthService.client;
    final authClient = MockClient((request) async {
      passwordRequests.add(request);
      return _json({'success': true, 'message': 'Password changed.'});
    });
    AuthService.client = authClient;
    addTearDown(() {
      authClient.close();
      AuthService.client = previousAuthClient;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      if (call.method == 'read' && call.arguments['key'] == 'auth_token') return 'host-token';
      return null;
    });

    await tester.pumpWidget(MaterialApp(
      theme: buildGinataTheme(),
      home: const TemplateSettingsScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Host Profile & Brand Studio'), findsOneWidget);
    expect(find.text('Official Ginata Brand Mark'), findsOneWidget);
    expect(find.text('Garden Estates'), findsWidgets);

    Future<void> scrollToVisible(Finder target) async {
      for (var attempt = 0;
          attempt < 20 && target.hitTestable().evaluate().isEmpty;
          attempt++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      expect(target.hitTestable(), findsOneWidget);
    }

    final preset = find.text('Midnight & Brass');
    await scrollToVisible(preset);
    await tester.tap(preset);
    await tester.pumpAndSettle();
    await scrollToVisible(find.text('ACCOUNT SECURITY'));
    expect(find.text('Change password'), findsOneWidget);
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    Future<void> enterPasswordField(String label, String value) async {
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.enterText(field, value);
    }

    await enterPasswordField('Current password', 'old-password');
    await enterPasswordField('New password', 'a-strong-password');
    await enterPasswordField('Confirm new password', 'a-strong-password');
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(passwordRequests, hasLength(1));
    expect(passwordRequests.single.url.path, '/api/v1/auth/password/change');
    expect(passwordRequests.single.headers['authorization'], 'Bearer host-token');
    expect(
      jsonDecode(passwordRequests.single.body),
      {'current_password': 'old-password', 'new_password': 'a-strong-password'},
    );
    expect(find.text('Password updated. Other sessions have been signed out.'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final organizationSave = requests.firstWhere(
      (request) => request.method == 'PATCH' && request.url.path.endsWith('/organization'),
    );
    final templateSave = requests.firstWhere(
      (request) => request.method == 'PATCH' && request.url.path.endsWith('/templates/template-1'),
    );
    final savedTemplate = jsonDecode(templateSave.body) as Map<String, dynamic>;
    expect(savedTemplate['primary_color'], '#101828');
    expect(savedTemplate['secondary_color'], '#B89758');
    expect(jsonDecode(organizationSave.body)['name'], 'Garden Estates');
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings show a retry state instead of hiding backend errors', (tester) async {
    ApiService.client = MockClient((request) async => _json({'detail': 'Server unavailable'}, 503));
    await tester.pumpWidget(const MaterialApp(home: TemplateSettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Could not load your settings.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
