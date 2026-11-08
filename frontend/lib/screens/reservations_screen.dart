import 'package:flutter/material.dart';
import '../theme/ginata_theme.dart';
import '../services/api_service.dart';
import 'manual_booking_dialog.dart';
import 'payment_modal.dart';

class ReservationsScreen extends StatefulWidget {
  final VoidCallback onOpenNewBooking;

  const ReservationsScreen({super.key, required this.onOpenNewBooking});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  List<dynamic> _reservations = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() => _isLoading = true);
    final status = _selectedFilter == 'all' ? null : _selectedFilter;
    final res = await ApiService.fetchReservations(statusFilter: status);
    setState(() {
      _reservations = res;
      _isLoading = false;
    });
  }

  void _showReservationDetails(Map<String, dynamic> res) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GinataColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReservationDetailsSheet(
        reservation: res,
        onRefresh: _loadReservations,
      ),
    );
    _loadReservations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReservations,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Booking', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                final created = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const ManualBookingDialog(),
                );
                if (created == true) _loadReservations();
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All Stays', 'all'),
                _buildFilterChip('Confirmed', 'confirmed'),
                _buildFilterChip('Draft', 'draft'),
                _buildFilterChip('Checked In', 'checked_in'),
                _buildFilterChip('Departed', 'checked_out'),
                _buildFilterChip('Cancelled', 'cancelled'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Reservation List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: GinataColors.primary))
                : _reservations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.hotel_outlined, size: 48, color: GinataColors.outline),
                            const SizedBox(height: 12),
                            const Text('No reservations recorded yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                            const SizedBox(height: 4),
                            const Text('Create a direct booking or sync Airbnb & Booking.com channels.', style: TextStyle(fontSize: 12, color: GinataColors.textSecondary), textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GinataColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create First Booking', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: widget.onOpenNewBooking,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReservations,
                        color: GinataColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                          itemCount: _reservations.length,
                          itemBuilder: (ctx, idx) => _buildReservationCard(_reservations[idx]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: GinataColors.primary,
        backgroundColor: GinataColors.surfaceContainerHigh,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : GinataColors.textPrimary,
        ),
        shape: const StadiumBorder(),
        onSelected: (val) {
          setState(() => _selectedFilter = filterKey);
          _loadReservations();
        },
      ),
    );
  }

  Widget _buildReservationCard(dynamic res) {
    final guest = res['primary_guest'] ?? {};
    final guestName = '${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}'.trim();
    final prop = res['property'] ?? {};
    final propName = prop['name'] ?? 'Residence';
    final unit = res['unit'] ?? {};
    final unitName = unit['name'] ?? '';
    final source = (res['booking_source'] ?? 'direct').toString().toUpperCase();
    final payStatus = res['payment_status'] ?? 'unpaid';
    final formStatus = res['guest_info_status'] ?? 'pending';
    final totalKes = GinataFormatters.formatKES(res['total_amount']);
    final balanceKes = GinataFormatters.formatKES(res['balance_due']);
    final hasConflict = res['has_conflict'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showReservationDetails(res as Map<String, dynamic>),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Guest & Channel Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: GinataColors.primaryContainer,
                        child: Text(
                          guestName.isNotEmpty ? guestName[0] : 'G',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(guestName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                              if (hasConflict) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: GinataColors.errorContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('OVERRIDDEN CONFLICT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: GinataColors.alertTerracotta)),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            unitName.isNotEmpty ? '$propName • $unitName' : propName,
                            style: const TextStyle(fontSize: 12, color: GinataColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (res['has_agent'] == true) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'AGENT: ${res['agent_name'] ?? 'Broker'} (${res['agent_commission_percent'] ?? 0}%)',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
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
                ],
              ),
              const SizedBox(height: 12),

              // Middle: Dates & Nights
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
                        const Icon(Icons.calendar_today_outlined, size: 14, color: GinataColors.secondary),
                        const SizedBox(width: 6),
                        Text(
                          '${res['check_in_date']} - ${res['check_out_date']} (${res['number_of_nights']} nts)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GinataColors.textPrimary),
                        ),
                      ],
                    ),
                    Text(
                      '${res['number_of_guests']} Guests',
                      style: const TextStyle(fontSize: 12, color: GinataColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Bottom Row: Financials and Form Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        totalKes,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GinataColors.primary),
                      ),
                      if (res['has_agent'] == true && res['agent_commission_amount'] != null)
                        Text(
                          'Net Host: ${GinataFormatters.formatKES(res['net_host_amount'])}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                        ),
                      Text(
                        payStatus == 'paid' ? 'Paid in full' : 'Due: $balanceKes',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: payStatus == 'paid' ? GinataColors.secondary : GinataColors.warningOchre,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Guest Form Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: formStatus == 'completed'
                              ? GinataColors.secondaryContainer.withValues(alpha: 0.7)
                              : formStatus == 'needs_review'
                                  ? GinataColors.warningContainer
                                  : GinataColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              formStatus == 'completed'
                                  ? Icons.check_circle
                                  : formStatus == 'needs_review'
                                      ? Icons.rule
                                      : Icons.pending,
                              size: 12,
                              color: formStatus == 'completed'
                                  ? GinataColors.primary
                                  : formStatus == 'needs_review'
                                      ? GinataColors.warningOchre
                                      : GinataColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formStatus == 'completed'
                                  ? 'Form Verified'
                                  : formStatus == 'needs_review'
                                      ? 'Needs Review'
                                      : 'Form Pending',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: formStatus == 'completed'
                                    ? GinataColors.primary
                                    : formStatus == 'needs_review'
                                        ? GinataColors.warningOchre
                                        : GinataColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 20, color: GinataColors.outline),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservationDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> reservation;
  final VoidCallback onRefresh;

  const _ReservationDetailsSheet({
    required this.reservation,
    required this.onRefresh,
  });

  @override
  State<_ReservationDetailsSheet> createState() => _ReservationDetailsSheetState();
}

class _ReservationDetailsSheetState extends State<_ReservationDetailsSheet> {
  Map<String, dynamic>? _timelineData;
  bool _isLoadingTimeline = true;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    final resId = widget.reservation['id'].toString();
    final timeline = await ApiService.fetchFinancialTimeline(resId);
    setState(() {
      _timelineData = timeline;
      _isLoadingTimeline = false;
    });
  }

  void _recordPayment() async {
    final resId = widget.reservation['id'].toString();
    final balance = widget.reservation['balance_due']?.toString() ?? '0';

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => PaymentModal(
        reservationId: resId,
        suggestedAmount: double.tryParse(balance) ?? 0,
      ),
    );
    if (result == true) {
      widget.onRefresh();
      _loadTimeline();
    }
  }

  void _shareGuestForm() async {
    final resId = widget.reservation['id'].toString();
    try {
      final form = await ApiService.generateGuestForm(resId);
      final token = form['token'];
      final link = 'http://localhost:8000/api/v1/public/forms/$token';

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Guest Registration Portal Link'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Share this secure post-confirmation check-in link with the guest:'),
                const SizedBox(height: 12),
                SelectableText(
                  link,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: GinataColors.primary),
                ),
                const SizedBox(height: 12),
                Text('Token: $token', style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                Text('Status: ${form['form_status']}', style: const TextStyle(fontSize: 11, color: GinataColors.secondary)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _editBooking() async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ManualBookingDialog(initialData: widget.reservation),
    );
    if (updated == true) {
      widget.onRefresh();
      if (mounted) Navigator.pop(context);
    }
  }

  void _cancelBooking() async {
    final resId = widget.reservation['id'].toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Reservation?'),
        content: const Text('Are you sure you want to cancel this booking? This will update the reservation status and audit trail.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Booking')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GinataColors.alertTerracotta),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.cancelReservation(resId, reason: 'Cancelled by host');
        widget.onRefresh();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.reservation;
    final guest = res['primary_guest'] ?? {};
    final guestName = '${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}'.trim();
    final prop = res['property'] ?? {};
    final propName = prop['name'] ?? 'Residence';
    final totalKes = GinataFormatters.formatKES(res['total_amount']);
    final paidKes = GinataFormatters.formatKES(res['amount_paid']);
    final balanceKes = GinataFormatters.formatKES(res['balance_due']);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: GinataColors.outlineVariant, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(guestName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                  Text('$propName • Ref: ${res['booking_reference'] ?? res['id'].toString().substring(0, 8)}', style: const TextStyle(fontSize: 12, color: GinataColors.textSecondary)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),

          // Action Shortcuts Ribbon
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GinataColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.edit, size: 15),
                label: const Text('Edit Booking', style: TextStyle(fontSize: 12)),
                onPressed: _editBooking,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                icon: const Icon(Icons.payments_outlined, size: 15),
                label: const Text('Payment', style: TextStyle(fontSize: 12)),
                onPressed: _recordPayment,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                icon: const Icon(Icons.receipt_long, size: 15, color: GinataColors.primary),
                label: const Text('Invoice', style: TextStyle(fontSize: 12, color: GinataColors.primary)),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  final resId = widget.reservation['id'].toString();
                  try {
                    final inv = await ApiService.createInvoice(resId, {'document_type': 'invoice'});
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Invoice ${inv['invoice_number']} ready in Invoice Studio!'),
                        backgroundColor: GinataColors.primary,
                      ),
                    );
                    navigator.pop();
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                icon: const Icon(Icons.link, size: 15),
                label: const Text('Form Link', style: TextStyle(fontSize: 12)),
                onPressed: _shareGuestForm,
              ),
              if (res['reservation_status'] != 'cancelled')
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GinataColors.alertTerracotta,
                    side: const BorderSide(color: GinataColors.alertTerracotta),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 15, color: GinataColors.alertTerracotta),
                  label: const Text('Cancel', style: TextStyle(fontSize: 12, color: GinataColors.alertTerracotta)),
                  onPressed: _cancelBooking,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Financial Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GinataColors.surfaceSubdued,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFinMetric('TOTAL BILLED', totalKes),
                Container(width: 1, height: 32, color: GinataColors.outlineVariant),
                _buildFinMetric('AMOUNT PAID', paidKes, isPositive: true),
                Container(width: 1, height: 32, color: GinataColors.outlineVariant),
                _buildFinMetric('BALANCE DUE', balanceKes, isWarning: (double.tryParse(res['balance_due'].toString()) ?? 0) > 0),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Unified Financial Timeline
          const Text('Unified Financial Timeline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GinataColors.primary)),
          const SizedBox(height: 4),
          const Text('Booking events, invoice drafts, recorded payments, and issued receipts together.', style: TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
          const SizedBox(height: 12),

          Expanded(
            child: _isLoadingTimeline
                ? const Center(child: CircularProgressIndicator(color: GinataColors.primary))
                : (_timelineData?['timeline'] as List<dynamic>?)?.isEmpty ?? true
                    ? const Center(child: Text('No financial events recorded yet.'))
                    : ListView.builder(
                        itemCount: (_timelineData!['timeline'] as List<dynamic>).length,
                        itemBuilder: (ctx, idx) {
                          final item = (_timelineData!['timeline'] as List<dynamic>)[idx];
                          return _buildTimelineRow(item, idx == 0, idx == (_timelineData!['timeline'] as List<dynamic>).length - 1);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinMetric(String label, String value, {bool isPositive = false, bool isWarning = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: GinataColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isPositive ? GinataColors.secondary : isWarning ? GinataColors.warningOchre : GinataColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineRow(dynamic item, bool isFirst, bool isLast) {
    final type = item['type'] ?? '';
    final title = item['title'] ?? '';
    final desc = item['description'] ?? '';
    final amount = item['amount'];

    IconData icon = Icons.check_circle_outline;
    Color iconColor = GinataColors.primary;

    if (type.contains('payment')) {
      icon = Icons.payments;
      iconColor = GinataColors.secondary;
    } else if (type.contains('receipt')) {
      icon = Icons.verified;
      iconColor = GinataColors.brassGold;
    } else if (type.contains('invoice')) {
      icon = Icons.receipt_long;
      iconColor = GinataColors.primary;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical line and icon
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Icon(icon, size: 18, color: iconColor),
                if (!isLast) Expanded(child: Container(width: 2, color: GinataColors.surfaceContainerHigh)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Event content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                      if (amount != null)
                        Text(
                          GinataFormatters.formatKES(amount),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: type.contains('credit') ? GinataColors.alertTerracotta : GinataColors.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
