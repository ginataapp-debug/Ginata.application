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

  String _activeView = 'Month'; // 'Month' (default, interactive) or 'Timeline'
  String _selectedChannel = 'all';
  String _selectedPropertyId = 'all';
  DateTime _anchorDate = DateTime.now();

  // Interactive Date Range Selection
  DateTime? _rangeCheckIn;
  DateTime? _rangeCheckOut;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
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
      if (_selectedChannel != 'all' && r['booking_source'] != _selectedChannel) {
        return false;
      }
      if (_selectedPropertyId != 'all' && r['property_id'].toString() != _selectedPropertyId) {
        return false;
      }
      return true;
    }).toList();
  }

  List<dynamic> get _filteredProperties {
    if (_selectedPropertyId == 'all') return _properties;
    return _properties.where((p) => p['id'].toString() == _selectedPropertyId).toList();
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

  List<dynamic> _getBookingsOnDate(DateTime d) {
    return _filteredReservations.where((r) {
      return _isDateInRange(d, r['check_in_date'], r['check_out_date']);
    }).toList();
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

  void _openBookingForRange(DateTime checkIn, DateTime checkOut, {String? propertyId}) async {
    final targetPropId = propertyId ?? (_selectedPropertyId != 'all' ? _selectedPropertyId : (_properties.isNotEmpty ? _properties.first['id'].toString() : null));
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ManualBookingDialog(
        initialData: {
          if (targetPropId != null) ...{'property_id': targetPropId},
          'check_in_date': DateFormat('yyyy-MM-dd').format(checkIn),
          'check_out_date': DateFormat('yyyy-MM-dd').format(checkOut),
        },
      ),
    );
    if (created == true) {
      _loadCalendar();
    }
  }

  void _openBookingForPropertyDate(String propertyId, DateTime date) async {
    _openBookingForRange(date, date.add(const Duration(days: 2)), propertyId: propertyId);
  }

  void _showBookingInspector(dynamic res) {
    final guest = res['primary_guest'] ?? {};
    final guestName = '${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}'.trim();
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
      builder: (sheetCtx) => SafeArea(
        child: Padding(
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$propName · ${res['check_in_date']} to ${res['check_out_date']} (${res['number_of_nights'] ?? 1} nights)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: GinataColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getChannelColor(source).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getChannelColor(source).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _formatChannelLabel(source).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getChannelColor(source),
                      ),
                    ),
                  ),
                ],
              ),
              if (isConflict) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GinataColors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, size: 14, color: GinataColors.alertTerracotta),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Authorized Overridden Conflict',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GinataColors.alertTerracotta),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GinataColors.surfaceSubdued,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TOTAL BILLED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: GinataColors.textSecondary)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(totalKes, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BALANCE DUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: GinataColors.textSecondary)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              balanceKes,
                              style: TextStyle(
                                fontSize: 14,
                                color: (double.tryParse(res['balance_due']?.toString() ?? '0') ?? 0) > 0 ? GinataColors.warningOchre : GinataColors.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GUEST FORM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: GinataColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            formStatus == 'completed' ? '✓ Verified' : 'Pending',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: formStatus == 'completed' ? GinataColors.secondary : GinataColors.warningOchre,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Action Buttons
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
                        child: Text('Edit Booking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.payments_outlined, size: 15),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        final paid = await showDialog<bool>(
                          context: context,
                          builder: (_) => PaymentModal(
                            reservationId: res['id'].toString(),
                            suggestedAmount: double.tryParse(res['balance_due']?.toString() ?? '0') ?? 0,
                          ),
                        );
                        if (paid == true) _loadCalendar();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.receipt_long, size: 15, color: GinataColors.primary),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                      ),
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final inv = await ApiService.createInvoice(res['id'].toString(), {'document_type': 'invoice'});
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Invoice ${inv['invoice_number']} ready in Invoice Studio!'),
                              backgroundColor: GinataColors.primary,
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: GinataColors.alertTerracotta),
                    tooltip: 'Cancel Stay',
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Cancel Reservation?'),
                          content: Text('Are you sure you want to cancel the confirmed stay for $guestName?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Stay')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: GinataColors.alertTerracotta),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Cancel Reservation'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ApiService.cancelReservation(res['id'].toString(), reason: 'Cancelled from calendar');
                        _loadCalendar();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GinataColors.background,
      appBar: AppBar(
        title: const Text('Calendar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: GinataColors.primary),
            tooltip: 'Reload calendar',
            onPressed: _loadCalendar,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.add_circle, color: GinataColors.primary, size: 28),
              tooltip: 'New Booking',
              onPressed: widget.onNewBooking,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: GinataColors.primary))
          : Column(
              children: [
                // Clean Single Navigation & Header Card
                _buildHeaderControlBar(),

                // Calendar Body (Month View or Horizontal Timeline)
                Expanded(
                  child: _activeView == 'Month' ? _buildMonthView() : _buildTimelineView(),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderControlBar() {
    final monthStr = DateFormat('MMMM yyyy').format(_anchorDate);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          // Row 1: Month/Year Selector + Today button + View Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Date Switcher
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 22, color: GinataColors.primary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() {
                      if (_activeView == 'Month') {
                        _anchorDate = DateTime(_anchorDate.year, _anchorDate.month - 1, 1);
                      } else {
                        _anchorDate = _anchorDate.subtract(const Duration(days: 7));
                      }
                    }),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    monthStr,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GinataColors.primary),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 22, color: GinataColors.primary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() {
                      if (_activeView == 'Month') {
                        _anchorDate = DateTime(_anchorDate.year, _anchorDate.month + 1, 1);
                      } else {
                        _anchorDate = _anchorDate.add(const Duration(days: 7));
                      }
                    }),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() {
                      _anchorDate = DateTime.now();
                      _selectedDate = DateTime.now();
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: GinataColors.secondaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Today', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                    ),
                  ),
                ],
              ),

              // View Switcher (Month vs Timeline)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: GinataColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: ['Month', 'Timeline'].map((v) {
                    final isSel = _activeView == v;
                    return InkWell(
                      onTap: () => setState(() => _activeView = v),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSel ? GinataColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          v,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel ? Colors.white : GinataColors.textSecondary,
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

          // Row 2: Property Filter Dropdown & Channel Dropdown
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: GinataColors.surfaceSubdued,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPropertyId,
                      isDense: true,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                      style: const TextStyle(fontSize: 12, color: GinataColors.textPrimary),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Properties', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ..._properties.map((p) => DropdownMenuItem(
                              value: p['id'].toString(),
                              child: Text(p['name'] ?? 'Property', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedPropertyId = val ?? 'all'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: GinataColors.surfaceSubdued,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedChannel,
                      isDense: true,
                      isExpanded: true,
                      icon: const Icon(Icons.filter_list, size: 16),
                      style: const TextStyle(fontSize: 12, color: GinataColors.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Channels', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'direct', child: Text('Direct (KES)', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'airbnb', child: Text('Airbnb', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'booking_com', child: Text('Booking.com', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'walk_in', child: Text('Walk-in', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'phone', child: Text('Phone', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (v) => setState(() => _selectedChannel = v ?? 'all'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 3: Compact Channel Color Legend
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLegendItem('Direct', GinataColors.primary),
                const SizedBox(width: 12),
                _buildLegendItem('Airbnb', const Color(0xFFFF5A5F)),
                const SizedBox(width: 12),
                _buildLegendItem('Booking.com', const Color(0xFF003580)),
                const SizedBox(width: 12),
                _buildLegendItem('Phone/Walk-in', const Color(0xFF7C3AED)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: GinataColors.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ==========================================
  // INTERACTIVE MONTH VIEW WITH RANGE SELECTION
  // ==========================================
  Widget _buildMonthView() {
    final year = _anchorDate.year;
    final month = _anchorDate.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    return Column(
      children: [
        // Weekday header with clear typography
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((w) {
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GinataColors.secondary),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),

        // Month Grid
        Expanded(
          flex: 5,
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.95,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (ctx, idx) {
              if (idx < startWeekday) return const SizedBox();

              final dayNum = idx - startWeekday + 1;
              final curDate = DateTime(year, month, dayNum);
              final isToday = curDate.day == DateTime.now().day && curDate.month == DateTime.now().month && curDate.year == DateTime.now().year;

              final activeBookings = _getBookingsOnDate(curDate);
              final hasBooking = activeBookings.isNotEmpty;

              // Check if date is in selected check-in / check-out range
              final isCheckIn = _rangeCheckIn != null &&
                  _rangeCheckIn!.year == curDate.year &&
                  _rangeCheckIn!.month == curDate.month &&
                  _rangeCheckIn!.day == curDate.day;

              final isCheckOut = _rangeCheckOut != null &&
                  _rangeCheckOut!.year == curDate.year &&
                  _rangeCheckOut!.month == curDate.month &&
                  _rangeCheckOut!.day == curDate.day;

              final isInRange = _rangeCheckIn != null &&
                  _rangeCheckOut != null &&
                  curDate.isAfter(_rangeCheckIn!) &&
                  curDate.isBefore(_rangeCheckOut!);

              final isSelectedSingle = _selectedDate != null &&
                  _rangeCheckIn == null &&
                  _selectedDate!.year == curDate.year &&
                  _selectedDate!.month == curDate.month &&
                  _selectedDate!.day == curDate.day;

              Color cellBg = Colors.white;
              Border? cellBorder;

              if (isCheckIn || isCheckOut) {
                cellBg = GinataColors.primary;
              } else if (isInRange) {
                cellBg = GinataColors.secondaryContainer.withValues(alpha: 0.5);
              } else if (hasBooking) {
                cellBg = Colors.white;
                cellBorder = Border.all(color: _getChannelColor(activeBookings.first['booking_source'] ?? 'direct').withValues(alpha: 0.6), width: 1.2);
              } else if (isToday) {
                cellBg = GinataColors.secondaryContainer.withValues(alpha: 0.2);
                cellBorder = Border.all(color: GinataColors.primary, width: 1.5);
              } else if (isSelectedSingle) {
                cellBorder = Border.all(color: GinataColors.secondary, width: 1.5);
              } else {
                cellBorder = Border.all(color: Colors.grey.shade200);
              }

              return InkWell(
                onTap: () {
                  setState(() {
                    if (_rangeCheckIn == null || (_rangeCheckIn != null && _rangeCheckOut != null)) {
                      // First tap: Select check-in date
                      _rangeCheckIn = curDate;
                      _rangeCheckOut = null;
                      _selectedDate = curDate;
                    } else if (_rangeCheckIn != null && _rangeCheckOut == null) {
                      // Second tap: Select check-out date
                      if (curDate.isAfter(_rangeCheckIn!)) {
                        _rangeCheckOut = curDate;
                      } else {
                        // If tapped earlier date, make it the new check-in
                        _rangeCheckIn = curDate;
                        _rangeCheckOut = null;
                      }
                      _selectedDate = curDate;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: cellBg,
                    borderRadius: BorderRadius.circular(10),
                    border: cellBorder,
                    boxShadow: hasBooking
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Day Number & Status Dot
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dayNum.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday || isCheckIn || isCheckOut ? FontWeight.bold : FontWeight.w600,
                              color: isCheckIn || isCheckOut
                                  ? Colors.white
                                  : (isToday ? GinataColors.primary : GinataColors.textPrimary),
                            ),
                          ),
                          if (hasBooking && !isCheckIn && !isCheckOut)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _getChannelColor(activeBookings.first['booking_source'] ?? 'direct'),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),

                      // Range Marker or Booking Pill
                      if (isCheckIn)
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('IN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                        )
                      else if (isCheckOut)
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('OUT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                        )
                      else if (hasBooking)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _getChannelColor(activeBookings.first['booking_source'] ?? 'direct'),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              activeBookings.length > 1
                                  ? '${activeBookings.length} Stays'
                                  : (activeBookings.first['primary_guest']?['first_name'] ?? 'Stay'),
                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 6),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Interactive Date Range / Selected Date Inspector Panel
        _buildDateInspectorPanel(),
      ],
    );
  }

  // ==========================================
  // DATE INSPECTOR & ACTIONS PANEL
  // ==========================================
  Widget _buildDateInspectorPanel() {
    final hasRange = _rangeCheckIn != null && _rangeCheckOut != null;
    final singleDate = _selectedDate ?? _rangeCheckIn ?? DateTime.now();

    final bookingsOnSelected = _getBookingsOnDate(singleDate);
    final rangeNights = hasRange ? _rangeCheckOut!.difference(_rangeCheckIn!).inDays : 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Range Selected Banner OR Selected Date Header
          if (hasRange) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, size: 18, color: GinataColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${DateFormat('MMM d').format(_rangeCheckIn!)} → ${DateFormat('MMM d').format(_rangeCheckOut!)} ($rangeNights night${rangeNights > 1 ? "s" : ""})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GinataColors.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _rangeCheckIn = null;
                    _rangeCheckOut = null;
                  }),
                  child: const Text('Reset', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GinataColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: Text(
                  'Book Stay for $rangeNights Night${rangeNights > 1 ? "s" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => _openBookingForRange(_rangeCheckIn!, _rangeCheckOut!),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event, size: 16, color: GinataColors.secondary),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('EEE, MMM d, yyyy').format(singleDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: GinataColors.primary),
                    ),
                  ],
                ),
                if (_rangeCheckIn != null && _rangeCheckOut == null)
                  const Text('Tap checkout date', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: GinataColors.secondary))
                else
                  Text(
                    bookingsOnSelected.isNotEmpty ? '${bookingsOnSelected.length} Booking${bookingsOnSelected.length > 1 ? "s" : ""}' : 'Available',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: bookingsOnSelected.isNotEmpty ? GinataColors.primary : GinataColors.secondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Stays on selected day
            if (bookingsOnSelected.isNotEmpty) ...[
              ...bookingsOnSelected.map((b) {
                final guest = b['primary_guest'] ?? {};
                final guestName = '${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}'.trim();
                final prop = b['property'] ?? {};
                final propName = prop['name'] ?? 'Estate';
                final source = b['booking_source'] ?? 'direct';

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: GinataColors.surfaceSubdued,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _getChannelColor(source).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _getChannelColor(source),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guestName.isNotEmpty ? guestName : 'Valued Guest',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$propName · ${_formatChannelLabel(source)}',
                              style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GinataColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _showBookingInspector(b),
                        child: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 15),
                      label: Text('Book for ${DateFormat('MMM d').format(singleDate)}', style: const TextStyle(fontSize: 12)),
                      onPressed: () => _openBookingForRange(singleDate, singleDate.add(const Duration(days: 2))),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ==========================================
  // HORIZONTALLY SCROLLABLE TIMELINE VIEW
  // ==========================================
  Widget _buildTimelineView() {
    final startDay = _anchorDate.subtract(const Duration(days: 2));
    final days = List.generate(14, (i) => startDay.add(Duration(days: i)));

    if (_filteredProperties.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.domain_disabled_outlined, size: 48, color: GinataColors.outlineVariant),
              const SizedBox(height: 12),
              const Text('No Estates in Calendar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GinataColors.primary)),
              const SizedBox(height: 4),
              const Text('Add a property in Estates to view multi-day room availability.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: GinataColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      itemCount: _filteredProperties.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (ctx, idx) {
        final prop = _filteredProperties[idx];
        final propId = prop['id'].toString();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Property Name & Quick Book Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: GinataColors.secondary, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            prop['name'] ?? 'Estate',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GinataColors.primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _openBookingForPropertyDate(propId, DateTime.now()),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: GinataColors.secondaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 13, color: GinataColors.primary),
                          SizedBox(width: 2),
                          Text('Book', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Horizontally Scrollable 14-Day Timeline Tape
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: days.map((d) {
                    final booking = _findReservationForDate(propId, d);
                    final isToday = d.day == DateTime.now().day && d.month == DateTime.now().month && d.year == DateTime.now().year;

                    return Container(
                      width: 62,
                      margin: const EdgeInsets.only(right: 6),
                      child: Column(
                        children: [
                          // Day Header
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isToday ? GinataColors.primary : GinataColors.surfaceSubdued,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Text(
                                  DateFormat('E').format(d).toUpperCase(),
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isToday ? Colors.white70 : GinataColors.textSecondary),
                                ),
                                Text(
                                  d.day.toString(),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isToday ? Colors.white : GinataColors.textPrimary),
                                ),
                              ],
                            ),
                          ),

                          // Slot: Booked or Open
                          if (booking != null) ...[
                            Builder(
                              builder: (context) {
                                final guest = booking['primary_guest'] ?? {};
                                final guestName = '${guest['first_name'] ?? ''}'.trim();
                                final source = booking['booking_source'] ?? 'direct';
                                final channelColor = _getChannelColor(source);
                                final isCheckIn = booking['check_in_date'] == DateFormat('yyyy-MM-dd').format(d);

                                return InkWell(
                                  onTap: () => _showBookingInspector(booking),
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                                  child: Container(
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: channelColor.withValues(alpha: 0.9),
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            isCheckIn ? '▶ ARRIVAL' : (guestName.isNotEmpty ? guestName : 'Booked'),
                                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              _formatChannelLabel(source).toUpperCase(),
                                              style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ] else ...[
                            InkWell(
                              onTap: () => _openBookingForPropertyDate(propId, d),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: GinataColors.surfaceSubdued,
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: const Center(
                                  child: Icon(Icons.add, size: 16, color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
