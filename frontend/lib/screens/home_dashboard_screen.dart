import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../theme/ginata_theme.dart';

import '../services/api_service.dart';

import 'manual_booking_dialog.dart';

class HomeDashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const HomeDashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  List<dynamic> _reservations = [];

  Map<String, dynamic> _financialSummary = {};

  int _propertyCount = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    final res = await ApiService.fetchReservations();

    final finances = await ApiService.fetchFinancialSummary();

    final props = await ApiService.fetchProperties();

    if (mounted) {
      setState(() {
        _reservations = res;

        _financialSummary = finances;

        _propertyCount = props.length;

        _isLoading = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good morning';

    if (hour < 17) return 'Good afternoon';

    return 'Good evening';
  }

  void _openManualBookingModal() async {
    final result = await showDialog<bool>(
      context: context,

      barrierDismissible: false,

      builder: (_) => const ManualBookingDialog(),
    );

    if (result == true) {
      _loadDashboardData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation saved and calendar updated!'),

            backgroundColor: GinataColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,

        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',

              height: 32,

              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.villa,
                color: GinataColors.primary,
                size: 28,
              ),
            ),

            const SizedBox(width: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'GINATA',

                  style: TextStyle(
                    fontSize: 10,

                    letterSpacing: 2.0,

                    fontWeight: FontWeight.w700,

                    color: GinataColors.secondary,
                  ),
                ),

                Text(
                  'Home',

                  style: TextStyle(
                    fontSize: 18,

                    fontWeight: FontWeight.w700,

                    color: GinataColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: GinataColors.textPrimary,
                ),

                Positioned(
                  top: 2,

                  right: 2,

                  child: Container(
                    width: 8,

                    height: 8,

                    decoration: const BoxDecoration(
                      color: GinataColors.warningOchre,

                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),

            onPressed: () => widget.onNavigateTab(3), // go to inbox
          ),

          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),

            child: CircleAvatar(
              radius: 16,

              backgroundColor: GinataColors.primaryContainer,

              child: const Text(
                'H',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadDashboardData,

        color: GinataColors.primary,

        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),

          children: [
            // Live Sync Pill
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),

                decoration: BoxDecoration(
                  color: GinataColors.surfaceContainerHigh,

                  borderRadius: BorderRadius.circular(20),
                ),

                child: Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Container(
                      width: 6,

                      height: 6,

                      decoration: const BoxDecoration(
                        color: GinataColors.secondary,

                        shape: BoxShape.circle,
                      ),
                    ),

                    const SizedBox(width: 6),

                    const Text(
                      'LIVE SYNC · AIRBNB & BOOKING.COM',

                      style: TextStyle(
                        fontSize: 10,

                        fontWeight: FontWeight.w700,

                        letterSpacing: 1.0,

                        color: GinataColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Editorial Greeting
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              crossAxisAlignment: CrossAxisAlignment.end,

              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        DateFormat(
                          'EEEE, MMM d',
                        ).format(DateTime.now()).toUpperCase(),

                        style: const TextStyle(
                          fontSize: 11,

                          fontWeight: FontWeight.w700,

                          letterSpacing: 1.2,

                          color: GinataColors.secondary,
                        ),
                      ),

                      const SizedBox(height: 2),

                      FittedBox(
                        fit: BoxFit.scaleDown,

                        alignment: Alignment.centerLeft,

                        child: Text(
                          '${_getGreeting()}, Host',

                          style: const TextStyle(
                            fontSize: 22,

                            fontWeight: FontWeight.w700,

                            color: GinataColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),

                  decoration: BoxDecoration(
                    color: GinataColors.secondaryContainer.withValues(
                      alpha: 0.5,
                    ),

                    borderRadius: BorderRadius.circular(16),
                  ),

                  child: const Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      Icon(Icons.star, size: 14, color: GinataColors.primary),

                      SizedBox(width: 4),

                      Text(
                        'VERIFIED HOST',

                        style: TextStyle(
                          fontSize: 10,

                          fontWeight: FontWeight.bold,

                          color: GinataColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Horizontal Metric Cards
            SizedBox(
              height: 125,

              child: ListView(
                scrollDirection: Axis.horizontal,

                physics: const BouncingScrollPhysics(),

                children: [
                  _buildMetricCard(
                    title: 'NET HOST PROFIT',

                    value: GinataFormatters.formatKES(
                      _financialSummary['net_operating_profit'] ?? 0,
                    ),

                    subtext: 'After commissions & exp.',

                    icon: Icons.account_balance_wallet_outlined,

                    highlight: true,
                  ),

                  _buildMetricCard(
                    title: 'COLLECTED CASH',

                    value: GinataFormatters.formatKES(
                      _financialSummary['collected_revenue'] ?? 0,
                    ),

                    subtext:
                        'Gross: ${GinataFormatters.formatKES(_financialSummary['gross_revenue'] ?? 0)}',

                    icon: Icons.payments_outlined,

                    trendUp: true,
                  ),

                  _buildMetricCard(
                    title: 'ACTIVE RESERVATIONS',

                    value: '${_reservations.length} Stays',

                    subtext: 'Calendar synchronized',

                    icon: Icons.hotel_outlined,
                  ),

                  _buildMetricCard(
                    title: 'PORTFOLIO',

                    value: '$_propertyCount Estates',

                    subtext: 'Direct & iCal sync',

                    icon: Icons.domain_outlined,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Conflict Warning Banner
            InkWell(
              onTap: () => widget.onNavigateTab(3), // Navigate to Stays

              borderRadius: BorderRadius.circular(16),

              child: Container(
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: GinataColors.errorContainer.withValues(alpha: 0.5),

                  borderRadius: BorderRadius.circular(16),

                  border: Border.all(
                    color: GinataColors.alertTerracotta.withValues(alpha: 0.3),
                  ),
                ),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Container(
                      width: 32,

                      height: 32,

                      decoration: const BoxDecoration(
                        color: GinataColors.errorContainer,

                        shape: BoxShape.circle,
                      ),

                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: GinataColors.alertTerracotta,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: const [
                              Text(
                                'CALENDAR & CHANNEL STATUS',

                                style: TextStyle(
                                  fontSize: 11,

                                  fontWeight: FontWeight.w700,

                                  color: GinataColors.alertTerracotta,

                                  letterSpacing: 0.8,
                                ),
                              ),

                              Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: GinataColors.alertTerracotta,
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'All direct and channel bookings (Airbnb / Booking.com) are monitored in real time.',

                            style: TextStyle(
                              fontSize: 12,
                              color: GinataColors.textSecondary,
                            ),
                          ),

                          const SizedBox(height: 6),

                          const Text(
                            'View Reservations & Payouts',

                            style: TextStyle(
                              fontSize: 11,

                              fontWeight: FontWeight.bold,

                              color: GinataColors.primary,

                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Concierge Shortcuts
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'QUICK ACCESS SHORTCUTS',

                  style: TextStyle(
                    fontSize: 11,

                    fontWeight: FontWeight.w700,

                    letterSpacing: 1.2,

                    color: GinataColors.secondary,
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  height: 44,

                  child: ListView(
                    scrollDirection: Axis.horizontal,

                    physics: const BouncingScrollPhysics(),

                    children: [
                      _buildShortcutButton(
                        label: 'New Stay',

                        icon: Icons.add_circle_outline,

                        onTap: _openManualBookingModal,
                      ),

                      const SizedBox(width: 8),

                      _buildShortcutButton(
                        label: 'Estates & Inventory',

                        icon: Icons.domain_outlined,

                        onTap: () => widget.onNavigateTab(1),
                      ),

                      const SizedBox(width: 8),

                      _buildShortcutButton(
                        label: 'Calendar',

                        icon: Icons.calendar_month_outlined,

                        onTap: () => widget.onNavigateTab(2),
                      ),

                      const SizedBox(width: 8),

                      _buildShortcutButton(
                        label: 'Stays & Agents',

                        icon: Icons.hotel_outlined,

                        onTap: () => widget.onNavigateTab(3),
                      ),

                      const SizedBox(width: 8),

                      _buildShortcutButton(
                        label: 'Finances & Expenses',

                        icon: Icons.account_balance_wallet_outlined,

                        onTap: () => widget.onNavigateTab(4),
                      ),

                      const SizedBox(width: 8),

                      _buildShortcutButton(
                        label: 'Guest Messages',

                        icon: Icons.forum_outlined,

                        onTap: () => widget.onNavigateTab(5),
                      ),

                      const SizedBox(width: 8),

                      _buildShortcutButton(
                        label: 'Guest Forms',

                        icon: Icons.how_to_reg_outlined,

                        onTap: () => widget.onNavigateTab(6),
                      ),

                      const SizedBox(width: 8),

                      _buildShortcutButton(
                        label: 'Invoice Studio',

                        icon: Icons.receipt_long_outlined,

                        onTap: () => widget.onNavigateTab(7),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Turnover Pulse
            Container(
              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: GinataColors.surface,

                borderRadius: BorderRadius.circular(16),

                border: Border.all(color: const Color(0x14174A3F)),
              ),

              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),

                    decoration: BoxDecoration(
                      color: GinataColors.secondaryContainer.withValues(
                        alpha: 0.5,
                      ),

                      borderRadius: BorderRadius.circular(10),
                    ),

                    child: const Icon(
                      Icons.cleaning_services_outlined,
                      size: 20,
                      color: GinataColors.primary,
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          'House Readiness & Turnovers',

                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: GinataColors.primary,
                          ),
                        ),

                        SizedBox(height: 2),

                        Text(
                          'All residences ready for guest check-ins today',

                          style: TextStyle(
                            fontSize: 12,
                            color: GinataColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Today's Schedule Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      "Today's Schedule",

                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: GinataColors.primary,
                      ),
                    ),

                    Text(
                      'Arrivals, handoffs & departure rituals',

                      style: TextStyle(
                        fontSize: 12,
                        color: GinataColors.secondary,
                      ),
                    ),
                  ],
                ),

                TextButton(
                  onPressed: () =>
                      widget.onNavigateTab(2), // View all reservations

                  child: const Text(
                    'Full List',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Schedule Cards from live reservations
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: GinataColors.primary),
                ),
              )
            else
              ..._reservations.take(3).map((res) => _buildScheduleCard(res)),

            const SizedBox(height: 20),

            // Portfolio Spotlight Banner
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF003329), Color(0xFF174A3F), Color(0xFF0A241D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x1A003329), blurRadius: 16, offset: Offset(0, 4)),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(
                      Icons.villa_outlined,
                      size: 160,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _propertyCount == 0 ? 'GET STARTED' : 'PORTFOLIO SPOTLIGHT',
                                style: const TextStyle(
                                  color: GinataColors.secondary,
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _propertyCount == 0
                                    ? 'Add Your First Estate'
                                    : (_reservations.isNotEmpty && _reservations[0]['property'] != null
                                        ? _reservations[0]['property']['name']
                                        : 'Active Portfolio'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _propertyCount == 0
                                    ? 'Set up properties, calendar sync & direct billing'
                                    : '$_propertyCount ${_propertyCount == 1 ? "Property" : "Properties"} Managed · ${_reservations.length} Stays',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: GinataColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () => widget.onNavigateTab(1),
                          child: Text(
                            _propertyCount == 0 ? 'Add Estate' : 'View Estates',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,

    required String value,

    required String subtext,

    required IconData icon,

    bool trendUp = false,

    bool highlight = false,

    bool warning = false,
  }) {
    return Container(
      width: 175,

      margin: const EdgeInsets.only(right: 12),

      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

      decoration: BoxDecoration(
        color: highlight ? GinataColors.primary : GinataColors.surface,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(
          color: highlight ? GinataColors.primary : const Color(0x18174A3F),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),

            blurRadius: 8,

            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Expanded(
                child: Text(
                  title,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    fontSize: 10,

                    fontWeight: FontWeight.w700,

                    letterSpacing: 0.8,

                    color: highlight ? Colors.white70 : GinataColors.secondary,
                  ),
                ),
              ),

              const SizedBox(width: 4),

              Icon(
                icon,

                size: 16,

                color: highlight
                    ? Colors.white70
                    : (warning
                          ? GinataColors.warningOchre
                          : GinataColors.secondary),
              ),
            ],
          ),

          const SizedBox(height: 4),

          FittedBox(
            fit: BoxFit.scaleDown,

            alignment: Alignment.centerLeft,

            child: Text(
              value,

              style: TextStyle(
                fontSize: 18,

                fontWeight: FontWeight.bold,

                color: highlight
                    ? Colors.white
                    : (warning
                          ? GinataColors.warningOchre
                          : GinataColors.primary),
              ),
            ),
          ),

          const SizedBox(height: 2),

          Text(
            subtext,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(
              fontSize: 10,

              color: highlight ? Colors.white70 : GinataColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutButton({
    required String label,

    required IconData icon,

    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),

      child: Material(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        child: InkWell(
          onTap: onTap,

          borderRadius: BorderRadius.circular(20),

          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),

              border: Border.all(color: const Color(0x20174A3F)),
            ),

            child: Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                Icon(icon, color: GinataColors.primary, size: 16),

                const SizedBox(width: 8),

                Text(
                  label,

                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: GinataColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(dynamic res) {
    final guest = res['primary_guest'] ?? {};

    final guestName = '${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}'
        .trim();

    final prop = res['property'] ?? {};

    final propName = prop['name'] ?? 'Residence';

    final source = (res['booking_source'] ?? 'direct').toString().toUpperCase();

    final formStatus = res['guest_info_status'] ?? 'pending';

    final totalKes = GinataFormatters.formatKES(res['total_amount']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: GinataColors.surface,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: const Color(0x14174A3F)),
      ),

      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,

                      backgroundColor: GinataColors.surfaceContainer,

                      child: Text(
                        guestName.isNotEmpty ? guestName[0] : 'G',

                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: GinataColors.primary,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            guestName,

                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: GinataColors.primary,
                            ),

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,
                          ),

                          Text(
                            propName,

                            style: const TextStyle(
                              fontSize: 11,
                              color: GinataColors.textSecondary,
                            ),

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

                decoration: BoxDecoration(
                  color: source.contains('AIRBNB')
                      ? const Color(0xFFFF5A5F).withValues(alpha: 0.12)
                      : source.contains('BOOKING')
                      ? const Color(0xFF003580).withValues(alpha: 0.12)
                      : GinataColors.secondaryContainer,

                  borderRadius: BorderRadius.circular(12),
                ),

                child: Text(
                  source,

                  style: TextStyle(
                    fontSize: 9,

                    fontWeight: FontWeight.bold,

                    color: source.contains('AIRBNB')
                        ? const Color(0xFFD93B40)
                        : source.contains('BOOKING')
                        ? const Color(0xFF003580)
                        : GinataColors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

            decoration: BoxDecoration(
              color: GinataColors.surfaceSubdued,

              borderRadius: BorderRadius.circular(10),
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.login,
                      size: 16,
                      color: GinataColors.secondary,
                    ),

                    const SizedBox(width: 6),

                    Text(
                      'Check-in ${res['check_in_time'] ?? '15:00'}',

                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: GinataColors.primary,
                      ),
                    ),
                  ],
                ),

                Text(
                  totalKes,

                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: GinataColors.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Row(
                children: [
                  Icon(
                    formStatus == 'completed'
                        ? Icons.check_circle
                        : Icons.pending,

                    size: 14,

                    color: formStatus == 'completed'
                        ? GinataColors.secondary
                        : GinataColors.warningOchre,
                  ),

                  const SizedBox(width: 4),

                  Text(
                    formStatus == 'completed'
                        ? 'Form Verified'
                        : 'Registration Pending',

                    style: TextStyle(
                      fontSize: 11,

                      color: formStatus == 'completed'
                          ? GinataColors.secondary
                          : GinataColors.warningOchre,

                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),

                  minimumSize: const Size(0, 28),
                ),

                onPressed: () =>
                    widget.onNavigateTab(2), // open reservation details

                child: const Text('View Stay', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
