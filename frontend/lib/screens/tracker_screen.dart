import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/ginata_theme.dart';
import 'reservations_screen.dart';

class TrackerScreen extends StatefulWidget {
  final VoidCallback onOpenStays;

  const TrackerScreen({super.key, required this.onOpenStays});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  List<Map<String, dynamic>> _reservations = [];
  Map<String, dynamic> _properties = {};
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService.fetchReservations(),
      ApiService.fetchProperties(),
      ApiService.fetchFinancialSummary(),
    ]);
    if (!mounted) return;
    final reservations = results[0] as List<dynamic>;
    final properties = results[1] as List<dynamic>;
    final summary = results[2] as Map<String, dynamic>;
    setState(() {
      _reservations = reservations.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _properties = {
        for (final p in properties) p['id'].toString(): Map<String, dynamic>.from(p as Map),
      };
      _summary = summary;
      _isLoading = false;
    });
  }

  Future<void> _openStay(Map<String, dynamic> reservation) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReservationDetailsPage(reservation: reservation, onRefresh: _load),
    ));
    if (mounted) await _load();
  }

  DateTime? _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return null;
    final local = parsed.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _isOpen(Map<String, dynamic> r) =>
      (r['reservation_status'] ?? '').toString().toLowerCase() != 'cancelled';

  String _guest(Map<String, dynamic> r) {
    final primary = r['primary_guest'];
    if (primary is Map) {
      final name = '${primary['first_name'] ?? ''} ${primary['last_name'] ?? ''}'.trim();
      if (name.isNotEmpty) return name;
    }
    final name = '${r['guest_first_name'] ?? ''} ${r['guest_last_name'] ?? ''}'.trim();
    return name.isNotEmpty ? name : (r['guest_name']?.toString() ?? 'Guest');
  }

  String _property(Map<String, dynamic> r) {
    final embedded = r['property'];
    if (embedded is Map && embedded['name'] != null) return embedded['name'].toString();
    return _properties[r['property_id']?.toString()]?['name']?.toString() ?? 'Property';
  }

  double _balance(Map<String, dynamic> r) {
    final explicit = double.tryParse(r['balance_due']?.toString() ?? '');
    if (explicit != null) return explicit;
    final total = double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(r['amount_paid']?.toString() ?? '0') ?? 0;
    return (total - paid).clamp(0, double.infinity).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final open = _reservations.where(_isOpen).toList();
    final arrivals = open.where((r) => _date(r['check_in_date']) == day).toList();
    final departures = open.where((r) => _date(r['check_out_date']) == day).toList();
    final inHouse = open.where((r) {
      final checkIn = _date(r['check_in_date']);
      final checkOut = _date(r['check_out_date']);
      return checkIn != null && checkOut != null && !checkIn.isAfter(day) && checkOut.isAfter(day);
    }).toList();
    final pending = double.tryParse(_summary['pending_balance']?.toString() ?? '') ??
        open.fold<double>(0, (sum, r) => sum + _balance(r));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stay Tracker'),
        actions: [
          IconButton(
            tooltip: 'Refresh tracker',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: GinataColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text(
              DateFormat('EEEE, d MMMM').format(today),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GinataColors.secondary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Today at a glance',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: GinataColors.primary),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 620 ? 4 : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: columns == 4 ? 1.45 : 1.55,
                  children: [
                    _metric(Icons.login, 'Arrivals', '${arrivals.length}', GinataColors.primary),
                    _metric(Icons.hotel, 'Staying today', '${inHouse.length}', GinataColors.secondary),
                    _metric(Icons.logout, 'Departures', '${departures.length}', GinataColors.warningOchre),
                    _metric(Icons.payments_outlined, 'Balance due', GinataFormatters.formatKES(pending), pending > 0 ? GinataColors.alertTerracotta : GinataColors.successSage),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                _filterChip(0, 'Today'),
                _filterChip(1, 'Next 7 days'),
                _filterChip(2, 'Payments'),
              ],
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: GinataColors.primary)),
              )
            else
              ..._buildContent(day, open, arrivals, departures),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(int index, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == index,
      onSelected: (_) => setState(() => _filter = index),
      selectedColor: GinataColors.primary,
      labelStyle: TextStyle(
        color: _filter == index ? Colors.white : GinataColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }

  Widget _metric(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          ),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
        ],
      ),
    );
  }

  List<Widget> _buildContent(DateTime day, List<Map<String, dynamic>> open, List<Map<String, dynamic>> arrivals, List<Map<String, dynamic>> departures) {
    if (_filter == 2) {
      final unpaid = open.where((r) => _balance(r) > 0).toList()
        ..sort((a, b) => (_date(a['check_in_date']) ?? day).compareTo(_date(b['check_in_date']) ?? day));
      if (unpaid.isEmpty) return [_empty('All payments are settled', 'No outstanding balances on open stays.')];
      return unpaid.map(_paymentCard).toList();
    }

    final limit = day.add(Duration(days: _filter == 0 ? 0 : 6));
    final events = <Map<String, dynamic>>[];
    for (final r in open) {
      final checkIn = _date(r['check_in_date']);
      final checkOut = _date(r['check_out_date']);
      if (checkIn != null && !checkIn.isBefore(day) && !checkIn.isAfter(limit)) {
        events.add({'reservation': r, 'date': checkIn, 'arrival': true});
      }
      if (checkOut != null && !checkOut.isBefore(day) && !checkOut.isAfter(limit)) {
        events.add({'reservation': r, 'date': checkOut, 'arrival': false});
      }
    }
    events.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    if (_filter == 0 && events.isEmpty && arrivals.isEmpty && departures.isEmpty) {
      return [_empty('No movements today', 'Arrivals and departures will appear here as their dates approach.')];
    }
    if (events.isEmpty) return [_empty('Nothing scheduled', 'No arrivals or departures in the next seven days.')];
    return events.map(_eventCard).toList();
  }

  Widget _eventCard(Map<String, dynamic> event) {
    final r = event['reservation'] as Map<String, dynamic>;
    final arrival = event['arrival'] as bool;
    final date = event['date'] as DateTime;
    final status = (r['reservation_status'] ?? 'confirmed').toString();
    return InkWell(
      onTap: () => _openStay(r),
      borderRadius: BorderRadius.circular(16),
      child: _card(
        icon: arrival ? Icons.login : Icons.logout,
        color: arrival ? GinataColors.primary : GinataColors.warningOchre,
        title: _guest(r),
        subtitle: '${arrival ? 'Arrival' : 'Departure'} · ${DateFormat('EEE, d MMM').format(date)}\n${_property(r)}',
        trailing: _statusChip(status),
      ),
    );
  }

  Widget _paymentCard(Map<String, dynamic> r) {
    final total = double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0;
    final balance = _balance(r);
    final paid = (total - balance).clamp(0, total).toDouble();
    final progress = total > 0 ? paid / total : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GinataColors.alertTerracotta.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_guest(r), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: GinataColors.textPrimary)),
              ),
              Text(GinataFormatters.formatKES(balance), style: const TextStyle(fontWeight: FontWeight.w700, color: GinataColors.alertTerracotta)),
            ],
          ),
          const SizedBox(height: 4),
          Text(_property(r), style: const TextStyle(fontSize: 12, color: GinataColors.textSecondary)),
          const SizedBox(height: 12),
          Semantics(
            container: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: progress, minHeight: 5, semanticsLabel: 'Payment progress', backgroundColor: GinataColors.surfaceSubdued, valueColor: const AlwaysStoppedAnimation<Color>(GinataColors.successSage)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('${GinataFormatters.formatKES(paid)} collected of ${GinataFormatters.formatKES(total)}', style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary))),
              TextButton(onPressed: () => _openStay(r), child: const Text('Open stay')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({required IconData icon, required Color color, required String title, required String subtitle, required Widget trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: GinataColors.textPrimary)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: GinataColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.toLowerCase();
    final color = normalized == 'confirmed' || normalized == 'checked_in'
        ? GinataColors.successSage
        : normalized == 'pending'
            ? GinataColors.warningOchre
            : GinataColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(
        normalized.replaceAll('_', ' '),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _empty(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: GinataColors.surfaceSubdued, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.event_available_outlined, size: 38, color: GinataColors.secondary),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: GinataColors.primary)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: GinataColors.textSecondary)),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: widget.onOpenStays, child: const Text('View all stays')),
        ],
      ),
    );
  }
}
