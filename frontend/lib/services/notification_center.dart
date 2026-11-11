import 'dart:async';
import 'package:flutter/widgets.dart';
import 'api_service.dart';

class HostNotification {
  final String id;
  final String kind;
  final String title;
  final String body;
  final String? entityType;
  final String? entityId;
  final bool isRead;
  final DateTime createdAt;

  const HostNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.entityType,
    required this.entityId,
    required this.isRead,
    required this.createdAt,
  });

  factory HostNotification.fromJson(Map<String, dynamic> json) => HostNotification(
        id: json['id'].toString(),
        kind: json['kind']?.toString() ?? 'general',
        title: json['title']?.toString() ?? 'Notification',
        body: json['body']?.toString() ?? '',
        entityType: json['entity_type']?.toString(),
        entityId: json['entity_id']?.toString(),
        isRead: json['read_at'] != null,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      );

  bool get isGuestUpdate => kind == 'guest_check_in' || kind == 'google_reconnect';
}

/// Polls the backend while the app is in the foreground and surfaces new host
/// notifications; [guestDataVersion] bumps whenever guest data may have changed.
class NotificationCenter extends ChangeNotifier with WidgetsBindingObserver {
  NotificationCenter._();
  static final NotificationCenter instance = NotificationCenter._();

  static const Duration pollInterval = Duration(seconds: 20);

  final StreamController<HostNotification> _incoming = StreamController<HostNotification>.broadcast();
  Stream<HostNotification> get incoming => _incoming.stream;

  Timer? _timer;
  bool _running = false;
  bool _polling = false;
  bool _available = true;
  String? _latestId;
  bool _primed = false;
  int unreadCount = 0;
  int guestDataVersion = 0;
  List<HostNotification> recent = const [];

  void start() {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    _schedule(immediate: true);
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    _latestId = null;
    _primed = false;
    unreadCount = 0;
    recent = const [];
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.resumed) {
      _schedule(immediate: true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _schedule({bool immediate = false}) {
    _timer?.cancel();
    if (!_running) return;
    _timer = Timer(immediate ? Duration.zero : pollInterval, () async {
      await refresh();
      _schedule();
    });
  }

  Future<void> refresh() async {
    if (_polling || !_available || ApiService.authToken == null) return;
    _polling = true;
    try {
      final summary = await ApiService.fetchNotificationSummary();
      final latestId = summary['latest_id']?.toString();
      final unread = (summary['unread_count'] as num?)?.toInt() ?? 0;
      final changed = latestId != _latestId;
      if (changed || unread != unreadCount || !_primed) {
        final list = (await ApiService.fetchNotifications(limit: 30))
            .map((e) => HostNotification.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (_primed && changed) {
          final knownIds = recent.map((n) => n.id).toSet();
          final fresh = list.where((n) => !n.isRead && !knownIds.contains(n.id)).toList().reversed;
          var guestChanged = false;
          for (final n in fresh) {
            _incoming.add(n);
            guestChanged = guestChanged || n.isGuestUpdate;
          }
          if (guestChanged) guestDataVersion++;
        }
        recent = list;
        _latestId = latestId;
        unreadCount = unread;
        _primed = true;
        notifyListeners();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) _available = false;
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  void markGuestDataChanged() {
    guestDataVersion++;
    notifyListeners();
  }

  Future<void> markRead(HostNotification n) async {
    if (n.isRead) return;
    try {
      await ApiService.markNotificationRead(n.id);
    } catch (_) {}
    recent = [
      for (final item in recent)
        item.id == n.id
            ? HostNotification(
                id: item.id,
                kind: item.kind,
                title: item.title,
                body: item.body,
                entityType: item.entityType,
                entityId: item.entityId,
                isRead: true,
                createdAt: item.createdAt,
              )
            : item,
    ];
    if (unreadCount > 0) unreadCount--;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead();
    } catch (_) {}
    unreadCount = 0;
    _primed = false;
    await refresh();
    notifyListeners();
  }
}
