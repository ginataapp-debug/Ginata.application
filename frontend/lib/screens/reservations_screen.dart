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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReservationDetailsPage(
          reservation: res,
          onRefresh: _loadReservations,
        ),
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
    final guestPhone = (guest['phone'] ?? '').toString();
    final guestEmail = (guest['email'] ?? '').toString();
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
    final hasAgent = res['has_agent'] == true;
    final sourceColor = source.contains('AIRBNB')
        ? const Color(0xFFFF5A5F)
        : source.contains('BOOKING')
            ? const Color(0xFF003580)
            : GinataColors.primary;
    final formLabel = formStatus == 'completed'
        ? 'Form Verified'
        : formStatus == 'needs_review'
            ? 'Needs Review'
            : 'Form Pending';
    final formColor = formStatus == 'completed'
        ? GinataColors.primary
        : formStatus == 'needs_review'
            ? GinataColors.warningOchre
            : GinataColors.textSecondary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showReservationDetails(res as Map<String, dynamic>),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Guest (flexible) + Channel Tag (fixed)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guestName.isEmpty ? 'Guest' : guestName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GinataColors.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          unitName.isNotEmpty ? '$propName • $unitName' : propName,
                          style: const TextStyle(fontSize: 12, color: GinataColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      source,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: sourceColor),
                    ),
                  ),
                ],
              ),

              // Status badges row (agent / conflict) — wraps instead of overflowing
              if (hasAgent || hasConflict) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (hasAgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.support_agent, size: 11, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Agent: ${res['agent_name'] ?? 'Broker'} • ${res['agent_commission_percent'] ?? 0}%',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (hasConflict)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: GinataColors.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 11, color: GinataColors.alertTerracotta),
                            SizedBox(width: 4),
                            Text('OVERRIDDEN CONFLICT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: GinataColors.alertTerracotta)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // Dates & Nights (date text flexes, guests stay fixed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: GinataColors.surfaceSubdued,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: GinataColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${res['check_in_date']} → ${res['check_out_date']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GinataColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${res['number_of_nights']} nts',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GinataColors.secondary),
                    ),
                    Container(width: 1, height: 14, margin: const EdgeInsets.symmetric(horizontal: 8), color: GinataColors.outlineVariant),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline, size: 13, color: GinataColors.textSecondary),
                        const SizedBox(width: 3),
                        Text('${res['number_of_guests']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GinataColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),

              // Guest contact (informative, ellipsized so it never sticks out)
              if (guestPhone.isNotEmpty || guestEmail.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(guestPhone.isNotEmpty ? Icons.phone_outlined : Icons.email_outlined, size: 13, color: GinataColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [guestPhone, guestEmail].where((e) => e.isNotEmpty).join('  •  '),
                        style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // Bottom Row: Financials (flex) + Form pill (flex) + chevron
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(totalKes, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GinataColors.primary), overflow: TextOverflow.ellipsis),
                        if (hasAgent && res['net_host_amount'] != null)
                          Text(
                            'Net host: ${GinataFormatters.formatKES(res['net_host_amount'])}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          payStatus == 'paid' ? 'Paid in full' : 'Due: $balanceKes',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: payStatus == 'paid' ? GinataColors.successSage : GinataColors.warningOchre,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                            color: formColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(formLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: formColor), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20, color: GinataColors.outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReservationDetailsPage extends StatefulWidget {
  final Map<String, dynamic> reservation;
  final VoidCallback onRefresh;

  const ReservationDetailsPage({
    super.key,
    required this.reservation,
    required this.onRefresh,
  });

  @override
  State<ReservationDetailsPage> createState() => _ReservationDetailsPageState();
}

class _ReservationDetailsPageState extends State<ReservationDetailsPage> {
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
    final res = widget.reservation;
    final resId = res['id'].toString();
    final guest = res['primary_guest'] ?? {};
    final guestName = '${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}'.trim();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => PaymentModal(
        reservationId: resId,
        suggestedAmount: double.tryParse(res['balance_due']?.toString() ?? '0') ?? 0,
        totalAmount: double.tryParse(res['total_amount']?.toString() ?? '0') ?? 0,
        amountPaid: double.tryParse(res['amount_paid']?.toString() ?? '0') ?? 0,
        balanceDue: double.tryParse(res['balance_due']?.toString() ?? '0') ?? 0,
        guestName: guestName.isEmpty ? null : guestName,
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
      final link = '${ApiService.baseUrl}/public/forms/$token';

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

    final initial = guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G';
    final refLabel = (res['booking_reference'] ?? res['id'].toString().substring(0, 8)).toString();
    return Scaffold(
      backgroundColor: GinataColors.background,
      appBar: AppBar(
        backgroundColor: GinataColors.primary,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(guestName.isEmpty ? 'Guest' : guestName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                    Text('$propName • Ref: $refLabel', style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                Expanded(child: _buildFinMetric('TOTAL BILLED', totalKes)),
                Container(width: 1, height: 32, color: GinataColors.outlineVariant),
                Expanded(child: _buildFinMetric('AMOUNT PAID', paidKes, isPositive: true)),
                Container(width: 1, height: 32, color: GinataColors.outlineVariant),
                Expanded(child: _buildFinMetric('BALANCE DUE', balanceKes, isWarning: (double.tryParse(res['balance_due'].toString()) ?? 0) > 0)),
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
        ),
      ),
    );
  }

  Widget _buildFinMetric(String label, String value, {bool isPositive = false, bool isWarning = false}) {
    return Column(
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: GinataColors.textSecondary))),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isPositive ? GinataColors.successSage : isWarning ? GinataColors.warningOchre : GinataColors.primary,
            ),
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
