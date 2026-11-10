import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class AuthService {
  static String get _baseUrl => ApiService.baseUrl;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _defaultOrgId = 'org-ginata-prime';

  static const String _keyEmail = 'host_email';
  static const String _keyName = 'host_name';
  static const String _keyPhone = 'host_phone';
  static const String _keyLoggedIn = 'is_logged_in';
  static const String _keyTimestamp = 'login_timestamp';
  static const String _keyToken = 'auth_token';
  static const String _keyOrgId = 'host_org_id';
  static const String _keyLastLogin = 'host_last_login_at';
  static const String _keyVerified = 'host_is_verified';

  static Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String? organizationName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName.trim();
    final cleanPhone = phone?.trim();

    if (cleanEmail.isEmpty || password.isEmpty || cleanName.isEmpty) {
      return {'success': false, 'message': 'Name, email, and password are required.'};
    }
    if (password.length < 10) {
      return {'success': false, 'message': 'Password must be at least 10 characters.'};
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'full_name': cleanName,
              'email': cleanEmail,
              'password': password,
              'phone': cleanPhone,
              if (organizationName != null && organizationName.trim().isNotEmpty)
                'organization_name': organizationName.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 201) {
        if (body['verification_required'] == true) {
          // No token is issued or persisted until the server accepts the code.
          return body;
        }
        return await _acceptSession(body);
      }
      return _errorResponse(body, 'Registration failed. Please try again.');
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot reach the Ginata server. Account creation needs an internet connection so your credentials are stored securely. Check your connection and try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      return {'success': false, 'message': 'Please enter both email and password.'};
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': cleanEmail,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return await _acceptSession(body);
      }
      return _errorResponse(body, 'Invalid email or password.');
    } catch (_) {
      return {
        'success': false,
        'message': 'Cannot reach the Ginata server. Sign-in must be verified online to keep your account secure. Check your connection and try again.',
      };
    }
  }

  static Map<String, dynamic> _errorResponse(Map<String, dynamic> body, String fallback) {
    final detail = body['detail'];
    if (detail is Map) {
      return {
        'success': false,
        'message': detail['message']?.toString() ?? fallback,
        'verification_required': detail['verification_required'] == true,
      };
    }
    return {'success': false, 'message': detail is String ? detail : fallback};
  }

  static Future<Map<String, dynamic>> _acceptSession(Map<String, dynamic> body) async {
    final host = body['host'] as Map<String, dynamic>? ?? {};
    final token = body['token'] as String?;
    final orgId = body['organization_id'] as String?;
    if (body['success'] != true || token == null || token.isEmpty || orgId == null || orgId.isEmpty) {
      return {'success': false, 'message': 'The server did not issue a valid session. Please sign in again.'};
    }
    await _saveSession(
      email: host['email']?.toString() ?? '',
      name: host['full_name']?.toString() ?? 'Host',
      phone: host['phone']?.toString(),
      token: token,
      orgId: orgId,
      lastLoginAt: host['last_login_at']?.toString(),
      isVerified: host['is_verified'] == true,
    );
    return body;
  }

  static Future<Map<String, dynamic>> sendVerification(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verification/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase(), 'password': password}),
      ).timeout(const Duration(seconds: 30));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) return body;
      return _errorResponse(body, 'Could not send a confirmation code.');
    } catch (_) {
      return {'success': false, 'message': 'Could not reach the server to send a confirmation code.'};
    }
  }

  static Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verification/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase(), 'code': code}),
      ).timeout(const Duration(seconds: 30));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) return await _acceptSession(body);
      return _errorResponse(body, 'Could not confirm your email.');
    } catch (_) {
      return {'success': false, 'message': 'Could not reach the server to confirm your email.'};
    }
  }

  /// Requires online validation; no fallback sign-in when validation fails.
  static Future<bool> validateSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await getToken();
    if (token.isEmpty || token.startsWith('local-') || token == 'offline-token') {
      await logout();
      return false;
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final host = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveSession(
          email: host['email'] ?? '',
          name: host['full_name'] ?? 'Host',
          phone: host['phone'],
          token: token,
          orgId: host['organization_id'] ?? prefs.getString(_keyOrgId) ?? _defaultOrgId,
          lastLoginAt: host['last_login_at']?.toString(),
          isVerified: host['is_verified'] == true,
        );
        return true;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _saveSession({
    required String email,
    required String name,
    String? phone,
    required String token,
    required String orgId,
    String? lastLoginAt,
    bool? isVerified,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await _secureStorage.write(key: _keyToken, value: token);
    await Future.wait([
      _secureStorage.write(key: _keyEmail, value: email),
      _secureStorage.write(key: _keyName, value: name),
      _secureStorage.write(key: _keyPhone, value: phone ?? ''),
      prefs.remove(_keyEmail),
      prefs.remove(_keyName),
      prefs.remove(_keyPhone),
      prefs.setBool(_keyLoggedIn, true),
      prefs.setString(_keyTimestamp, DateTime.now().toIso8601String()),
      prefs.setString(_keyOrgId, orgId),
      if (lastLoginAt != null) prefs.setString(_keyLastLogin, lastLoginAt),
      if (isVerified != null) prefs.setBool(_keyVerified, isVerified),
    ]);
    await ApiService.loadSession();
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await getToken();
    if (token.isNotEmpty && !token.startsWith('local-') && token != 'offline-token') {
      try {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
    await _secureStorage.delete(key: _keyToken);
    await Future.wait([
      _secureStorage.delete(key: _keyEmail),
      _secureStorage.delete(key: _keyName),
      _secureStorage.delete(key: _keyPhone),
      prefs.remove(_keyEmail),
      prefs.remove(_keyName),
      prefs.remove(_keyPhone),
      prefs.remove(_keyLoggedIn),
      prefs.remove(_keyTimestamp),
      prefs.remove(_keyToken),
      prefs.remove(_keyOrgId),
      prefs.remove(_keyLastLogin),
      prefs.remove(_keyVerified),
    ]);
    await ApiService.loadSession();
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await getToken();
    return (prefs.getBool(_keyLoggedIn) ?? false) && token.isNotEmpty;
  }

  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken); // Old insecure sessions require a fresh sign-in.
    try {
      return await _secureStorage.read(key: _keyToken) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<String> getHostName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName);
    return await _secureStorage.read(key: _keyName) ?? 'Host';
  }

  static Future<String> getHostEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    return await _secureStorage.read(key: _keyEmail) ?? '';
  }

  static Future<String> getHostPhone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPhone);
    return await _secureStorage.read(key: _keyPhone) ?? '';
  }

  static Future<String> getHostOrgId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOrgId) ?? _defaultOrgId;
  }

  static Future<String> getLastLoginAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastLogin) ?? '';
  }

  static Future<bool> isVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVerified) ?? false;
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phone,
    String? email,
  }) async {
    final token = await getToken();
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (fullName != null) 'full_name': fullName.trim(),
          if (phone != null) 'phone': phone.trim(),
          if (email != null) 'email': email.trim(),
        }),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await Future.wait([
          if (body['full_name'] != null) _secureStorage.write(key: _keyName, value: body['full_name']),
          _secureStorage.write(key: _keyPhone, value: body['phone'] ?? ''),
          if (body['email'] != null) _secureStorage.write(key: _keyEmail, value: body['email']),
          prefs.setBool(_keyVerified, body['is_verified'] == true),
        ]);
        await ApiService.loadSession();
        return {'success': true, 'host': body};
      }
      return {'success': false, 'message': body['detail'] ?? 'Could not update profile.'};
    } catch (_) {
      return {'success': false, 'message': 'Cannot reach the server. Profile changes need a connection.'};
    }
  }

}
