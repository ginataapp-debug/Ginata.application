import 'package:flutter/material.dart';
import 'theme/ginata_theme.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
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
  bool _showSplash = true;
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (mounted) {
      setState(() => _isLoggedIn = loggedIn);
    }
  }

  void _onSplashComplete() {
    if (mounted) {
      setState(() => _showSplash = false);
    }
  }

  void _onLoginSuccess() {
    if (mounted) {
      setState(() {
        _isLoggedIn = true;
        _showSplash = true; // Show splash animation after login
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still loading auth state
    if (_isLoggedIn == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F8FA),
        body: Center(
          child: CircularProgressIndicator(color: GinataColors.primary),
        ),
      );
    }

    // Not logged in → show login
    if (_isLoggedIn == false) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }

    // Logged in but showing splash
    if (_showSplash) {
      return SplashScreen(onComplete: _onSplashComplete);
    }

    // Logged in, splash done → main app
    return const MainNavigationShell();
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

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
                    'assets/images/logo.png',
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
                    _moreMenuItem(Icons.account_balance_wallet_outlined, 'Finances & Expenses', 'Net profit, house expenses & cash collected', 4, ctx),
                    _moreMenuItem(Icons.forum_outlined, 'Guest Messages', 'Multi-channel guest inbox & direct messaging', 5, ctx),
                    _moreMenuItem(Icons.how_to_reg_outlined, 'Guest Registration Forms', 'Google Forms sync & guest agreements', 6, ctx),
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
    if (_currentIndex == 5) label = 'Messages';
    if (_currentIndex == 6) label = 'Forms';
    if (_currentIndex == 7) label = 'Studio';
    if (_currentIndex == 8) label = 'Profile';

    return Expanded(
      child: InkWell(
        onTap: _showMoreMenu,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.grid_view_rounded : Icons.grid_view_outlined,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
