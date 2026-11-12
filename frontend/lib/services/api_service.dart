import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ServerConnection {
  final bool isOnline;
  final String message;
  const ServerConnection({required this.isOnline, required this.message});
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? details;
  const ApiException(this.statusCode, this.message, {this.code, this.details});
  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment('API_URL', defaultValue: 'https://ginata-backend.onrender.com/api/v1');
  static const _secureStorage = FlutterSecureStorage();
  static http.Client client = http.Client();
  static String orgId = 'org-ginata-prime';
  static String? authToken;
  static String hostName = 'Host';
  static Future<void> Function()? onUnauthorized;
  static bool _handlingUnauthorized = false;
  static Map<String, String> get _headers => {'Content-Type': 'application/json', if (authToken?.isNotEmpty == true) 'Authorization': 'Bearer $authToken'};

  static Future<void> init() => loadSession();
  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    orgId = prefs.getString('host_org_id') ?? 'org-ginata-prime';
    authToken = await _secureStorage.read(key: 'auth_token');
    hostName = await _secureStorage.read(key: 'host_name') ?? 'Host';
  }
  static Future<ServerConnection> checkServerConnection() async {
    try {
      final response = await client.get(Uri.parse(baseUrl).replace(path: '/')).timeout(const Duration(seconds: 45));
      return ServerConnection(isOnline: response.statusCode == 200, message: response.statusCode == 200 ? 'Connected to Ginata.' : 'Server unavailable (HTTP ${response.statusCode}). Please retry.');
    } catch (_) {
      return const ServerConnection(isOnline: false, message: 'Could not connect to Ginata. Check your connection and retry.');
    }
  }
  static Future<void> _checkResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = 'Request failed (HTTP ${response.statusCode}).';
    String? code;
    Map<String, dynamic>? details;
    try {
      final detail = (jsonDecode(response.body) as Map)['detail'];
      if (detail is String) message = detail;
      if (detail is Map) {
        details = Map<String, dynamic>.from(detail);
        message = detail['message']?.toString() ?? message;
        code = detail['code']?.toString();
      }
      if (detail is List && detail.isNotEmpty) message = detail.first['msg'].toString();
    } catch (_) {}
    if (response.statusCode == 401 && !_handlingUnauthorized && onUnauthorized != null) {
      _handlingUnauthorized = true;
      try { await onUnauthorized!(); } finally { _handlingUnauthorized = false; }
    }
    if (response.statusCode == 404 && message == 'Not Found') {
      message = 'This feature is not available on the server yet. Please update the Ginata backend.';
    }
    throw ApiException(response.statusCode, message, code: code, details: details);
  }
  static Future<http.Response> _response(String method, Uri uri, {Object? body}) async {
    if (uri.origin != Uri.parse(baseUrl).origin) throw const ApiException(0, 'Untrusted download address');
    final http.Response response;
    try {
      final req = http.Request(method, uri)..headers.addAll(_headers)..followRedirects = false;
      if (body != null) req.body = jsonEncode(body);
      response = await http.Response.fromStream(await client.send(req)).timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const ApiException(0, 'The server took too long to respond. Refresh before retrying to avoid duplicate changes.');
    } on http.ClientException {
      throw const ApiException(0, 'Could not reach Ginata. Check your connection. No local-only changes were saved.');
    }
    await _checkResponse(response);
    return response;
  }
  static Future<dynamic> request(String method, String path, {Object? body, Map<String, String>? query}) async {
    final response = await _response(method, Uri.parse('$baseUrl$path').replace(queryParameters: query), body: body);
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }
  static Future<Map<String, dynamic>> _map(String method, String path, {Object? body, Map<String, String>? query}) async => Map<String, dynamic>.from(await request(method, path, body: body, query: query) as Map);
  static Future<List<dynamic>> _list(String path, {Map<String, String>? query}) async => await request('GET', path, query: query) as List<dynamic>;

  static Future<List<dynamic>> fetchProperties() => _list('/properties');
  static Future<Map<String, dynamic>?> fetchPropertyCalendar(String id) => _map('GET', '/properties/$id/calendar');
  static Future<Map<String, dynamic>> createProperty(Map<String, dynamic> data) => _map('POST', '/properties', body: data);
  static Future<Map<String, dynamic>> updateProperty(String id, Map<String, dynamic> data) => _map('PATCH', '/properties/$id', body: data);
  static Future<void> deleteProperty(String id) async { await request('DELETE', '/properties/$id'); }
  static Future<Map<String, dynamic>> syncPropertyChannels(String id) => _map('POST', '/properties/$id/sync-channels');
  static Future<List<dynamic>> fetchPropertyInventory(String id) => _list('/properties/$id/inventory');
  static Future<Map<String, dynamic>> createInventoryItem(String id, Map<String, dynamic> data) => _map('POST', '/properties/$id/inventory', body: data);
  static Future<void> deleteInventoryItem(String id, String itemId) async { await request('DELETE', '/properties/$id/inventory/$itemId'); }
  static Future<List<dynamic>> fetchExpenses({String? propertyId, String? category}) => _list('/finances/expenses', query: {'property_id': ?propertyId, if (category != null && category != 'All') 'category': category});
  static Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) => _map('POST', '/finances/expenses', body: data);
  static Future<void> deleteExpense(String id) async { await request('DELETE', '/finances/expenses/$id'); }
  static Future<Map<String, dynamic>> fetchFinancialSummary({String? propertyId}) => _map('GET', '/finances/summary', query: {'property_id': ?propertyId});
  static Future<List<dynamic>> fetchMessageThreads() => _list('/messages/threads');
  static Future<Map<String, dynamic>> createMessageThread(Map<String, dynamic> data) => _map('POST', '/messages/threads', body: data);
  static Future<List<dynamic>> fetchThreadMessages(String id) => _list('/messages/threads/$id/messages');
  static Future<Map<String, dynamic>> sendThreadMessage(String id, String content, {String senderType = 'host', String senderName = 'Host'}) => _map('POST', '/messages/threads/$id/messages', body: {'content': content, 'sender_type': senderType, 'sender_name': senderName});
  static Future<List<dynamic>> fetchMessageTemplates() async {
    final list = await _list('/messages/templates');
    return list.isEmpty ? await request('POST', '/messages/templates/seed') as List<dynamic> : list;
  }
  static Future<Map<String, dynamic>> createMessageTemplate(Map<String, dynamic> data) => _map('POST', '/messages/templates', body: data);
  static Future<Map<String, dynamic>> updateMessageTemplate(String id, Map<String, dynamic> data) => _map('PUT', '/messages/templates/$id', body: data);
  static Future<bool> deleteMessageTemplate(String id) async { await request('DELETE', '/messages/templates/$id'); return true; }
  static Future<void> markMessageTemplateUsed(String id) async { await request('POST', '/messages/templates/$id/use'); }
  static Future<Map<String, dynamic>> upload(String path, List<int> bytes, String filename) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))..followRedirects = false;
    if (authToken?.isNotEmpty == true) req.headers['Authorization'] = 'Bearer $authToken';
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final http.Response response;
    try { response = await http.Response.fromStream(await client.send(req)).timeout(const Duration(seconds: 60)); }
    on TimeoutException { throw const ApiException(0, 'Image upload timed out. Refresh before retrying.'); }
    on http.ClientException { throw const ApiException(0, 'Image upload failed. Check your connection.'); }
    await _checkResponse(response);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
  static Future<String> uploadImage(List<int> bytes, String filename) async {
    final data = await upload('/uploads/image', bytes, filename);
    return Uri.parse(baseUrl).resolve(data['url'] as String).toString();
  }
  static Future<Map<String, dynamic>?> fetchOrganization() => _map('GET', '/organization');
  static Future<Map<String, dynamic>> updateOrganization(Map<String, dynamic> data) => _map('PATCH', '/organization', body: data);
  static Future<List<dynamic>> fetchReservations({String? propertyId, String? statusFilter}) => _list('/reservations', query: {if (propertyId != null && propertyId != 'all') 'property_id': propertyId, if (statusFilter != null && statusFilter != 'all') 'status_filter': statusFilter});
  static Future<Map<String, dynamic>?> fetchReservation(String id) => _map('GET', '/reservations/$id');
  static Future<Map<String, dynamic>> createReservation(Map<String, dynamic> data) {
    final payload = Map<String, dynamic>.from(data);
    if (payload['primary_guest'] is Map) {
      final guest = payload['primary_guest'] as Map;
      payload.addAll({'guest_first_name': guest['first_name'] ?? 'Guest', 'guest_last_name': guest['last_name'] ?? '', 'guest_email': guest['email'], 'guest_phone': guest['phone']});
    }
    return _map('POST', '/reservations', body: payload);
  }
  static Future<Map<String, dynamic>> checkConflicts(Map<String, dynamic> data) => _map('POST', '/reservations/check-conflicts', body: data);
  static Future<Map<String, dynamic>> updateReservation(String id, Map<String, dynamic> data) => _map('PATCH', '/reservations/$id', body: data);
  static Future<Map<String, dynamic>> confirmReservation(String id) => _map('POST', '/reservations/$id/confirm');
  static Future<Map<String, dynamic>> cancelReservation(String id, {String? reason}) => _map('POST', '/reservations/$id/cancel', query: {'reason': ?reason});
  static Future<Map<String, dynamic>> checkIn(String id) => _map('POST', '/reservations/$id/check-in');
  static Future<Map<String, dynamic>> checkOut(String id) => _map('POST', '/reservations/$id/check-out');
  static Future<Map<String, dynamic>?> fetchFinancialTimeline(String id) => _map('GET', '/reservations/$id/financial-timeline');
  static Future<Map<String, dynamic>> generateGuestForm(String id) => _map('POST', '/reservations/$id/guest-form');
  static Future<List<dynamic>> fetchGuestSubmissions({String? statusFilter}) => _list('/guest-forms/submissions', query: {'status_filter': ?statusFilter});
  static Future<Map<String, dynamic>> reviewGuestSubmission(String id, String action, {String? notes}) => _map('POST', '/guest-form-submissions/$id/review', body: {'action': action, 'review_notes': notes, 'update_guest_profile': true});
  static Future<void> revokeToken(String token) async { await request('POST', '/guest-forms/tokens/$token/revoke'); }
  static Future<Map<String, dynamic>> fetchGoogleAccountStatus() => _map('GET', '/integrations/google/status');
  static Future<String> getGoogleAuthorizationUrl() async => (await _map('GET', '/integrations/google/authorize'))['authorization_url'] as String;
  static Future<void> disconnectGoogleAccount() async { await request('DELETE', '/integrations/google/connection'); }
  static Future<Map<String, dynamic>> fetchGoogleFormsStatus() => _map('GET', '/guest-forms/google/status');
  static Future<Map<String, dynamic>> linkGoogleForm(String form, {String? propertyId}) => _map('PUT', '/guest-forms/google/config', body: {'form': form, 'property_id': ?propertyId});
  static Future<void> unlinkGoogleForm() async { await request('DELETE', '/guest-forms/google/config'); }
  static Future<Map<String, dynamic>> syncGoogleForms() => _map('POST', '/guest-forms/google/sync');
  static Future<List<dynamic>> fetchGoogleFormResponses({String? syncStatus, String? matchStatus, int limit = 100}) => _list('/guest-forms/google/responses', query: {'sync_status': ?syncStatus, 'match_status': ?matchStatus, 'limit': '$limit'});
  static Future<Map<String, dynamic>> fetchGoogleFormResponse(String id) => _map('GET', '/guest-forms/google/responses/$id');
  static Future<Map<String, dynamic>> assignGoogleFormResponse(String id, String reservationId) => _map('POST', '/guest-forms/google/responses/$id/assign', body: {'reservation_id': reservationId});
  static Future<Map<String, dynamic>> fetchNotificationSummary() => _map('GET', '/notifications/summary');
  static Future<List<dynamic>> fetchNotifications({bool unreadOnly = false, int limit = 30}) => _list('/notifications', query: {'unread_only': '$unreadOnly', 'limit': '$limit'});
  static Future<void> markNotificationRead(String id) async { await request('POST', '/notifications/$id/read'); }
  static Future<void> markAllNotificationsRead() async { await request('POST', '/notifications/read-all'); }
  static Future<List<dynamic>> fetchInvoices({String? statusFilter}) => _list('/invoices', query: {'status_filter': ?statusFilter});
  static Future<Map<String, dynamic>?> fetchInvoice(String id) => _map('GET', '/invoices/$id');
  static Future<Map<String, dynamic>> createInvoice(String id, Map<String, dynamic> data) => _map('POST', '/reservations/$id/invoices', body: data);
  static Future<Map<String, dynamic>> updateInvoice(String id, Map<String, dynamic> data) => _map('PATCH', '/invoices/$id', body: {...data, 'force_edit': true});
  static Future<Map<String, dynamic>> issueInvoice(String id) => _map('POST', '/invoices/$id/issue');
  static Future<Map<String, dynamic>> exportInvoice(String id, String format) => _map('POST', '/invoices/$id/export', body: {'format': format});
  static Future<Map<String, dynamic>> sendInvoice(String id, String channel, String recipient, {String? message}) => _map('POST', '/invoices/$id/send', body: {'channel': channel, 'recipient': recipient, 'custom_message': message});
  static Future<List<dynamic>> fetchPayments({String? reservationId}) => _list('/payments', query: {'reservation_id': ?reservationId});
  static Future<Map<String, dynamic>> recordPayment(Map<String, dynamic> data) => _map('POST', '/payments', body: data);
  static Future<List<dynamic>> fetchReceipts({String? reservationId}) => _list('/payments/receipts', query: {'reservation_id': ?reservationId});
  static Future<Map<String, dynamic>> updateReceipt(String id, Map<String, dynamic> data) => _map('PATCH', '/payments/receipts/$id', body: data);
  static Future<Map<String, dynamic>> exportReceipt(String id) => _map('POST', '/payments/receipts/$id/export');
  static Future<Uint8List> downloadBytes(String apiPath) async => (await _response('GET', apiPath.startsWith('http') ? Uri.parse(apiPath) : Uri.parse('$baseUrl$apiPath'))).bodyBytes;
  static Future<Uint8List> downloadExpensesCsv({String? propertyId, String? category}) async => (await _response('GET', Uri.parse('$baseUrl/finances/expenses/export').replace(queryParameters: {'property_id': ?propertyId, if (category != null && category != 'All') 'category': category}))).bodyBytes;
  static Future<List<dynamic>> fetchTemplates() => _list('/templates');
  static Future<Map<String, dynamic>> updateTemplate(String id, Map<String, dynamic> data) => _map('PATCH', '/templates/$id', body: data);
  static Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> data) => _map('POST', '/templates', body: data);
  static Future<Uint8List> previewDocumentTemplate(Map<String, dynamic> design) async => (await _response('POST', Uri.parse('$baseUrl/templates/preview'), body: design)).bodyBytes;
  static Future<Map<String, dynamic>> applyTemplateToDocuments(String id) => _map('POST', '/templates/$id/apply');
  static Future<List<dynamic>> fetchDocuments({String? reservationId, String? docType}) => _list('/documents', query: {'reservation_id': ?reservationId, 'document_type': ?docType});
  static Future<List<dynamic>> fetchAuditLogs() => _list('/audit-logs');
  static Future<Map<String, dynamic>> fetchProfile() => _map('GET', '/auth/me');
  static Future<Map<String, dynamic>> fetchSubscription() => _map('GET', '/subscription');
  static Future<List<dynamic>> fetchTasks({String? status, String? kind, String? propertyId}) => _list('/tasks', query: {'status': ?status, 'kind': ?kind, 'property_id': ?propertyId});
  static Future<Map<String, dynamic>> fetchToday() => _map('GET', '/tasks/today');
  static Future<Map<String, dynamic>> createTask(Map<String, dynamic> data) => _map('POST', '/tasks', body: data);
  static Future<Map<String, dynamic>> updateTask(String id, Map<String, dynamic> data) => _map('PATCH', '/tasks/$id', body: data);
  static Future<void> deleteTask(String id) async { await request('DELETE', '/tasks/$id'); }
  static Future<List<dynamic>> fetchGuests({String search = ''}) => _list('/guests', query: {'search': search});
  static Future<Map<String, dynamic>> fetchGuest(String id) => _map('GET', '/guests/$id');
  static Future<Map<String, dynamic>> updateGuest(String id, Map<String, dynamic> data) => _map('PATCH', '/guests/$id', body: data);
  static Future<List<dynamic>> fetchExternalBlocks({String? start, String? end}) => _list('/properties/external-blocks', query: {'start': ?start, 'end': ?end});
}
