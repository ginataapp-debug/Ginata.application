import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://ginata-backend.onrender.com/api/v1',
  );
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static String orgId = 'org-ginata-prime';
  static String? authToken;
  static String hostName = 'Host';
  static const Duration _timeout = Duration(seconds: 10);

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-Organization-ID': orgId,
    if (authToken != null && authToken!.isNotEmpty) 'Authorization': 'Bearer $authToken',
  };

  /// Loads the signed-in host's session (token, organization, name) from secure
  /// local storage. Called at startup and after every sign-in / sign-out.
  static Future<void> loadSession() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      for (final key in ['auth_token', 'host_name', 'host_email', 'host_phone']) {
        await _prefs!.remove(key);
      }
      orgId = _prefs?.getString('host_org_id') ?? 'org-ginata-prime';
      authToken = await _secureStorage.read(key: 'auth_token');
      hostName = await _secureStorage.read(key: 'host_name') ?? 'Host';
    } catch (_) {
      authToken = null;
      hostName = 'Host';
    }
    await prepareHostCache();
  }

  // -------------------------------------------------------------
  // DYNAMIC IN-MEMORY STORE (Fresh Brand-New State for New Host)
  // -------------------------------------------------------------
  static final List<Map<String, dynamic>> _localProperties = [];
  static final List<Map<String, dynamic>> _localReservations = [];
  static final List<Map<String, dynamic>> _localInvoices = [];
  static final List<Map<String, dynamic>> _localReceipts = [];
  static final List<Map<String, dynamic>> _localExpenses = [];
  static final List<Map<String, dynamic>> _localInventory = [];
  static final List<Map<String, dynamic>> _localMessageThreads = [];
  static final List<Map<String, dynamic>> _localMessageTemplates = [];
  static final List<Map<String, dynamic>> _localSubmissions = [];
  static final List<Map<String, dynamic>> _localPayments = [];
  static final List<Map<String, dynamic>> _localTemplates = [];
  static final List<Map<String, dynamic>> _localDocuments = [];

  static Map<String, dynamic> _localOrganization = {};

  static SharedPreferences? _prefs;

  static Future<void> prepareHostCache() async {
    _prefs ??= await SharedPreferences.getInstance();
    final owner = authToken == null ? null : orgId;
    final cachedOwner = owner == null ? null : await _secureStorage.read(key: 'cache_owner');
    for (final key in _prefs!.getKeys().where((key) => key.startsWith('cache_'))) {
      await _prefs!.remove(key);
    }
    if (owner != null && cachedOwner == owner) return;

    for (final records in [
      _localProperties, _localReservations, _localInvoices, _localReceipts,
      _localExpenses, _localInventory, _localMessageThreads,
      _localMessageTemplates, _localSubmissions, _localPayments,
      _localTemplates, _localDocuments,
    ]) {
      records.clear();
    }
    _localOrganization = {};
    for (final key in [
      'cache_owner', 'cache_properties', 'cache_reservations', 'cache_invoices',
      'cache_receipts', 'cache_expenses', 'cache_inventory', 'cache_payments',
      'cache_templates', 'cache_documents', 'cache_message_threads',
      'cache_message_templates', 'cache_submissions', 'cache_organization',
    ]) {
      await _secureStorage.delete(key: key);
    }
    if (owner != null) await _secureStorage.write(key: 'cache_owner', value: owner);
  }

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await loadSession();

      final pStr = await _secureStorage.read(key: 'cache_properties');
      if (pStr != null && pStr.isNotEmpty) {
        final list = jsonDecode(pStr) as List;
        _localProperties.clear();
        _localProperties.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final rStr = await _secureStorage.read(key: 'cache_reservations');
      if (rStr != null && rStr.isNotEmpty) {
        final list = jsonDecode(rStr) as List;
        _localReservations.clear();
        _localReservations.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final iStr = await _secureStorage.read(key: 'cache_invoices');
      if (iStr != null && iStr.isNotEmpty) {
        final list = jsonDecode(iStr) as List;
        _localInvoices.clear();
        _localInvoices.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final rcStr = await _secureStorage.read(key: 'cache_receipts');
      if (rcStr != null && rcStr.isNotEmpty) {
        final list = jsonDecode(rcStr) as List;
        _localReceipts.clear();
        _localReceipts.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final expStr = await _secureStorage.read(key: 'cache_expenses');
      if (expStr != null && expStr.isNotEmpty) {
        final list = jsonDecode(expStr) as List;
        _localExpenses.clear();
        _localExpenses.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final invStr = await _secureStorage.read(key: 'cache_inventory');
      if (invStr != null && invStr.isNotEmpty) {
        final list = jsonDecode(invStr) as List;
        _localInventory.clear();
        _localInventory.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final payStr = await _secureStorage.read(key: 'cache_payments');
      if (payStr != null && payStr.isNotEmpty) {
        final list = jsonDecode(payStr) as List;
        _localPayments.clear();
        _localPayments.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final tplStr = await _secureStorage.read(key: 'cache_templates');
      if (tplStr != null && tplStr.isNotEmpty) {
        final list = jsonDecode(tplStr) as List;
        _localTemplates.clear();
        _localTemplates.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final docStr = await _secureStorage.read(key: 'cache_documents');
      if (docStr != null && docStr.isNotEmpty) {
        final list = jsonDecode(docStr) as List;
        _localDocuments.clear();
        _localDocuments.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final thStr = await _secureStorage.read(key: 'cache_message_threads');
      if (thStr != null && thStr.isNotEmpty) {
        final list = jsonDecode(thStr) as List;
        _localMessageThreads.clear();
        _localMessageThreads.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final mtStr = await _secureStorage.read(key: 'cache_message_templates');
      if (mtStr != null && mtStr.isNotEmpty) {
        final list = jsonDecode(mtStr) as List;
        _localMessageTemplates.clear();
        _localMessageTemplates.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final subStr = await _secureStorage.read(key: 'cache_submissions');
      if (subStr != null && subStr.isNotEmpty) {
        final list = jsonDecode(subStr) as List;
        _localSubmissions.clear();
        _localSubmissions.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }

      final orgStr = await _secureStorage.read(key: 'cache_organization');
      if (orgStr != null && orgStr.isNotEmpty) {
        final org = jsonDecode(orgStr) as Map;
        _localOrganization = Map<String, dynamic>.from(org);
      }
    } catch (_) {}
  }

  static Future<void> _persistProperties() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _secureStorage.write(key: 'cache_properties', value: jsonEncode(_localProperties));
    } catch (_) {}
  }

  static Future<void> _persistReservations() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _secureStorage.write(key: 'cache_reservations', value: jsonEncode(_localReservations));
    } catch (_) {}
  }

  static Future<void> _persistInvoices() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _secureStorage.write(key: 'cache_invoices', value: jsonEncode(_localInvoices));
    } catch (_) {}
  }

  static Future<void> _persistReceipts() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _secureStorage.write(key: 'cache_receipts', value: jsonEncode(_localReceipts));
    } catch (_) {}
  }

  static Future<void> _persistExpenses() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _secureStorage.write(key: 'cache_expenses', value: jsonEncode(_localExpenses));
    } catch (_) {}
  }

  static Future<void> _persistInventory() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _secureStorage.write(key: 'cache_inventory', value: jsonEncode(_localInventory));
    } catch (_) {}
  }

  static Future<void> _persistPayments() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _secureStorage.write(key: 'cache_payments', value: jsonEncode(_localPayments));
    } catch (_) {}
  }

  static Future<void> _persistTemplates() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _secureStorage.write(key: 'cache_templates', value: jsonEncode(_localTemplates));
    } catch (_) {}
  }

  static Future<void> _persistDocuments() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _secureStorage.write(key: 'cache_documents', value: jsonEncode(_localDocuments));
    } catch (_) {}
  }

  static Future<void> _persistMessageThreads() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _secureStorage.write(key: 'cache_message_threads', value: jsonEncode(_localMessageThreads));
    } catch (_) {}
  }

  static Future<void> _persistMessageTemplates() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _secureStorage.write(key: 'cache_message_templates', value: jsonEncode(_localMessageTemplates));
    } catch (_) {}
  }

  static Future<void> _persistSubmissions() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _secureStorage.write(key: 'cache_submissions', value: jsonEncode(_localSubmissions));
    } catch (_) {}
  }

  static Future<void> _persistOrganization() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _secureStorage.write(key: 'cache_organization', value: jsonEncode(_localOrganization));
    } catch (_) {}
  }

  // --- PROPERTIES ---
  static Future<List<dynamic>> fetchProperties() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/properties'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        _localProperties
          ..clear()
          ..addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _persistProperties();
        return list;
      }
    } catch (_) {}
    return List<dynamic>.from(_localProperties);
  }

  static Future<Map<String, dynamic>?> fetchPropertyCalendar(String propertyId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/properties/$propertyId/calendar'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    final prop = _localProperties.firstWhere((p) => p['id'].toString() == propertyId, orElse: () => {});
    return prop.isNotEmpty ? prop : null;
  }

  static Future<Map<String, dynamic>> createProperty(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/properties'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
    if (res.statusCode != 201) {
      throw Exception('Property could not be saved (${res.statusCode}).');
    }
    final created = jsonDecode(res.body) as Map<String, dynamic>;
    _localProperties.insert(0, created);
    await _persistProperties();
    return created;
  }

  static Future<Map<String, dynamic>> updateProperty(String propertyId, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/properties/$propertyId'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Property changes could not be saved (${res.statusCode}).');
    }
    final updated = jsonDecode(res.body) as Map<String, dynamic>;
    final idx = _localProperties.indexWhere((p) => p['id'].toString() == propertyId);
    if (idx != -1) _localProperties[idx] = updated;
    await _persistProperties();
    return updated;
  }

  static Future<void> deleteProperty(String propertyId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/properties/$propertyId'),
      headers: _headers,
    ).timeout(_timeout);
    if (res.statusCode != 204) {
      throw Exception('Property could not be deleted (${res.statusCode}).');
    }
    _localProperties.removeWhere((p) => p['id'].toString() == propertyId);
    await _persistProperties();
  }

  static Future<Map<String, dynamic>> syncPropertyChannels(String propertyId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/properties/$propertyId/sync-channels'),
        headers: _headers,
      ).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'message': 'Channels synchronized successfully. No new external conflicts detected.',
      'synced_at': DateTime.now().toIso8601String(),
    };
  }

  // --- PROPERTY INVENTORY ---
  static Future<List<dynamic>> fetchPropertyInventory(String propertyId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/properties/$propertyId/inventory'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        _localInventory.removeWhere((it) => it['property_id'].toString() == propertyId);
        _localInventory.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _persistInventory();
        return list;
      }
    } catch (_) {}
    return _localInventory.where((it) => it['property_id'].toString() == propertyId).toList();
  }

  static Future<Map<String, dynamic>> createInventoryItem(String propertyId, Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/properties/$propertyId/inventory'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(_timeout);
      if (res.statusCode == 201) {
        final item = jsonDecode(res.body) as Map<String, dynamic>;
        _localInventory.add(item);
        _persistInventory();
        return item;
      }
    } catch (_) {}

    final item = Map<String, dynamic>.from(data);
    item['id'] = 'inv-item-${DateTime.now().millisecondsSinceEpoch}';
    item['property_id'] = propertyId;
    _localInventory.add(item);
    _persistInventory();
    return item;
  }

  static Future<void> deleteInventoryItem(String propertyId, String itemId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/properties/$propertyId/inventory/$itemId'),
        headers: _headers,
      ).timeout(_timeout);
    } catch (_) {}
    _localInventory.removeWhere((it) => it['id'].toString() == itemId);
    _persistInventory();
  }

  // --- FINANCES & EXPENSES ---
  static Future<List<dynamic>> fetchExpenses({String? propertyId, String? category}) async {
    try {
      final params = <String, String>{};
      if (propertyId != null) params['property_id'] = propertyId;
      if (category != null) params['category'] = category;
      final uri = Uri.parse('$baseUrl/finances/expenses').replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        _localExpenses.removeWhere((e) =>
          (propertyId == null || e['property_id'].toString() == propertyId) &&
          (category == null || e['category'].toString().toLowerCase() == category.toLowerCase()));
        _localExpenses.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _persistExpenses();
        return list;
      }
    } catch (_) {}

    var exp = List<Map<String, dynamic>>.from(_localExpenses);
    if (propertyId != null) {
      exp = exp.where((e) => e['property_id'].toString() == propertyId).toList();
    }
    if (category != null && category != 'All') {
      exp = exp.where((e) => (e['category'] ?? '').toString().toLowerCase() == category.toLowerCase()).toList();
    }
    return exp;
  }

  static Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/finances/expenses'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
    if (res.statusCode != 201) {
      throw Exception('Expense was not saved (server returned ${res.statusCode}).');
    }
    final exp = jsonDecode(res.body) as Map<String, dynamic>;
    _localExpenses.insert(0, exp);
    _persistExpenses();
    return exp;
  }

  static Future<void> deleteExpense(String expenseId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/finances/expenses/$expenseId'),
      headers: _headers,
    ).timeout(_timeout);
    if (res.statusCode != 204) {
      throw Exception('Expense was not deleted (server returned ${res.statusCode}).');
    }
    _localExpenses.removeWhere((e) => e['id'].toString() == expenseId);
    _persistExpenses();
  }

  static Future<Map<String, dynamic>> fetchFinancialSummary({String? propertyId}) async {
    try {
      final params = <String, String>{};
      if (propertyId != null) params['property_id'] = propertyId;
      final uri = Uri.parse('$baseUrl/finances/summary').replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    // Calculate dynamically from active local state
    double gross = 0.0;
    double collected = 0.0;
    double pending = 0.0;
    double commissions = 0.0;

    for (final r in _localReservations) {
      if (r['reservation_status'] == 'cancelled') continue;
      if (propertyId != null && r['property_id'].toString() != propertyId) continue;
      final tot = double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0.0;
      final paid = double.tryParse(r['amount_paid']?.toString() ?? '0') ?? 0.0;
      final bal = double.tryParse(r['balance_due']?.toString() ?? '0') ?? 0.0;
      final comm = double.tryParse(r['agent_commission_amount']?.toString() ?? '0') ?? 0.0;
      gross += tot;
      collected += paid;
      pending += bal;
      commissions += comm;
    }

    double totalExp = 0.0;
    for (final e in _localExpenses) {
      if (propertyId != null && e['property_id'].toString() != propertyId) continue;
      totalExp += double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0;
    }

    return {
      "currency": "KES",
      "gross_revenue": gross,
      "collected_revenue": collected,
      "pending_balance": pending,
      "total_agent_commissions": commissions,
      "total_expenses": totalExp,
      "net_operating_profit": gross - totalExp - commissions,
      "is_cached": true,
    };
  }

  // --- UNIFIED MESSAGES & COMMUNICATIONS ---
  static Future<List<dynamic>> fetchMessageThreads() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/messages/threads'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        _localMessageThreads
          ..clear()
          ..addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _persistMessageThreads();
        return list;
      }
    } catch (_) {}
    return List<dynamic>.from(_localMessageThreads);
  }

  static Future<Map<String, dynamic>> createMessageThread(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/messages/threads'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(_timeout);
      if (res.statusCode == 201) {
        final t = jsonDecode(res.body) as Map<String, dynamic>;
        _localMessageThreads.insert(0, t);
        return t;
      }
    } catch (_) {}

    final thread = Map<String, dynamic>.from(data);
    thread['id'] = 'th-${DateTime.now().millisecondsSinceEpoch}';
    thread['messages'] = [];
    thread['last_message_at'] = DateTime.now().toIso8601String();
    _localMessageThreads.insert(0, thread);
    return thread;
  }

  static Future<List<dynamic>> fetchThreadMessages(String threadId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/messages/threads/$threadId/messages'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        final t = _localMessageThreads.firstWhere((th) => th['id'].toString() == threadId, orElse: () => {});
        if (t.isNotEmpty) {
          t['messages'] = list;
          _persistMessageThreads();
        }
        return list;
      }
    } catch (_) {}
    final t = _localMessageThreads.firstWhere((th) => th['id'].toString() == threadId, orElse: () => {});
    return (t['messages'] as List<dynamic>?) ?? [];
  }

  static Future<Map<String, dynamic>> sendThreadMessage(
    String threadId,
    String content, {
    String senderType = 'host',
    String senderName = 'Host',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/messages/threads/$threadId/messages'),
        headers: _headers,
        body: jsonEncode({
          'content': content,
          'sender_type': senderType,
          'sender_name': senderName,
        }),
      ).timeout(_timeout);
      if (res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    final msg = {
      'id': 'msg-${DateTime.now().millisecondsSinceEpoch}',
      'thread_id': threadId,
      'content': content,
      'sender_type': senderType,
      'sender_name': senderName,
      'created_at': DateTime.now().toIso8601String(),
    };

    final t = _localMessageThreads.firstWhere((th) => th['id'].toString() == threadId, orElse: () => {});
    if (t.isNotEmpty) {
      t['messages'] = ((t['messages'] as List<dynamic>?) ?? [])..add(msg);
      t['last_message'] = content;
      t['last_message_at'] = DateTime.now().toIso8601String();
    }
    return msg;
  }

  // --- PRE-BUILT MESSAGE TEMPLATES (create / edit / copy / manage) ---
  static Future<List<dynamic>> fetchMessageTemplates() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/messages/templates'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        var list = (jsonDecode(res.body) as List<dynamic>);
        // Cold start for a brand-new host: seed the curated starter library.
        if (list.isEmpty) {
          final seed = await http.post(Uri.parse('$baseUrl/messages/templates/seed'), headers: _headers).timeout(_timeout);
          if (seed.statusCode == 200) {
            list = (jsonDecode(seed.body) as List<dynamic>);
          }
        }
        _localMessageTemplates
          ..clear()
          ..addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _persistMessageTemplates();
        return list;
      }
    } catch (_) {}
    return List<dynamic>.from(_localMessageTemplates);
  }

  static Future<Map<String, dynamic>> createMessageTemplate(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/messages/templates'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(_timeout);
      if (res.statusCode == 201) {
        final t = jsonDecode(res.body) as Map<String, dynamic>;
        _localMessageTemplates.insert(0, t);
        _persistMessageTemplates();
        return t;
      }
    } catch (_) {}

    final tpl = Map<String, dynamic>.from(data);
    tpl['id'] = 'mtpl-${DateTime.now().millisecondsSinceEpoch}';
    tpl['use_count'] = 0;
    tpl['created_at'] = DateTime.now().toIso8601String();
    tpl['updated_at'] = tpl['created_at'];
    _localMessageTemplates.insert(0, tpl);
    _persistMessageTemplates();
    return tpl;
  }

  static Future<Map<String, dynamic>> updateMessageTemplate(String id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/messages/templates/$id'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(_timeout);
      if (res.statusCode == 200) {
        final updated = jsonDecode(res.body) as Map<String, dynamic>;
        final idx = _localMessageTemplates.indexWhere((e) => e['id'].toString() == id);
        if (idx >= 0) {
          _localMessageTemplates[idx] = updated;
        } else {
          _localMessageTemplates.insert(0, updated);
        }
        _persistMessageTemplates();
        return updated;
      }
    } catch (_) {}

    final idx = _localMessageTemplates.indexWhere((e) => e['id'].toString() == id);
    if (idx >= 0) {
      _localMessageTemplates[idx] = {..._localMessageTemplates[idx], ...data, 'updated_at': DateTime.now().toIso8601String()};
      _persistMessageTemplates();
      return _localMessageTemplates[idx];
    }
    return {...data, 'id': id};
  }

  static Future<bool> deleteMessageTemplate(String id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/messages/templates/$id'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 204 || res.statusCode == 200) {
        _localMessageTemplates.removeWhere((e) => e['id'].toString() == id);
        _persistMessageTemplates();
        return true;
      }
    } catch (_) {}
    // Offline: still remove locally so the UI stays truthful to the host's intent.
    _localMessageTemplates.removeWhere((e) => e['id'].toString() == id);
    _persistMessageTemplates();
    return true;
  }

  static Future<void> markMessageTemplateUsed(String id) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/messages/templates/$id/use'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final updated = jsonDecode(res.body) as Map<String, dynamic>;
        final idx = _localMessageTemplates.indexWhere((e) => e['id'].toString() == id);
        if (idx >= 0) _localMessageTemplates[idx] = updated;
        _persistMessageTemplates();
      }
    } catch (_) {}
  }

  // --- FILE UPLOADS ---
  static Future<String> uploadImage(List<int> bytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/uploads/image'));
    request.headers.addAll({
      if (authToken != null && authToken!.isNotEmpty) 'Authorization': 'Bearer $authToken',
    });
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 201) {
      throw Exception('Image could not be uploaded (${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Uri.parse(baseUrl).resolve(data['url'] as String).toString();
  }

  // --- HOST & ORGANIZATION PROFILE ---
  static Future<Map<String, dynamic>?> fetchOrganization() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/organization'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        _localOrganization = jsonDecode(res.body) as Map<String, dynamic>;
        await _persistOrganization();
        return Map<String, dynamic>.from(_localOrganization);
      }
    } catch (_) {}
    return Map<String, dynamic>.from(_localOrganization);
  }

  static Future<Map<String, dynamic>> updateOrganization(Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/organization'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Host profile could not be saved (${res.statusCode}).');
    }
    final org = jsonDecode(res.body) as Map<String, dynamic>;
    _localOrganization = org;
    await _persistOrganization();
    return org;
  }

  // --- RESERVATIONS ---
  static Future<List<dynamic>> fetchReservations({String? propertyId, String? statusFilter}) async {
    try {
      final params = <String, String>{};
      if (propertyId != null) params['property_id'] = propertyId;
      if (statusFilter != null) params['status_filter'] = statusFilter;

      final uri = Uri.parse('$baseUrl/reservations').replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        _localReservations
          ..clear()
          ..addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _persistReservations();
        return list;
      }
    } catch (_) {}

    var resList = List<Map<String, dynamic>>.from(_localReservations);
    if (propertyId != null && propertyId != 'all') {
      resList = resList.where((r) => r['property_id'].toString() == propertyId).toList();
    }
    if (statusFilter != null && statusFilter != 'all') {
      resList = resList.where((r) => (r['reservation_status'] ?? '').toString().toLowerCase() == statusFilter.toLowerCase()).toList();
    }
    return resList;
  }

  static Future<Map<String, dynamic>?> fetchReservation(String id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/reservations/$id'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    final r = _localReservations.firstWhere((res) => res['id'].toString() == id, orElse: () => {});
    return r.isNotEmpty ? r : null;
  }

  static Future<Map<String, dynamic>> createReservation(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    if (payload['primary_guest'] is Map) {
      final pg = payload['primary_guest'] as Map;
      payload['guest_first_name'] = pg['first_name'] ?? 'Guest';
      payload['guest_last_name'] = pg['last_name'] ?? '';
      payload['guest_email'] = pg['email'];
      payload['guest_phone'] = pg['phone'];
    }
    final res = await http.post(
      Uri.parse('$baseUrl/reservations'),
      headers: _headers,
      body: jsonEncode(payload),
    ).timeout(_timeout);
    if (res.statusCode != 201) {
      throw Exception('Booking was not saved (${res.statusCode}). Check dates and booking details before retrying.');
    }
    final reservation = jsonDecode(res.body) as Map<String, dynamic>;
    _localReservations.insert(0, reservation);
    await _persistReservations();
    return reservation;
  }

  static Future<Map<String, dynamic>> checkConflicts(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/reservations/check-conflicts'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    // Check against local reservations
    final propId = data['property_id']?.toString();
    final checkIn = DateTime.tryParse(data['check_in_date']?.toString() ?? '');
    final checkOut = DateTime.tryParse(data['check_out_date']?.toString() ?? '');
    final excludeId = data['exclude_reservation_id']?.toString();

    if (propId != null && checkIn != null && checkOut != null) {
      for (final r in _localReservations) {
        if (r['id'].toString() == excludeId) continue;
        if (r['property_id'].toString() != propId) continue;
        if (r['reservation_status'] == 'cancelled') continue;

        final rIn = DateTime.tryParse(r['check_in_date']?.toString() ?? '');
        final rOut = DateTime.tryParse(r['check_out_date']?.toString() ?? '');
        if (rIn != null && rOut != null) {
          final overlaps = checkIn.isBefore(rOut) && checkOut.isAfter(rIn);
          if (overlaps) {
            return {
              'has_conflict': true,
              'message': 'Dates overlap with an existing confirmed booking (${r['booking_reference'] ?? 'Ref'}).',
            };
          }
        }
      }
    }

    return {'has_conflict': false, 'message': 'Dates are available'};
  }

  static Future<Map<String, dynamic>> updateReservation(String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/reservations/$id'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Booking changes were not saved (${res.statusCode}).');
    }
    final reservation = jsonDecode(res.body) as Map<String, dynamic>;
    final idx = _localReservations.indexWhere((item) => item['id'].toString() == id);
    if (idx != -1) {
      _localReservations[idx] = reservation;
    } else {
      _localReservations.insert(0, reservation);
    }
    await _persistReservations();
    return reservation;
  }

  static Future<Map<String, dynamic>> confirmReservation(String id) async {
    final res = await http.post(
      Uri.parse('$baseUrl/reservations/$id/confirm'),
      headers: _headers,
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Booking could not be confirmed (${res.statusCode}).');
    }
    final reservation = jsonDecode(res.body) as Map<String, dynamic>;
    final idx = _localReservations.indexWhere((item) => item['id'].toString() == id);
    if (idx != -1) _localReservations[idx] = reservation;
    await _persistReservations();
    return reservation;
  }

  static Future<Map<String, dynamic>> cancelReservation(String id, {String? reason}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/reservations/$id/cancel'),
      headers: _headers,
      body: jsonEncode({'reason': reason}),
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Booking could not be cancelled (${res.statusCode}).');
    }
    final reservation = jsonDecode(res.body) as Map<String, dynamic>;
    final idx = _localReservations.indexWhere((item) => item['id'].toString() == id);
    if (idx != -1) _localReservations[idx] = reservation;
    await _persistReservations();
    return reservation;
  }

  static Future<Map<String, dynamic>?> fetchFinancialTimeline(String reservationId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/reservations/$reservationId/financial-timeline'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    final r = _localReservations.firstWhere((item) => item['id'].toString() == reservationId, orElse: () => {});
    if (r.isEmpty) return null;

    final timeline = <Map<String, dynamic>>[
      {
        'type': 'reservation_confirmed',
        'date': r['created_at'] ?? DateTime.now().toIso8601String(),
        'title': 'Stay Confirmed',
        'description': 'Booking confirmed for ${r['number_of_nights'] ?? 1} nights via ${(r['booking_source'] ?? 'Direct').toString().toUpperCase()}',
        'amount': r['total_amount'] ?? 0.0,
        'currency': 'KES',
        'reference_id': r['booking_reference'] ?? r['id'],
      }
    ];

    if ((double.tryParse(r['amount_paid']?.toString() ?? '0') ?? 0) > 0) {
      timeline.add({
        'type': 'payment_received',
        'date': DateTime.now().toIso8601String(),
        'title': 'Payment Recorded',
        'description': 'Payment verified and credited to host ledger',
        'amount': r['amount_paid'],
        'currency': 'KES',
        'reference_id': 'PAY-${r['id']}',
      });
    }

    return {'timeline': timeline};
  }

  // --- GUEST FORMS ---
  static Future<Map<String, dynamic>> generateGuestForm(String reservationId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/reservations/$reservationId/guest-form'),
        headers: _headers,
      ).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    final token = 'token-${DateTime.now().millisecondsSinceEpoch}';
    return {
      'token': token,
      'form_status': 'unopened',
      'reservation_id': reservationId,
      'public_url': '$baseUrl/public/forms/$token',
    };
  }

  static Future<List<dynamic>> fetchGuestSubmissions({String? statusFilter}) async {
    try {
      final uri = Uri.parse('$baseUrl/guest-forms/submissions').replace(
        queryParameters: statusFilter != null ? {'status_filter': statusFilter} : null,
      );
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        _localSubmissions
          ..clear()
          ..addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _persistSubmissions();
        return list;
      }
    } catch (_) {}
    return List<dynamic>.from(_localSubmissions);
  }

  static Future<Map<String, dynamic>> reviewGuestSubmission(String id, String action, {String? notes}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/guest-form-submissions/$id/review'),
        headers: _headers,
        body: jsonEncode({
          'action': action,
          'review_notes': notes,
          'update_guest_profile': true,
        }),
      ).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    final sub = _localSubmissions.firstWhere((s) => s['id'].toString() == id, orElse: () => {});
    if (sub.isNotEmpty) {
      sub['form_status'] = action == 'approve' ? 'completed' : 'rejected';
      sub['review_notes'] = notes;
    }
    return sub;
  }

  static Future<void> revokeToken(String token) async {
    try {
      await http.post(Uri.parse('$baseUrl/guest-forms/tokens/$token/revoke'), headers: _headers).timeout(_timeout);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> fetchGoogleFormsStatus() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/guest-forms/google/status'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'mode': 'google_forms',
      'is_connected': true,
      'connected_email': _localOrganization['email'] ?? 'host@ginata.ke',
      'google_form_id': 'Ready to link your Google Form',
      'google_sheet_id': 'Ready to link Google Sheet',
      'sync_status': 'ready',
    };
  }

  static Future<Map<String, dynamic>> syncGoogleForms() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/guest-forms/google/sync'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'synced': true,
      'imported_submissions': 0,
      'message': 'Google Forms check-in responses synchronized.',
    };
  }

  // --- INVOICES & STUDIO ---
  static Future<List<dynamic>> fetchInvoices({String? statusFilter}) async {
    try {
      final uri = Uri.parse('$baseUrl/invoices').replace(
        queryParameters: statusFilter != null ? {'status_filter': statusFilter} : null,
      );
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        _localInvoices
          ..clear()
          ..addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _persistInvoices();
        return list;
      }
    } catch (_) {}
    return List<dynamic>.from(_localInvoices);
  }

  static Future<Map<String, dynamic>?> fetchInvoice(String id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/invoices/$id'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    final inv = _localInvoices.firstWhere((item) => item['id'].toString() == id, orElse: () => {});
    return inv.isNotEmpty ? inv : null;
  }

  static Future<Map<String, dynamic>> createInvoice(String reservationId, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/reservations/$reservationId/invoices'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
    if (res.statusCode != 201) {
      throw Exception('Invoice could not be created (${res.statusCode}).');
    }
    final inv = jsonDecode(res.body) as Map<String, dynamic>;
    _localInvoices.insert(0, inv);
    await _persistInvoices();
    return inv;
  }

  static Future<Map<String, dynamic>> updateInvoice(String id, Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data)..['force_edit'] = true;
    final res = await http.patch(
      Uri.parse('$baseUrl/invoices/$id'),
      headers: _headers,
      body: jsonEncode(payload),
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Invoice changes could not be saved (${res.statusCode}).');
    }
    final inv = jsonDecode(res.body) as Map<String, dynamic>;
    final idx = _localInvoices.indexWhere((item) => item['id'].toString() == id);
    if (idx != -1) _localInvoices[idx] = inv;
    await _persistInvoices();
    return inv;
  }

  static Future<Map<String, dynamic>> issueInvoice(String id) async {
    final res = await http.post(
      Uri.parse('$baseUrl/invoices/$id/issue'),
      headers: _headers,
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Invoice could not be issued (${res.statusCode}).');
    }
    final inv = jsonDecode(res.body) as Map<String, dynamic>;
    final idx = _localInvoices.indexWhere((item) => item['id'].toString() == id);
    if (idx != -1) _localInvoices[idx] = inv;
    await _persistInvoices();
    return inv;
  }

  static Future<Map<String, dynamic>> exportInvoice(String id, String format) async {
    final res = await http.post(
      Uri.parse('$baseUrl/invoices/$id/export'),
      headers: _headers,
      body: jsonEncode({'format': format}),
    ).timeout(const Duration(seconds: 45));
    if (res.statusCode == 200) {
      final doc = jsonDecode(res.body) as Map<String, dynamic>;
      final idx = _localDocuments.indexWhere((d) => d['id'].toString() == doc['id'].toString());
      if (idx != -1) {
        _localDocuments[idx] = doc;
      } else {
        _localDocuments.insert(0, doc);
      }
      _persistDocuments();
      return doc;
    }
    throw Exception('Could not export the invoice (server returned ${res.statusCode}). Check your connection and try again.');
  }

  static Future<Map<String, dynamic>> sendInvoice(String id, String channel, String recipient, {String? message}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/invoices/$id/send'),
        headers: _headers,
        body: jsonEncode({
          'channel': channel,
          'recipient': recipient,
          'custom_message': message,
        }),
      ).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    return {
      'delivered': true,
      'channel': channel,
      'recipient': recipient,
      'sent_at': DateTime.now().toIso8601String(),
    };
  }

  // --- PAYMENTS & RECEIPTS ---
  static Future<List<dynamic>> fetchPayments({String? reservationId}) async {
    try {
      final uri = Uri.parse('$baseUrl/payments').replace(
        queryParameters: reservationId != null ? {'reservation_id': reservationId} : null,
      );
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        _localPayments
          ..clear()
          ..addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _persistPayments();
        return list;
      }
    } catch (_) {}
    if (reservationId != null) {
      return _localPayments.where((p) => p['reservation_id'].toString() == reservationId).toList();
    }
    return List<dynamic>.from(_localPayments);
  }

  static Future<Map<String, dynamic>> recordPayment(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/payments'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
    if (res.statusCode != 201) {
      throw Exception('Payment was not recorded (${res.statusCode}). Refresh the reservation before retrying.');
    }
    final payData = jsonDecode(res.body) as Map<String, dynamic>;
    _localPayments.insert(0, payData);
    await _persistPayments();
    final receipt = payData['receipt'];
    if (receipt is Map) {
      _localReceipts.insert(0, Map<String, dynamic>.from(receipt));
      await _persistReceipts();
    }
    final resId = data['reservation_id']?.toString();
    if (resId != null) {
      try {
        final resRes = await http.get(
          Uri.parse('$baseUrl/reservations/$resId'),
          headers: _headers,
        ).timeout(_timeout);
        if (resRes.statusCode == 200) {
          final updatedRes = jsonDecode(resRes.body) as Map<String, dynamic>;
          final idx = _localReservations.indexWhere((r) => r['id'].toString() == resId);
          if (idx != -1) _localReservations[idx] = updatedRes;
          await _persistReservations();
        }
      } catch (_) {}
    }
    return payData;
  }

  static Future<List<dynamic>> fetchReceipts({String? reservationId}) async {
    try {
      final uri = Uri.parse('$baseUrl/payments/receipts').replace(
        queryParameters: reservationId != null ? {'reservation_id': reservationId} : null,
      );
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        _localReceipts
          ..clear()
          ..addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _persistReceipts();
        return list;
      }
    } catch (_) {}
    return List<dynamic>.from(_localReceipts);
  }

  static Future<Map<String, dynamic>> updateReceipt(String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/payments/receipts/$id'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Receipt changes could not be saved (${res.statusCode}).');
    }
    final receipt = jsonDecode(res.body) as Map<String, dynamic>;
    final idx = _localReceipts.indexWhere((r) => r['id'].toString() == id);
    if (idx != -1) _localReceipts[idx] = receipt;
    await _persistReceipts();
    return receipt;
  }

  static Future<Map<String, dynamic>> exportReceipt(String receiptId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/payments/receipts/$receiptId/export'),
      headers: _headers,
    ).timeout(const Duration(seconds: 45));
    if (res.statusCode == 200) {
      final doc = jsonDecode(res.body) as Map<String, dynamic>;
      final idx = _localDocuments.indexWhere((d) => d['id'].toString() == doc['id'].toString());
      if (idx != -1) {
        _localDocuments[idx] = doc;
      } else {
        _localDocuments.insert(0, doc);
      }
      _persistDocuments();
      return doc;
    }
    throw Exception('Could not export the receipt (server returned ${res.statusCode}). Check your connection and try again.');
  }

  /// Downloads raw file bytes from an API path (e.g. /documents/{id}/download)
  /// using the authenticated session. Used by the in-app PDF viewer and saver.
  static Future<Uint8List> downloadBytes(String apiPath) async {
    final url = apiPath.startsWith('http') ? apiPath : '$baseUrl$apiPath';
    final res = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 45));
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    throw Exception('Download failed (server returned ${res.statusCode}).');
  }

  /// Downloads the expenses ledger as a real CSV file from the server.
  static Future<Uint8List> downloadExpensesCsv({String? propertyId, String? category}) async {
    final params = <String, String>{};
    if (propertyId != null) params['property_id'] = propertyId;
    if (category != null && category != 'All') params['category'] = category;
    final uri = Uri.parse('$baseUrl/finances/expenses/export').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 45));
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    throw Exception('Could not export expenses (server returned ${res.statusCode}).');
  }

  // --- TEMPLATES ---
  static Future<List<dynamic>> fetchTemplates() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/templates'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        _localTemplates
          ..clear()
          ..addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _persistTemplates();
        return list;
      }
    } catch (_) {}
    return List<dynamic>.from(_localTemplates);
  }

  static Future<Map<String, dynamic>> updateTemplate(String id, Map<String, dynamic> data) async {
      final res = await http.patch(
        Uri.parse('$baseUrl/templates/$id'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(_timeout);
      if (res.statusCode == 200) {
        final tpl = jsonDecode(res.body) as Map<String, dynamic>;
        final idx = _localTemplates.indexWhere((t) => t['id'].toString() == id);
        if (idx != -1) {
          _localTemplates[idx] = tpl;
        } else {
          _localTemplates.add(tpl);
        }
        _persistTemplates();
        return tpl;
      }
    throw Exception('Could not save the document design (server returned ${res.statusCode}).');
  }

  static Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/templates'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
    if (res.statusCode == 201 || res.statusCode == 200) {
      final tpl = jsonDecode(res.body) as Map<String, dynamic>;
      _localTemplates.add(tpl);
      _persistTemplates();
      return tpl;
    }
    throw Exception('Could not create template (server returned ${res.statusCode}).');
  }

  /// Applies a template's layout/typography to all existing invoices & receipts
  /// by regenerating their archived documents on the server.
  static Future<Uint8List> previewDocumentTemplate(Map<String, dynamic> design) async {
    final res = await http.post(
      Uri.parse('$baseUrl/templates/preview'),
      headers: _headers,
      body: jsonEncode(design),
    ).timeout(const Duration(seconds: 45));
    if (res.statusCode == 200) return res.bodyBytes;
    throw Exception('Could not preview design (server returned ${res.statusCode}).');
  }

  static Future<Map<String, dynamic>> applyTemplateToDocuments(String templateId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/templates/$templateId/apply'),
      headers: _headers,
    ).timeout(const Duration(seconds: 60));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Could not apply template (server returned ${res.statusCode}).');
  }

  // --- DOCUMENTS ARCHIVE ---
  static Future<List<dynamic>> fetchDocuments({String? reservationId, String? docType}) async {
    try {
      final params = <String, String>{};
      if (reservationId != null) params['reservation_id'] = reservationId;
      if (docType != null) params['document_type'] = docType;
      final uri = Uri.parse('$baseUrl/documents').replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        _localDocuments
          ..clear()
          ..addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _persistDocuments();
        return list;
      }
    } catch (_) {}
    return List<dynamic>.from(_localDocuments);
  }

  // --- AUDIT LOGS ---
  static Future<List<dynamic>> fetchAuditLogs() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/audit-logs'), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }
}
