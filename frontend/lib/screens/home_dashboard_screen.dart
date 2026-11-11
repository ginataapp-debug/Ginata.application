import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/ginata_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
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
  bool? _isOnline;
  String _hostName = 'Host';
  String _hostInitial = 'H';

  @override
  void initState() {
    super.initState();
    _loadHostInfo();
    _loadDashboardData();
  }

  Future<void> _loadHostInfo() async {
    final name = await AuthService.getHostName();
    if (mounted && name.isNotEmpty) {
      setState(() {
        _hostName = name.split(' ').first;
        _hostInitial = _hostName[0].toUpperCase();
      });
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService.fetchReservations(),
      ApiService.fetchFinancialSummary(),
      ApiService.fetchProperties(),
      ApiService.checkServerConnection(),
    ]);
    if (mounted) {
      setState(() {
        _reservations = results[0] as List<dynamic>;
        _financialSummary = results[1] as Map<String, dynamic>;
        _propertyCount = (results[2] as List<dynamic>).length;
        _isOnline = (results[3] as ServerConnection).isOnline;
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
    final activeStays = _reservations.where((r) {
      final status = (r['reservation_status'] ?? '').toString().toLowerCase();
      return status != 'cancelled';
    }).toList();

    final pendingBal = double.tryParse(
        _financialSummary['pending_balance']?.toString() ?? '0') ?? 0.0;
    final gross = double.tryParse(
        _financialSummary['gross_revenue']?.toString() ?? '0') ?? 0.0;
    final collected = double.tryParse(
        _financialSummary['collected_revenue']?.toString() ?? '0') ?? 0.0;
    final netProfit = double.tryParse(
        _financialSummary['net_operating_profit']?.toString() ?? '0') ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'assets/images/brand_mark.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.villa, color: GinataColors.primary, size: 28,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GINATA',
                  style: TextStyle(
                    fontSize: 10, letterSpacing: 2.0,
                    fontWeight: FontWeight.w700, color: GinataColors.secondary,
                  ),
                ),
                Text(
                  'Home',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
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
                const Icon(Icons.notifications_outlined, color: GinataColors.textPrimary),
                if (activeStays.isNotEmpty)
                  Positioned(
                    top: 2, right: 2,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: GinataColors.warningOchre, shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => widget.onNavigateTab(9),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: GinataColors.primaryContainer,
              child: Text(
                _hostInitial,
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold,
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
            // Greeting
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 1.2, color: GinataColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_getGreeting()}, $_hostName',
                          style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700,
                            color: GinataColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final online = _isOnline == true;
                    final checking = _isOnline == null;
                    final color = checking
                        ? GinataColors.secondary
                        : online
                            ? GinataColors.successSage
                            : GinataColors.alertTerracotta;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(
                            checking ? 'Checking' : online ? 'Online' : 'Offline',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Revenue Overview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF003329), Color(0xFF174A3F), Color(0xFF0A241D)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF003329).withValues(alpha: 0.3),
                    blurRadius: 20, offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'REVENUE OVERVIEW',
                        style: TextStyle(
                          color: Colors.white60, fontSize: 10,
                          fontWeight: FontWeight.w700, letterSpacing: 1.2,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.onNavigateTab(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Details →',
                            style: TextStyle(
                              color: Colors.white70, fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      GinataFormatters.formatKES(netProfit),
                      style: const TextStyle(
                        color: Colors.white, fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Projected Net Host Profit',
                    style: TextStyle(
                      color: Colors.white60, fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Gross | Collected | Pending
                  Row(
                    children: [
                      _revenueMetric('Gross', GinataFormatters.formatKES(gross)),
                      Container(width: 1, height: 28, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                      _revenueMetric('Collected', GinataFormatters.formatKES(collected)),
                      Container(width: 1, height: 28, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                      _revenueMetric('Pending', GinataFormatters.formatKES(pendingBal)),
                    ],
                  ),
                  if (gross > 0) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (gross > 0) ? (collected / gross).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF79E0A8)),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Quick Stats Row
            Row(
              children: [
                Expanded(
                  child: _quickStatCard(
                    icon: Icons.hotel_outlined,
                    label: 'Active Stays',
                    value: '${activeStays.length}',
                    color: GinataColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickStatCard(
                    icon: Icons.domain_outlined,
                    label: 'Properties',
                    value: '$_propertyCount',
                    color: GinataColors.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickStatCard(
                    icon: Icons.pending_actions_outlined,
                    label: 'Pending',
                    value: GinataFormatters.formatKES(pendingBal),
                    color: pendingBal > 0 ? GinataColors.warningOchre : GinataColors.successSage,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Quick Actions
            const Text(
              'QUICK ACTIONS',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 1.2, color: GinataColors.secondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _actionCard(Icons.add_circle_outline, 'New Booking', _openManualBookingModal)),
                const SizedBox(width: 10),
                Expanded(child: _actionCard(Icons.track_changes_outlined, 'Stay Tracker', () => widget.onNavigateTab(9))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _actionCard(Icons.calendar_month_outlined, 'Calendar', () => widget.onNavigateTab(2))),
                const SizedBox(width: 10),
                Expanded(child: _actionCard(Icons.account_balance_wallet_outlined, 'Finances', () => widget.onNavigateTab(4))),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Stays
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Stays',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: GinataColors.primary,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab(3),
                  child: const Text('View All', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: GinataColors.primary),
                ),
              )
            else if (_reservations.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: GinataColors.surfaceSubdued,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 40, color: GinataColors.secondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'No stays yet',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: GinataColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Create your first booking to get started',
                      style: TextStyle(fontSize: 13, color: GinataColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openManualBookingModal,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Booking'),
                    ),
                  ],
                ),
              )
            else
              ..._reservations.take(3).map((res) => _buildScheduleCard(res)),

            const SizedBox(height: 20),

            // Portfolio Banner
            if (_propertyCount > 0 || _reservations.isEmpty)
              GestureDetector(
                onTap: () => widget.onNavigateTab(1),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF003329), Color(0xFF174A3F)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        right: -20, top: -20,
                        child: Icon(Icons.villa_outlined, size: 140,
                          color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _propertyCount == 0 ? 'GET STARTED' : 'YOUR PORTFOLIO',
                                    style: const TextStyle(
                                      color: Colors.white60, fontSize: 10,
                                      letterSpacing: 1.2, fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _propertyCount == 0
                                        ? 'Add Your First Estate'
                                        : '$_propertyCount ${_propertyCount == 1 ? "Property" : "Properties"} Managed',
                                    style: const TextStyle(
                                      color: Colors.white, fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _revenueMetric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _quickStatCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: GinataColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14174A3F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: GinataColors.textSecondary, fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _actionCard(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: GinataColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x14174A3F)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GinataColors.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: GinataColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: GinataColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: GinataColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(dynamic res) {
    final guest = res['primary_guest'] ?? {};
    final guestName = '${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}'.trim();
    final prop = res['property'] ?? {};
    final propName = prop['name'] ?? 'Residence';
    final source = (res['booking_source'] ?? 'direct').toString().toUpperCase();
    final totalKes = GinataFormatters.formatKES(res['total_amount']);
    final status = (res['reservation_status'] ?? 'confirmed').toString().toLowerCase();

    Color statusColor;
    String statusLabel;
    if (status == 'confirmed') {
      statusColor = GinataColors.successSage;
      statusLabel = 'Confirmed';
    } else if (status == 'checked_in') {
      statusColor = GinataColors.primary;
      statusLabel = 'Checked In';
    } else if (status == 'cancelled') {
      statusColor = GinataColors.alertTerracotta;
      statusLabel = 'Cancelled';
    } else {
      statusColor = GinataColors.warningOchre;
      statusLabel = status[0].toUpperCase() + status.substring(1);
    }

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
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: GinataColors.surfaceContainer,
                child: Text(
                  guestName.isNotEmpty ? guestName[0] : 'G',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: GinataColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guestName.isNotEmpty ? guestName : 'Guest',
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: GinataColors.primary,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      propName,
                      style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
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
                    fontSize: 9, fontWeight: FontWeight.bold,
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
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 7, color: statusColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: statusColor,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    totalKes,
                    style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: GinataColors.primary,
                    ),
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
                  const Icon(Icons.login, size: 14, color: GinataColors.secondary),
                  const SizedBox(width: 4),
                  Text(
                    '${res['check_in_date'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.logout, size: 14, color: GinataColors.secondary),
                  const SizedBox(width: 4),
                  Text(
                    '${res['check_out_date'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: const Size(0, 28),
                ),
                onPressed: () => widget.onNavigateTab(3),
                child: const Text('View', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
