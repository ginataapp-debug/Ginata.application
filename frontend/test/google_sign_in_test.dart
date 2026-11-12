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

  test('PKCE challenge uses SHA-256 and base64url without padding', () {
    expect(
      AuthService.createGoogleCodeChallenge(
        'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
      ),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });

  test('Google callback exchanges PKCE code for a Ginata session', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/auth/config')) {
        return _json({'google_sign_in_enabled': true});
      }
      if (request.url.path.endsWith('/auth/google/authorize-url')) {
        return _json({
          'url': 'https://supabase.example.test/auth/v1/authorize',
        });
      }
      if (request.url.path.endsWith('/auth/google')) {
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
      }
      if (request.url.path.endsWith('/auth/me')) {
        expect(request.headers['authorization'], 'Bearer ginata-session-token');
        return _json({
          'id': 'host-1',
          'email': 'host@example.com',
          'full_name': 'Test Host',
          'organization_id': 'organization-1',
          'is_active': true,
          'is_verified': true,
        });
      }
      return http.Response('Not found', 404);
    });
    final previousClient = AuthService.client;
    AuthService.client = client;
    addTearDown(() {
      AuthService.client = previousClient;
      client.close();
    });

    final started = await AuthService.beginGoogleSignIn(
      redirectUri: 'https://ginata.example.test/',
    );
    expect(started['success'], isTrue);
    expect(started['url'], startsWith('https://'));

    final authorizeBody = jsonDecode(requests[1].body) as Map<String, dynamic>;
    expect(authorizeBody['redirect_to'], 'https://ginata.example.test/');

    final callback = await AuthService.handleGoogleCallback(
      Uri.parse('https://ginata.example.test/?code=supabase-auth-code'),
    );
    expect(callback?['success'], isTrue);

    final exchangeBody = jsonDecode(requests[2].body) as Map<String, dynamic>;
    expect(exchangeBody['code'], 'supabase-auth-code');
    final verifier = exchangeBody['code_verifier'] as String;
    expect(verifier, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(
      AuthService.createGoogleCodeChallenge(verifier),
      authorizeBody['code_challenge'],
    );
    expect(await AuthService.getToken(), 'ginata-session-token');
    expect(await AuthService.validateSession(), SessionValidation.valid);
  });

  test(
    'Google cancellation is reported and does not exchange a code',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/auth/config')) {
          return _json({'google_sign_in_enabled': true});
        }
        if (request.url.path.endsWith('/auth/google/authorize-url')) {
          return _json({
            'url': 'https://supabase.example.test/auth/v1/authorize',
          });
        }
        return http.Response('Unexpected request', 500);
      });
      final previousClient = AuthService.client;
      AuthService.client = client;
      addTearDown(() {
        AuthService.client = previousClient;
        client.close();
      });

      await AuthService.beginGoogleSignIn(
        redirectUri: AuthService.androidGoogleRedirectUri,
      );
      final result = await AuthService.handleGoogleCallback(
        Uri.parse(
          '${AuthService.androidGoogleRedirectUri}?error=access_denied',
        ),
      );

      expect(result?['success'], isFalse);
      expect(result?['message'], 'Google sign-in was cancelled.');
      expect(requests, hasLength(2));
    },
  );

  test(
    'untrusted callback is ignored and expired code reports failure',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/auth/config')) {
          return _json({'google_sign_in_enabled': true});
        }
        if (request.url.path.endsWith('/auth/google/authorize-url')) {
          return _json({
            'url': 'https://supabase.example.test/auth/v1/authorize',
          });
        }
        if (request.url.path.endsWith('/auth/google')) {
          return _json({
            'detail': 'Google sign-in expired or was rejected.',
          }, status: 400);
        }
        return http.Response('Unexpected request', 500);
      });
      final previousClient = AuthService.client;
      AuthService.client = client;
      addTearDown(() {
        AuthService.client = previousClient;
        client.close();
      });

      await AuthService.beginGoogleSignIn(
        redirectUri: 'https://ginata.example.test/',
      );
      expect(
        await AuthService.handleGoogleCallback(
          Uri.parse('https://attacker.example.test/?code=untrusted'),
        ),
        isNull,
      );
      final result = await AuthService.handleGoogleCallback(
        Uri.parse('https://ginata.example.test/?code=expired-code'),
      );
      expect(result?['success'], isFalse);
      expect(result?['message'], 'Google sign-in expired or was rejected.');
      expect(requests, hasLength(3));
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
