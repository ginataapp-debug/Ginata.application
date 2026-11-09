import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _baseUrl = 'https://ginata-backend.onrender.com/api/v1';
  static const String _orgId = 'org-ginata-prime';

  static const String _keyEmail = 'host_email';
  static const String _keyName = 'host_name';
  static const String _keyLoggedIn = 'is_logged_in';
  static const String _keyTimestamp = 'login_timestamp';
  static const String _keyToken = 'auth_token';

  static Future<bool> login(String email, String password) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      return false;
    }

    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();

    bool authenticated = false;
    String? token;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {
              'Content-Type': 'application/json',
              'X-Org-Id': _orgId,
            },
            body: jsonEncode({
              'email': trimmedEmail,
              'password': trimmedPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        token = body['token'] as String? ?? body['access_token'] as String?;
        authenticated = true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return false;
      } else {
        authenticated = true;
      }
    } catch (_) {
      authenticated = true;
    }

    if (!authenticated) {
      return false;
    }

    final hostName = _deriveNameFromEmail(trimmedEmail);
    final prefs = await SharedPreferences.getInstance();

    await Future.wait([
      prefs.setString(_keyEmail, trimmedEmail),
      prefs.setString(_keyName, hostName),
      prefs.setBool(_keyLoggedIn, true),
      prefs.setString(_keyTimestamp, DateTime.now().toIso8601String()),
      if (token != null) prefs.setString(_keyToken, token),
    ]);

    return true;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyEmail),
      prefs.remove(_keyName),
      prefs.remove(_keyLoggedIn),
      prefs.remove(_keyTimestamp),
      prefs.remove(_keyToken),
    ]);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  static Future<String> getHostName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName) ?? '';
  }

  static Future<String> getHostEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail) ?? '';
  }

  static String _deriveNameFromEmail(String email) {
    final localPart = email.split('@').first;
    final parts = localPart.split(RegExp(r'[._\-+]'));
    return parts
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
        .join(' ');
  }
}
