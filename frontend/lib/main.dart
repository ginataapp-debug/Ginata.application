import 'dart:async';
import 'package:flutter/material.dart';
import 'theme/ginata_theme.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/notification_center.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/server_unavailable_screen.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/unified_calendar_screen.dart';
import 'screens/reservations_screen.dart';
import 'screens/guest_forms_screen.dart';
import 'screens/invoice_studio_screen.dart';
import 'screens/template_settings_screen.dart';
import 'screens/manual_booking_dialog.dart';
import 'screens/properties_screen.dart';
import 'screens/finances_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/tracker_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const GinataApp());
}

class GinataApp extends StatelessWidget {
  const GinataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ginata',
      debugShowCheckedModeBanner: false,
      theme: buildGinataTheme(),
      home: const AppEntryPoint(),
    );
  }
}

/// Determines the launch flow: splash → login (if needed) → main app.
class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool _splashComplete = false;
  SessionValidation? _sessionValidation;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService.isLoggedIn();
    final validation = loggedIn
        ? await AuthService.validateSession()
        : SessionValidation.invalid;
    if (mounted) {
      setState(() => _sessionValidation = validation);
    }
  }

  void _onSplashComplete() {
    if (mounted) setState(() => _splashComplete = true);
  }

  void _onLoginSuccess() {
    if (mounted) {
      setState(() {
        _sessionValidation = SessionValidation.valid;
        _splashComplete = true;
      });
    }
  }

  Future<void> _signOut() async {
    await AuthService.logout();
    if (mounted) setState(() => _sessionValidation = SessionValidation.invalid);
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashComplete || _sessionValidation == null) {
      return SplashScreen(onComplete: _onSplashComplete);
    }

    return switch (_sessionValidation!) {
      SessionValidation.valid => const MainNavigationShell(),
      SessionValidation.invalid => LoginScreen(onLoginSuccess: _onLoginSuccess),
      SessionValidation.unavailable => ServerUnavailableScreen(
          onRetry: _checkAuth,
          onSignOut: _signOut,
        ),
    };
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  StreamSubscription<HostNotification>? _notificationSub;

  @override
  void initState() {
    super.initState();
    final center = NotificationCenter.instance;
    _notificationSub = center.incoming.listen(_onIncomingNotification);
    center.addListener(_onCenterChanged);
    center.start();
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    NotificationCenter.instance.removeListener(_onCenterChanged);
    NotificationCenter.instance.stop();
    super.dispose();
  }

  void _onCenterChanged() {
    if (mounted) setState(() {});
  }

  void _onIncomingNotification(HostNotification n) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        backgroundColor: GinataColors.primary,
        content: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (n.body.isNotEmpty)
                Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: GinataColors.brassGold,
          onPressed: () => _openNotification(n),
        ),
      ),
    );
  }

  void _openNotification(HostNotification n) {
    NotificationCenter.instance.markRead(n);
    final type = n.entityType;
    if (type == 'google_form_response' || type == 'guest_form_submission') {
      GuestFormsScreen.focusRequest.value = GuestRecordFocus(type!, n.entityId ?? '');
      setState(() => _currentIndex = 6);
    } else if (n.isGuestUpdate || type == 'guest_form') {
      setState(() => _currentIndex = 6);
    }
  }

  void _showNotifications() {
    final center = NotificationCenter.instance;
    center.refresh();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: ListenableBuilder(
            listenable: center,
            builder: (ctx, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: GinataColors.primary),
                        ),
                      ),
                      if (center.unreadCount > 0)
                        TextButton(onPressed: center.markAllRead, child: const Text('Mark all read')),
                    ],
                  ),
                ),
                if (center.recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Text(
                      'No notifications yet. New guest check-ins will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: GinataColors.textSecondary),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: center.recent.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final n = center.recent[i];
                        return ListTile(
                          leading: Icon(
                            n.kind == 'google_reconnect' ? Icons.link_off : Icons.how_to_reg_outlined,
                            color: n.isRead ? GinataColors.textMuted : GinataColors.primary,
                          ),
                          title: Text(
                            n.title,
                            style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${n.body}${n.body.isEmpty ? '' : '\n'}${_relativeTime(n.createdAt)}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          isThreeLine: n.body.isNotEmpty,
                          trailing: n.isRead
                              ? null
                              : const Icon(Icons.circle, size: 10, color: GinataColors.brassGold, semanticLabel: 'Unread'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _openNotification(n);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  void _openNewBookingModal() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ManualBookingDialog(),
    );
    if (created == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reservation created and property calendar updated!'),
          backgroundColor: GinataColors.primary,
        ),
      );
    }
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Image.asset(
                    'assets/images/brand_mark.png',
                    height: 22,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.villa, color: GinataColors.primary, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'More Tools & Sections',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GinataColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: GinataColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Badge(
                          isLabelVisible: NotificationCenter.instance.unreadCount > 0,
                          label: Text('${NotificationCenter.instance.unreadCount}'),
                          child: const Icon(Icons.notifications_outlined, color: GinataColors.primary, size: 20),
                        ),
                      ),
                      title: const Text(
                        'Notifications',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GinataColors.textPrimary),
                      ),
                      subtitle: const Text('New guest check-ins and sync alerts', style: TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                      trailing: const Icon(Icons.chevron_right, size: 20, color: GinataColors.secondary),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showNotifications();
                      },
                    ),
                    const SizedBox(height: 8),
                    _moreMenuItem(Icons.track_changes_outlined, 'Stay Tracker', 'Arrivals, departures, guests in-house & balances', 9, ctx),
                    _moreMenuItem(Icons.account_balance_wallet_outlined, 'Finances & Expenses', 'Net profit, house expenses & cash collected', 4, ctx),
                    _moreMenuItem(Icons.text_snippet_outlined, 'Message Templates', 'Pre-built guest messages for Airbnb & more', 5, ctx),
                    _moreMenuItem(Icons.how_to_reg_outlined, 'Guest Check-ins', 'Google Forms sync & guest check-in review', 6, ctx),
                    _moreMenuItem(Icons.receipt_long_outlined, 'Invoice Studio', 'Generate guest receipts, invoices & vouchers', 7, ctx),
                    _moreMenuItem(Icons.person_outline, 'Host Profile & Settings', 'Edit host info, contacts, payout instructions', 8, ctx),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: GinataColors.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout, color: GinataColors.alertTerracotta, size: 20),
                      ),
                      title: const Text(
                        'Sign Out',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GinataColors.alertTerracotta),
                      ),
                      subtitle: const Text('End your session', style: TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await AuthService.logout();
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const AppEntryPoint()),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreMenuItem(IconData icon, String title, String subtitle, int tabIndex, BuildContext ctx) {
    final isSelected = _currentIndex == tabIndex;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? GinataColors.secondaryContainer.withValues(alpha: 0.3) : GinataColors.surfaceSubdued,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? GinataColors.primary : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? GinataColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: isSelected ? Colors.white : GinataColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isSelected ? GinataColors.primary : GinataColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20, color: GinataColors.secondary),
        onTap: () {
          Navigator.pop(ctx);
          setState(() => _currentIndex = tabIndex);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeDashboardScreen(onNavigateTab: _onTabSelected),
      PropertiesScreen(onNewBooking: _openNewBookingModal),
      UnifiedCalendarScreen(onNewBooking: _openNewBookingModal),
      ReservationsScreen(onOpenNewBooking: _openNewBookingModal),
      const FinancesScreen(),
      const MessagesScreen(),
      const GuestFormsScreen(),
      const InvoiceStudioScreen(),
      const TemplateSettingsScreen(),
      TrackerScreen(onOpenStays: () => _onTabSelected(3)),
    ];

    final isMoreSelected = _currentIndex >= 4;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Home'),
                _buildNavItem(1, Icons.domain_outlined, Icons.domain, 'Estates'),
                _buildNavItem(2, Icons.calendar_month_outlined, Icons.calendar_month, 'Calendar'),
                _buildNavItem(3, Icons.hotel_outlined, Icons.hotel, 'Stays'),
                _buildMoreNavItem(isMoreSelected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTabSelected(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? filledIcon : outlineIcon,
              size: 22,
              color: isSelected ? GinataColors.primary : GinataColors.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? GinataColors.primary : GinataColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreNavItem(bool isSelected) {
    String label = 'More';
    if (_currentIndex == 4) label = 'Finances';
    if (_currentIndex == 5) label = 'Templates';
    if (_currentIndex == 6) label = 'Check-ins';
    if (_currentIndex == 7) label = 'Studio';
    if (_currentIndex == 8) label = 'Profile';
    if (_currentIndex == 9) label = 'Tracker';
    final unread = NotificationCenter.instance.unreadCount;

    return Expanded(
      child: InkWell(
        onTap: _showMoreMenu,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 9 ? '9+' : '$unread'),
              child: Icon(
                isSelected ? Icons.grid_view_rounded : Icons.grid_view_outlined,
                size: 22,
                color: isSelected ? GinataColors.primary : GinataColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? GinataColors.primary : GinataColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
