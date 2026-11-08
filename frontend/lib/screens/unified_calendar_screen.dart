import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../theme/ginata_theme.dart';

import '../services/api_service.dart';

import 'manual_booking_dialog.dart';

import 'payment_modal.dart';

class UnifiedCalendarScreen extends StatefulWidget {
  final VoidCallback onNewBooking;

  const UnifiedCalendarScreen({super.key, required this.onNewBooking});

  @override
  State<UnifiedCalendarScreen> createState() => _UnifiedCalendarScreenState();
}

class _UnifiedCalendarScreenState extends State<UnifiedCalendarScreen> {
  List<dynamic> _properties = [];

  List<dynamic> _reservations = [];

  bool _isLoading = true;

  String _activeView = 'Timeline'; // 'Timeline', 'Week', 'Month'

  String _selectedChannel = 'all';

  String _selectedPropertyId = 'all';

  DateTime _anchorDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    setState(() => _isLoading = true);

    final props = await ApiService.fetchProperties();

    final res = await ApiService.fetchReservations();

    if (!mounted) return;

    setState(() {
      _properties = props;

      _reservations = res;

      _isLoading = false;
    });
  }

  List<dynamic> get _filteredReservations {
    return _reservations.where((r) {
      if (r['reservation_status'] == 'cancelled') return false;

      if (_selectedChannel != 'all' &&
          r['booking_source'] != _selectedChannel) {
        return false;
      }

      if (_selectedPropertyId != 'all' &&
          r['property_id'].toString() != _selectedPropertyId) {
        return false;
      }

      return true;
    }).toList();
  }

  List<dynamic> get _filteredProperties {
    if (_selectedPropertyId == 'all') return _properties;

    return _properties
        .where((p) => p['id'].toString() == _selectedPropertyId)
        .toList();
  }

  bool _isDateInRange(DateTime d, String checkInStr, String checkOutStr) {
    try {
      final cin = DateTime.parse(checkInStr);

      final cout = DateTime.parse(checkOutStr);

      final checkDay = DateTime(d.year, d.month, d.day);

      final startDay = DateTime(cin.year, cin.month, cin.day);

      final endDay = DateTime(cout.year, cout.month, cout.day);

      return !checkDay.isBefore(startDay) && checkDay.isBefore(endDay);
    } catch (_) {
      return false;
    }
  }

  dynamic _findReservationForDate(String propertyId, DateTime day) {
    for (final r in _filteredReservations) {
      if (r['property_id'].toString() == propertyId) {
        if (_isDateInRange(day, r['check_in_date'], r['check_out_date'])) {
          return r;
        }
      }
    }

    return null;
  }

  Color _getChannelColor(String source) {
    switch (source.toLowerCase()) {
      case 'airbnb':
        return const Color(0xFFFF5A5F);

      case 'booking_com':
        return const Color(0xFF003580);

      case 'phone':
        return const Color(0xFFD97706);

      case 'walk_in':
        return const Color(0xFF7C3AED);

      case 'direct':
      default:
        return GinataColors.primary;
    }
  }

  String _formatChannelLabel(String source) {
    switch (source.toLowerCase()) {
      case 'airbnb':
        return 'Airbnb';

      case 'booking_com':
        return 'Booking.com';

      case 'phone':
        return 'Phone';

      case 'walk_in':
        return 'Walk-in';

      case 'direct':
      default:
        return 'Direct';
    }
  }

  void _openBookingForPropertyDate(String propertyId, DateTime date) async {
    final created = await showDialog<bool>(
      context: context,

      barrierDismissible: false,

      builder: (_) => ManualBookingDialog(
        initialData: {
          'property_id': propertyId,

          'check_in_date': DateFormat('yyyy-MM-dd').format(date),

          'check_out_date': DateFormat(
            'yyyy-MM-dd',
          ).format(date.add(const Duration(days: 3))),
        },
      ),
    );

    if (created == true) {
      _loadCalendar();
    }
  }

  void _showBookingInspector(dynamic res) {
    final guest = res['primary_guest'] ?? {};

    final guestName = '${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}'
        .trim();

    final prop = res['property'] ?? {};

    final propName = prop['name'] ?? 'Residence';

    final totalKes = GinataFormatters.formatKES(res['total_amount']);

    final balanceKes = GinataFormatters.formatKES(res['balance_due']);

    final formStatus = res['guest_info_status'] ?? 'pending';

    final isConflict = res['has_conflict'] == true;

    final source = res['booking_source'] ?? 'direct';

    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: GinataColors.surface,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),

      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Center(
              child: Container(
                width: 44,

                height: 4,

                decoration: BoxDecoration(
                  color: GinataColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        guestName.isNotEmpty ? guestName : 'Valued Guest',

                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: GinataColors.primary,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        '$propName · ${res['check_in_date']} to ${res['check_out_date']} (${res['number_of_nights'] ?? 1} nights)',

                        style: const TextStyle(
                          fontSize: 12,
                          color: GinataColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),

                  decoration: BoxDecoration(
                    color: _getChannelColor(source).withValues(alpha: 0.15),

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(
                      color: _getChannelColor(source).withValues(alpha: 0.4),
                    ),
                  ),

                  child: Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      Container(
                        width: 7,

                        height: 7,

                        decoration: BoxDecoration(
                          color: _getChannelColor(source),

                          shape: BoxShape.circle,
                        ),
                      ),

                      const SizedBox(width: 6),

                      Text(
                        _formatChannelLabel(source).toUpperCase(),

                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getChannelColor(source),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (isConflict) ...[
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: GinataColors.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),

                child: Row(
                  children: [
                    const Icon(
                      Icons.warning,
                      size: 18,
                      color: GinataColors.alertTerracotta,
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        'Overridden conflict: ${res['conflict_override_reason'] ?? 'Host override approved'}',

                        style: const TextStyle(
                          fontSize: 12,
                          color: GinataColors.alertTerracotta,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: GinataColors.surfaceSubdued,
                borderRadius: BorderRadius.circular(14),
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'TOTAL BILLED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: GinataColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        totalKes,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: GinataColors.primary,
                        ),
                      ),
                    ],
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'BALANCE DUE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: GinataColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        balanceKes,

                        style: TextStyle(
                          fontSize: 14,

                          color:
                              (double.tryParse(
                                        res['balance_due']?.toString() ?? '0',
                                      ) ??
                                      0) >
                                  0
                              ? GinataColors.warningOchre
                              : GinataColors.secondary,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'GUEST FORM',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: GinataColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        formStatus == 'completed' ? '✓ Verified' : 'Pending',

                        style: TextStyle(
                          fontSize: 13,

                          fontWeight: FontWeight.bold,

                          color: formStatus == 'completed'
                              ? GinataColors.secondary
                              : GinataColors.warningOchre,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GinataColors.primary,

                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),

                    icon: const Icon(Icons.edit, size: 15),

                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Edit Booking',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    onPressed: () async {
                      Navigator.pop(sheetCtx);

                      final updated = await showDialog<bool>(
                        context: context,

                        barrierDismissible: false,

                        builder: (_) => ManualBookingDialog(initialData: res),
                      );

                      if (updated == true) _loadCalendar();
                    },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),

                    icon: const Icon(Icons.payments_outlined, size: 15),

                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Payment',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    onPressed: () async {
                      Navigator.pop(sheetCtx);

                      final paid = await showDialog<bool>(
                        context: context,

                        builder: (_) => PaymentModal(
                          reservationId: res['id'].toString(),

                          suggestedAmount:
                              double.tryParse(
                                res['balance_due']?.toString() ?? '0',
                              ) ??
                              0,
                        ),
                      );

                      if (paid == true) _loadCalendar();
                    },
                  ),
                ),

                const SizedBox(width: 10),

                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: GinataColors.alertTerracotta,
                  ),

                  tooltip: 'Cancel Stay',

                  onPressed: () async {
                    Navigator.pop(sheetCtx);

                    final confirm = await showDialog<bool>(
                      context: context,

                      builder: (_) => AlertDialog(
                        title: const Text('Cancel Reservation?'),

                        content: Text(
                          'Are you sure you want to cancel the confirmed stay for $guestName?',
                        ),

                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Keep Stay'),
                          ),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GinataColors.alertTerracotta,
                            ),

                            onPressed: () => Navigator.pop(context, true),

                            child: const Text('Cancel Reservation'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ApiService.cancelReservation(
                        res['id'].toString(),
                        reason: 'Cancelled from calendar',
                      );

                      _loadCalendar();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calendar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined, color: GinataColors.primary),
            tooltip: 'Jump to today',
            onPressed: () => setState(() => _anchorDate = DateTime.now()),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: GinataColors.primary),
            tooltip: 'Reload calendar',
            onPressed: _loadCalendar,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(
                Icons.add_circle,
                color: GinataColors.primary,
                size: 28,
              ),
              tooltip: 'New Booking',
              onPressed: widget.onNewBooking,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GinataColors.primary),
            )
          : Column(
              children: [
                // Top control bar with View switcher, Property filter, and Channel badges
                Container(
                  color: GinataColors.surface,

                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),

                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: [
                          // View Switcher (Timeline, Week, Month)
                          Container(
                            padding: const EdgeInsets.all(3),

                            decoration: BoxDecoration(
                              color: GinataColors.surfaceContainerHigh,

                              borderRadius: BorderRadius.circular(16),
                            ),

                            child: Row(
                              children: ['Timeline', 'Week', 'Month'].map((v) {
                                final isSel = _activeView == v;

                                return InkWell(
                                  onTap: () => setState(() => _activeView = v),

                                  borderRadius: BorderRadius.circular(12),

                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),

                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? GinataColors.surface
                                          : Colors.transparent,

                                      borderRadius: BorderRadius.circular(12),

                                      boxShadow: isSel
                                          ? const [
                                              BoxShadow(
                                                color: Color(0x10000000),
                                                blurRadius: 4,
                                                offset: Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),

                                    child: Text(
                                      v,

                                      style: TextStyle(
                                        fontSize: 12,

                                        fontWeight: isSel
                                            ? FontWeight.bold
                                            : FontWeight.w500,

                                        color: isSel
                                            ? GinataColors.primary
                                            : GinataColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          // Property filter dropdown
                          Expanded(
                            child: Container(
                              height: 38,

                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),

                              decoration: BoxDecoration(
                                color: GinataColors.surfaceSubdued,

                                borderRadius: BorderRadius.circular(10),

                                border: Border.all(
                                  color: GinataColors.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),

                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedPropertyId,

                                  isDense: true,

                                  isExpanded: true,

                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    size: 20,
                                  ),

                                  items: [
                                    const DropdownMenuItem(
                                      value: 'all',
                                      child: Text(
                                        'All Properties',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    ..._properties.map(
                                      (p) => DropdownMenuItem(
                                        value: p['id'].toString(),

                                        child: Text(
                                          p['name'] ?? '',
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],

                                  onChanged: (val) => setState(
                                    () => _selectedPropertyId = val ?? 'all',
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Channel Filter Dropdown
                          Expanded(
                            child: Container(
                              height: 38,

                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),

                              decoration: BoxDecoration(
                                color: GinataColors.surfaceSubdued,

                                borderRadius: BorderRadius.circular(10),

                                border: Border.all(
                                  color: GinataColors.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),

                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedChannel,

                                  isDense: true,

                                  isExpanded: true,

                                  icon: const Icon(Icons.filter_list, size: 16),

                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text(
                                        'All Channels',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    DropdownMenuItem(
                                      value: 'direct',
                                      child: Text(
                                        'Direct (KES)',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),

                                    DropdownMenuItem(
                                      value: 'airbnb',
                                      child: Text(
                                        'Airbnb',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),

                                    DropdownMenuItem(
                                      value: 'booking_com',
                                      child: Text(
                                        'Booking.com',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),

                                    DropdownMenuItem(
                                      value: 'walk_in',
                                      child: Text(
                                        'Walk-in',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),

                                    DropdownMenuItem(
                                      value: 'phone',
                                      child: Text(
                                        'Phone',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],

                                  onChanged: (v) => setState(
                                    () => _selectedChannel = v ?? 'all',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Channel Legend and Date Navigation Bar
                Container(
                  color: GinataColors.surface,

                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),

                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: [
                          // Date Navigation
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, size: 20),

                                constraints: const BoxConstraints(),

                                padding: const EdgeInsets.all(4),

                                onPressed: () => setState(() {
                                  if (_activeView == 'Month') {
                                    _anchorDate = DateTime(
                                      _anchorDate.year,
                                      _anchorDate.month - 1,
                                      1,
                                    );
                                  } else {
                                    _anchorDate = _anchorDate.subtract(
                                      const Duration(days: 7),
                                    );
                                  }
                                }),
                              ),

                              const SizedBox(width: 4),

                              Text(
                                DateFormat('MMMM yyyy').format(_anchorDate),

                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: GinataColors.primary,
                                ),
                              ),

                              const SizedBox(width: 4),

                              IconButton(
                                icon: const Icon(Icons.chevron_right, size: 20),

                                constraints: const BoxConstraints(),

                                padding: const EdgeInsets.all(4),

                                onPressed: () => setState(() {
                                  if (_activeView == 'Month') {
                                    _anchorDate = DateTime(
                                      _anchorDate.year,
                                      _anchorDate.month + 1,
                                      1,
                                    );
                                  } else {
                                    _anchorDate = _anchorDate.add(
                                      const Duration(days: 7),
                                    );
                                  }
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,

                        physics: const BouncingScrollPhysics(),

                        child: Row(
                          children: [
                            _buildLegendPill('Direct', GinataColors.primary),

                            const SizedBox(width: 10),

                            _buildLegendPill('Airbnb', const Color(0xFFFF5A5F)),

                            const SizedBox(width: 10),

                            _buildLegendPill(
                              'Booking.com',
                              const Color(0xFF003580),
                            ),

                            const SizedBox(width: 10),

                            _buildLegendPill(
                              'Walk-in/Phone',
                              const Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 4),
                    ],
                  ),
                ),

                const Divider(
                  height: 1,
                  color: GinataColors.surfaceContainerHigh,
                ),

                // Main Calendar Views
                Expanded(
                  child: _activeView == 'Month'
                      ? _buildMonthView()
                      : _buildTimelineView(),
                ),
              ],
            ),
    );
  }

  Widget _buildLegendPill(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,

      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 4),

        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: GinataColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineView() {
    final startDay = _activeView == 'Week'
        ? _anchorDate.subtract(Duration(days: _anchorDate.weekday - 1))
        : _anchorDate.subtract(const Duration(days: 2));

    final days = List.generate(7, (i) => startDay.add(Duration(days: i)));

    return Column(
      children: [
        // Days of week header row
        Container(
          color: GinataColors.surface,

          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),

          child: Row(
            children: [
              const SizedBox(
                width: 90,

                child: Text(
                  'ESTATE',

                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: GinataColors.secondary,
                  ),
                ),
              ),

              Expanded(
                child: Row(
                  children: days.map((d) {
                    final isToday =
                        d.day == DateTime.now().day &&
                        d.month == DateTime.now().month &&
                        d.year == DateTime.now().year;

                    return Expanded(
                      child: Column(
                        children: [
                          Text(
                            DateFormat('E').format(d).toUpperCase(),

                            style: TextStyle(
                              fontSize: 10,

                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.w600,

                              color: isToday
                                  ? GinataColors.primary
                                  : GinataColors.textSecondary,
                            ),
                          ),

                          const SizedBox(height: 2),

                          Container(
                            width: 28,

                            height: 28,

                            decoration: BoxDecoration(
                              color: isToday
                                  ? GinataColors.primary
                                  : Colors.transparent,

                              shape: BoxShape.circle,
                            ),

                            alignment: Alignment.center,

                            child: Text(
                              d.day.toString(),

                              style: TextStyle(
                                fontSize: 12,

                                fontWeight: FontWeight.bold,

                                color: isToday
                                    ? Colors.white
                                    : GinataColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: GinataColors.surfaceContainerHigh),

        // Property Timeline List
        Expanded(
          child: _filteredProperties.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.domain_disabled_outlined, size: 48, color: GinataColors.outlineVariant),
                        const SizedBox(height: 12),
                        const Text(
                          'No Estates in Calendar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GinataColors.primary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add a property in Estates to view 7-day timeline and room availability.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: GinataColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),

                  itemCount: _filteredProperties.length,

                  separatorBuilder: (_, _) => const SizedBox(height: 12),

                  itemBuilder: (ctx, idx) {
                    final prop = _filteredProperties[idx];

                    final propId = prop['id'].toString();

                    return Container(
                      padding: const EdgeInsets.all(14),

                      decoration: BoxDecoration(
                        color: GinataColors.surface,

                        borderRadius: BorderRadius.circular(16),

                        border: Border.all(color: const Color(0x18174A3F)),

                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x060D2620),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: GinataColors.secondary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),

                                    const SizedBox(width: 6),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                        children: [
                                          Text(
                                            prop['name'] ?? '',

                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: GinataColors.primary,
                                            ),

                                            maxLines: 1,

                                            overflow: TextOverflow.ellipsis,
                                          ),

                                          Text(
                                            '${prop['city'] ?? ''} · ${GinataFormatters.formatKES(prop['default_nightly_rate'])}/night',

                                            style: const TextStyle(
                                              fontSize: 10,
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

                              InkWell(
                                onTap: () => _openBookingForPropertyDate(
                                  propId,
                                  DateTime.now(),
                                ),

                                borderRadius: BorderRadius.circular(8),

                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),

                                  decoration: BoxDecoration(
                                    color: GinataColors.secondaryContainer
                                        .withValues(alpha: 0.4),

                                    borderRadius: BorderRadius.circular(8),
                                  ),

                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,

                                    children: [
                                      Icon(
                                        Icons.add,
                                        size: 12,
                                        color: GinataColors.primary,
                                      ),

                                      SizedBox(width: 3),

                                      Text(
                                        'Book',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: GinataColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Day Slots Row
                          Row(
                            children: [
                              const SizedBox(
                                width: 90,

                                child: Text(
                                  '7-Day:',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: GinataColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              Expanded(
                                child: Row(
                                  children: days.map((d) {
                                    final booking = _findReservationForDate(
                                      propId,
                                      d,
                                    );

                                    if (booking != null) {
                                      final isCheckIn =
                                          booking['check_in_date'] ==
                                          DateFormat('yyyy-MM-dd').format(d);

                                      final guest =
                                          booking['primary_guest'] ?? {};

                                      final guestName =
                                          '${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}'
                                              .trim();

                                      final isConflict =
                                          booking['has_conflict'] == true;

                                      final source =
                                          booking['booking_source'] ?? 'direct';

                                      final channelColor = _getChannelColor(
                                        source,
                                      );

                                      return Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2.5,
                                          ),

                                          child: InkWell(
                                            onTap: () =>
                                                _showBookingInspector(booking),

                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),

                                            child: Container(
                                              height: 52,

                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 4,
                                                  ),

                                              decoration: BoxDecoration(
                                                color: isConflict
                                                    ? GinataColors
                                                          .errorContainer
                                                    : channelColor.withValues(
                                                        alpha: 0.9,
                                                      ),

                                                borderRadius:
                                                    BorderRadius.circular(10),

                                                border: Border.all(
                                                  color: isConflict
                                                      ? GinataColors
                                                            .alertTerracotta
                                                      : channelColor,

                                                  width: 1,
                                                ),

                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color(0x14000000),
                                                    blurRadius: 4,
                                                    offset: Offset(0, 1),
                                                  ),
                                                ],
                                              ),

                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,

                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,

                                                children: [
                                                  Text(
                                                    isCheckIn
                                                        ? '▶ ARRIVAL'
                                                        : (guestName.isNotEmpty
                                                              ? guestName.split(
                                                                  ' ',
                                                                )[0]
                                                              : 'Booked'),

                                                    maxLines: 1,

                                                    overflow:
                                                        TextOverflow.ellipsis,

                                                    style: TextStyle(
                                                      fontSize: 9,

                                                      fontWeight:
                                                          FontWeight.bold,

                                                      color: isConflict
                                                          ? GinataColors
                                                                .alertTerracotta
                                                          : Colors.white,
                                                    ),
                                                  ),

                                                  const SizedBox(height: 2),

                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                          vertical: 1,
                                                        ),

                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),

                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),

                                                    child: Text(
                                                      _formatChannelLabel(
                                                        source,
                                                      ).toUpperCase(),

                                                      style: const TextStyle(
                                                        fontSize: 7.5,

                                                        fontWeight:
                                                            FontWeight.bold,

                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    // Open available day slot

                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2.5,
                                        ),

                                        child: InkWell(
                                          onTap: () =>
                                              _openBookingForPropertyDate(
                                                propId,
                                                d,
                                              ),

                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),

                                          child: Container(
                                            height: 52,

                                            decoration: BoxDecoration(
                                              color:
                                                  GinataColors.surfaceSubdued,

                                              borderRadius:
                                                  BorderRadius.circular(10),

                                              border: Border.all(
                                                color: GinataColors
                                                    .outlineVariant
                                                    .withValues(alpha: 0.4),
                                              ),
                                            ),

                                            child: const Center(
                                              child: Icon(
                                                Icons.add,
                                                size: 16,
                                                color: GinataColors.secondary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMonthView() {
    final year = _anchorDate.year;

    final month = _anchorDate.month;

    final firstDayOfMonth = DateTime(year, month, 1);

    final daysInMonth = DateTime(year, month + 1, 0).day;

    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    return Column(
      children: [
        // Weekday header
        Container(
          color: GinataColors.surface,

          padding: const EdgeInsets.symmetric(vertical: 10),

          child: Row(
            children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((
              w,
            ) {
              return Expanded(
                child: Center(
                  child: Text(
                    w,

                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: GinataColors.secondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const Divider(height: 1, color: GinataColors.surfaceContainerHigh),

        // Month Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),

            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,

              crossAxisSpacing: 8,

              mainAxisSpacing: 8,

              childAspectRatio: 0.82,
            ),

            itemCount: startWeekday + daysInMonth,

            itemBuilder: (ctx, idx) {
              if (idx < startWeekday) {
                return const SizedBox();
              }

              final dayNum = idx - startWeekday + 1;

              final curDate = DateTime(year, month, dayNum);

              final isToday =
                  curDate.day == DateTime.now().day &&
                  curDate.month == DateTime.now().month &&
                  curDate.year == DateTime.now().year;

              final activeBookingsOnDate = _filteredReservations.where((r) {
                return _isDateInRange(
                  curDate,
                  r['check_in_date'],
                  r['check_out_date'],
                );
              }).toList();

              return InkWell(
                onTap: () {
                  if (activeBookingsOnDate.isNotEmpty) {
                    _showBookingInspector(activeBookingsOnDate.first);
                  } else if (_properties.isNotEmpty) {
                    final targetProp = _selectedPropertyId != 'all'
                        ? _selectedPropertyId
                        : _properties[0]['id'].toString();

                    _openBookingForPropertyDate(targetProp, curDate);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please add a property in Estates before creating a booking.'),
                        backgroundColor: GinataColors.primary,
                      ),
                    );
                  }
                },

                borderRadius: BorderRadius.circular(12),

                child: Container(
                  padding: const EdgeInsets.all(6),

                  decoration: BoxDecoration(
                    color: isToday
                        ? GinataColors.secondaryContainer.withValues(
                            alpha: 0.35,
                          )
                        : (activeBookingsOnDate.isNotEmpty
                              ? GinataColors.surface
                              : GinataColors.surfaceSubdued),

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(
                      color: isToday
                          ? GinataColors.primary
                          : (activeBookingsOnDate.isNotEmpty
                                ? GinataColors.secondary
                                : GinataColors.outlineVariant.withValues(
                                    alpha: 0.5,
                                  )),

                      width: isToday ? 1.8 : 1.0,
                    ),

                    boxShadow: activeBookingsOnDate.isNotEmpty
                        ? const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: [
                          Text(
                            dayNum.toString(),

                            style: TextStyle(
                              fontSize: 12,

                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.w600,

                              color: isToday
                                  ? GinataColors.primary
                                  : GinataColors.textPrimary,
                            ),
                          ),

                          if (isToday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),

                              decoration: BoxDecoration(
                                color: GinataColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),

                              child: const Text(
                                'TODAY',
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),

                      if (activeBookingsOnDate.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Container(
                              width: double.infinity,

                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2.5,
                              ),

                              decoration: BoxDecoration(
                                color: _getChannelColor(
                                  activeBookingsOnDate
                                          .first['booking_source'] ??
                                      'direct',
                                ),

                                borderRadius: BorderRadius.circular(6),
                              ),

                              child: Text(
                                activeBookingsOnDate.length > 1
                                    ? '${activeBookingsOnDate.length} Stays'
                                    : (activeBookingsOnDate
                                              .first['primary_guest']?['first_name'] ??
                                          'Stay'),

                                maxLines: 1,

                                overflow: TextOverflow.ellipsis,

                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        const Center(
                          child: Icon(
                            Icons.add,
                            size: 14,
                            color: GinataColors.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
