import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginata_app/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureValues = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureValues.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          final arguments = Map<String, dynamic>.from(call.arguments as Map);
          switch (call.method) {
            case 'read':
              return secureValues[arguments['key']];
            case 'write':
              secureValues[arguments['key'] as String] =
                  arguments['value'] as String;
              return null;
            case 'delete':
              secureValues.remove(arguments['key']);
              return null;
            case 'deleteAll':
              secureValues.clear();
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  test('login sends normalized email and stores the server session', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return _json({
        'success': true,
        'token': 'ginata-session-token',
        'organization_id': 'organization-1',
        'host': {
          'email': 'host@example.com',
          'full_name': 'Test Host',
          'is_verified': true,
        },
      });
    });
    final previousClient = AuthService.client;
    AuthService.client = client;
    addTearDown(() {
      AuthService.client = previousClient;
      client.close();
    });

    final result = await AuthService.login(
      ' HOST@example.com ',
      ' secure password ',
    );

    expect(result['success'], isTrue);
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/v1/auth/login');
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['email'], 'host@example.com');
    expect(body['password'], ' secure password ');
    expect(await AuthService.getToken(), 'ginata-session-token');
    expect(
      (await SharedPreferences.getInstance()).getBool('is_logged_in'),
      isTrue,
    );
  });

  test(
    'login surfaces rejected credentials without creating a session',
    () async {
      final client = MockClient(
        (_) async =>
            _json({'detail': 'Invalid email or password.'}, status: 401),
      );
      final previousClient = AuthService.client;
      AuthService.client = client;
      addTearDown(() {
        AuthService.client = previousClient;
        client.close();
      });

      final result = await AuthService.login('host@example.com', 'wrong');

      expect(result['success'], isFalse);
      expect(result['message'], 'Invalid email or password.');
      expect(await AuthService.getToken(), isEmpty);
    },
  );
}

http.Response _json(Map<String, dynamic> body, {int status = 200}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
