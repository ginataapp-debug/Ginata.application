import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginata_app/screens/login_screen.dart';
import 'package:ginata_app/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Map<String, dynamic> body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('password reset requests a code and submits a new password', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/auth/password/forgot')) {
        return _json({'success': true, 'message': 'If the account exists, a code has been sent.'});
      }
      if (request.url.path.endsWith('/auth/password/reset')) {
        return _json({'success': true, 'message': 'Password updated.'});
      }
      return http.Response('Not found', 404);
    });

    final previousClient = AuthService.client;
    AuthService.client = client;
    addTearDown(() {
      client.close();
      AuthService.client = previousClient;
    });

    await tester.pumpWidget(MaterialApp(home: LoginScreen(onLoginSuccess: () {})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    final resetEmail = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Account email',
    );
    await tester.enterText(resetEmail, 'host@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    Future<void> enterField(String label, String value) async {
      final field = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.enterText(field, value);
    }

    await enterField('Six-digit reset code', '123456');
    await enterField('New password', 'a-strong-password');
    await enterField('Confirm new password', 'a-strong-password');
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();

    expect(find.text('Password updated. Sign in with your new password.'), findsOneWidget);
    expect(requests.map((request) => request.url.path), [
      '/api/v1/auth/password/forgot',
      '/api/v1/auth/password/reset',
    ]);
    final resetBody = jsonDecode(requests.last.body) as Map<String, dynamic>;
    expect(resetBody['email'], 'host@example.com');
    expect(resetBody['code'], '123456');
    expect(resetBody['new_password'], 'a-strong-password');
    expect(tester.takeException(), isNull);
  });
}
