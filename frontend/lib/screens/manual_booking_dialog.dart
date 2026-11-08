import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/ginata_theme.dart';
import '../services/api_service.dart';

class ManualBookingDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const ManualBookingDialog({super.key, this.initialData});

  @override
  State<ManualBookingDialog> createState() => _ManualBookingDialogState();
}

class _ManualBookingDialogState extends State<ManualBookingDialog> {
  final _formKey = GlobalKey<FormState>();

  List<dynamic> _properties = [];

  String? _selectedPropertyId;
  String? _selectedUnitId;
  String _bookingSource = 'direct';
  String _reservationStatus = 'confirmed';

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _guestsCtrl = TextEditingController(text: '2');

  DateTime _checkIn = DateTime.now().add(const Duration(days: 3));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 7));
  final _checkInTimeCtrl = TextEditingController(text: '15:00');
  final _checkOutTimeCtrl = TextEditingController(text: '11:00');

  final _nightlyRateCtrl = TextEditingController(text: '25000');
  final _cleaningFeeCtrl = TextEditingController(text: '4000');
  final _serviceFeeCtrl = TextEditingController(text: '0');
  final _discountCtrl = TextEditingController(text: '0');

  // Initial Deposit
  final bool _recordInitialPayment = false;
  final _depositAmountCtrl = TextEditingController(text: '50000');
  final String _paymentMethod = 'mpesa';
  final _txRefCtrl = TextEditingController();

  final _internalNotesCtrl = TextEditingController();
  final _specialRequestsCtrl = TextEditingController();

  // Agent referral tracking
  bool _hasAgent = false;
  final _agentNameCtrl = TextEditingController();
  final _agentPhoneCtrl = TextEditingController();
  final _agentCommissionPctCtrl = TextEditingController(text: '10');

  // Conflict state
  bool _hasConflict = false;
  String? _conflictMessage;
  bool _overrideConflict = false;
  final _overrideReasonCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _refCtrl.dispose();
    _guestsCtrl.dispose();
    _checkInTimeCtrl.dispose();
    _checkOutTimeCtrl.dispose();
    _nightlyRateCtrl.dispose();
    _cleaningFeeCtrl.dispose();
    _serviceFeeCtrl.dispose();
    _discountCtrl.dispose();
    _depositAmountCtrl.dispose();
    _txRefCtrl.dispose();
    _internalNotesCtrl.dispose();
    _specialRequestsCtrl.dispose();
    _agentNameCtrl.dispose();
    _agentPhoneCtrl.dispose();
    _agentCommissionPctCtrl.dispose();
    _overrideReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProperties() async {
    final props = await ApiService.fetchProperties();
    if (!mounted) return;
    setState(() {
      _properties = props;
      final isExistingReservation = widget.initialData != null && widget.initialData!['id'] != null;
      if (isExistingReservation) {
        final init = widget.initialData!;
        _selectedPropertyId = init['property_id']?.toString();
        _selectedUnitId = init['unit_id']?.toString();
        _bookingSource = init['booking_source'] ?? 'direct';
        _reservationStatus = init['reservation_status'] ?? 'confirmed';

        final guest = init['primary_guest'] ?? {};
        _firstNameCtrl.text = guest['first_name'] ?? '';
        _lastNameCtrl.text = guest['last_name'] ?? '';
        _emailCtrl.text = guest['email'] ?? '';
        _phoneCtrl.text = guest['phone'] ?? '';

        if (init['check_in_date'] != null) {
          _checkIn = DateTime.tryParse(init['check_in_date'].toString()) ?? _checkIn;
        }
        if (init['check_out_date'] != null) {
          _checkOut = DateTime.tryParse(init['check_out_date'].toString()) ?? _checkOut;
        }
        _checkInTimeCtrl.text = init['check_in_time'] ?? '15:00';
        _checkOutTimeCtrl.text = init['check_out_time'] ?? '11:00';

        _guestsCtrl.text = (init['number_of_guests'] ?? 2).toString();
        _nightlyRateCtrl.text = (init['nightly_rate'] ?? 25000).toString();
        _cleaningFeeCtrl.text = (init['cleaning_fee'] ?? 0).toString();
        _serviceFeeCtrl.text = (init['service_fee'] ?? 0).toString();
        _discountCtrl.text = (init['discount_amount'] ?? 0).toString();

        _refCtrl.text = init['booking_reference'] ?? '';
        _internalNotesCtrl.text = init['internal_notes'] ?? '';
        _specialRequestsCtrl.text = init['special_requests'] ?? '';

        _hasAgent = init['has_agent'] == true;
        _agentNameCtrl.text = init['agent_name'] ?? '';
        _agentPhoneCtrl.text = init['agent_phone'] ?? '';
        _agentCommissionPctCtrl.text = (init['agent_commission_percent'] ?? 10).toString();
      } else {
        // New booking (possibly pre-seeded with property/dates from calendar)
        if (widget.initialData != null && widget.initialData!['property_id'] != null) {
          _selectedPropertyId = widget.initialData!['property_id']?.toString();
        } else if (props.isNotEmpty) {
          _selectedPropertyId = props[0]['id']?.toString();
        }
        if (widget.initialData != null && widget.initialData!['check_in_date'] != null) {
          _checkIn = DateTime.tryParse(widget.initialData!['check_in_date'].toString()) ?? _checkIn;
        }
        if (widget.initialData != null && widget.initialData!['check_out_date'] != null) {
          _checkOut = DateTime.tryParse(widget.initialData!['check_out_date'].toString()) ?? _checkOut;
        }

        final targetProp = props.firstWhere(
          (p) => p['id']?.toString() == _selectedPropertyId,
          orElse: () => props.isNotEmpty ? props[0] : null,
        );
        if (targetProp != null) {
          _selectedPropertyId = targetProp['id']?.toString();
          final units = targetProp['units'] as List<dynamic>?;
          if (units != null && units.isNotEmpty) {
            _selectedUnitId = units[0]['id']?.toString();
          }
          _nightlyRateCtrl.text = (targetProp['default_nightly_rate'] ?? 25000).toString();
          _cleaningFeeCtrl.text = (targetProp['cleaning_fee'] ?? 0).toString();
        }
      }
    });
    _checkConflictsRealtime();
  }

  void _onPropertySelected(String? propId) {
    if (propId == null) return;
    setState(() {
      _selectedPropertyId = propId;
      final prop = _properties.firstWhere((p) => p['id']?.toString() == propId, orElse: () => null);
      if (prop != null) {
        final units = prop['units'] as List<dynamic>?;
        _selectedUnitId = (units != null && units.isNotEmpty) ? units[0]['id']?.toString() : null;
        _nightlyRateCtrl.text = prop['default_nightly_rate']?.toString() ?? '25000';
        _cleaningFeeCtrl.text = prop['cleaning_fee']?.toString() ?? '4000';
      }
    });
    _checkConflictsRealtime();
  }

  int get _nights => _checkOut.difference(_checkIn).inDays;

  double get _subtotal {
    final rate = double.tryParse(_nightlyRateCtrl.text) ?? 0;
    final cleaning = double.tryParse(_cleaningFeeCtrl.text) ?? 0;
    final service = double.tryParse(_serviceFeeCtrl.text) ?? 0;
    final disc = double.tryParse(_discountCtrl.text) ?? 0;
    return (rate * (_nights > 0 ? _nights : 1)) + cleaning + service - disc;
  }

  double get _tax => 0.0; // 0.00% VAT Direct Rate

  double get _grandTotal => _subtotal + _tax;

  double get _agentCommissionAmount {
    if (!_hasAgent) return 0.0;
    final pct = double.tryParse(_agentCommissionPctCtrl.text) ?? 0.0;
    return (_grandTotal * (pct / 100.0));
  }

  double get _netHostPayout => _grandTotal - _agentCommissionAmount;

  Future<void> _checkConflictsRealtime() async {
    if (_selectedPropertyId == null) return;
    try {
      final conflict = await ApiService.checkConflicts({
        'property_id': _selectedPropertyId!,
        'check_in_date': DateFormat('yyyy-MM-dd').format(_checkIn),
        'check_out_date': DateFormat('yyyy-MM-dd').format(_checkOut),
        if (_selectedUnitId != null) 'unit_id': _selectedUnitId,
        if (widget.initialData?['id'] != null) 'exclude_reservation_id': widget.initialData!['id'],
      });
      if (mounted) {
        setState(() {
          _hasConflict = conflict['has_conflict'] == true;
          _conflictMessage = conflict['message'];
        });
      }
    } catch (_) {}
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPropertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a property')),
      );
      return;
    }

    if (_hasConflict && !_overrideConflict) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calendar conflict! Check the authorized override box to proceed.'),
          backgroundColor: GinataColors.alertTerracotta,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'property_id': _selectedPropertyId,
        'unit_id': _selectedUnitId,
        'primary_guest': {
          'first_name': _firstNameCtrl.text.trim(),
          'last_name': _lastNameCtrl.text.trim(),
          'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
          'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        },
        'booking_source': _bookingSource,
        'booking_reference': _refCtrl.text.trim().isNotEmpty ? _refCtrl.text.trim() : null,
        'reservation_status': _reservationStatus,
        'check_in_date': DateFormat('yyyy-MM-dd').format(_checkIn),
        'check_out_date': DateFormat('yyyy-MM-dd').format(_checkOut),
        'check_in_time': _checkInTimeCtrl.text.trim(),
        'check_out_time': _checkOutTimeCtrl.text.trim(),
        'number_of_guests': int.tryParse(_guestsCtrl.text) ?? 2,
        'nightly_rate': double.tryParse(_nightlyRateCtrl.text) ?? 25000,
        'cleaning_fee': double.tryParse(_cleaningFeeCtrl.text) ?? 0,
        'service_fee': double.tryParse(_serviceFeeCtrl.text) ?? 0,
        'discount_amount': double.tryParse(_discountCtrl.text) ?? 0,
        'currency': 'KES',
        'has_agent': _hasAgent,
        'agent_name': _hasAgent && _agentNameCtrl.text.trim().isNotEmpty ? _agentNameCtrl.text.trim() : null,
        'agent_phone': _hasAgent && _agentPhoneCtrl.text.trim().isNotEmpty ? _agentPhoneCtrl.text.trim() : null,
        'agent_commission_percent': _hasAgent ? (double.tryParse(_agentCommissionPctCtrl.text) ?? 10.0) : 0.0,
        'internal_notes': _internalNotesCtrl.text.trim().isNotEmpty ? _internalNotesCtrl.text.trim() : null,
        'special_requests': _specialRequestsCtrl.text.trim().isNotEmpty ? _specialRequestsCtrl.text.trim() : null,
        'override_conflict': _overrideConflict,
        'conflict_override_reason': _overrideConflict ? _overrideReasonCtrl.text.trim() : null,
      };

      if (_recordInitialPayment) {
        payload['initial_payment'] = {
          'amount': double.tryParse(_depositAmountCtrl.text) ?? 0,
          'payment_method': _paymentMethod,
          'transaction_reference': _txRefCtrl.text.trim().isNotEmpty ? _txRefCtrl.text.trim() : null,
          'notes': 'Initial deposit recorded during booking creation',
        };
      }

      if (widget.initialData != null && widget.initialData!['id'] != null) {
        await ApiService.updateReservation(widget.initialData!['id'].toString(), payload);
      } else {
        await ApiService.createReservation(payload);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: GinataColors.alertTerracotta),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentProp = _properties.firstWhere((p) => p['id']?.toString() == _selectedPropertyId, orElse: () => null);
    final units = (currentProp?['units'] as List<dynamic>?) ?? [];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Apple-style Header with reliable close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('GINATA STAY', style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: GinataColors.secondary)),
                        Text(
                          (widget.initialData != null && widget.initialData!['id'] != null) ? 'Edit Reservation' : 'New Booking',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GinataColors.primary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 24, color: GinataColors.textSecondary),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const Divider(height: 16, color: Color(0x15101828)),

                // Scrollable Form Body
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // 1. Property & Unit Selection
                      _buildSectionTitle('1. Estate & Accommodation'),
                      const SizedBox(height: 8),
                      if (_properties.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: GinataColors.secondaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: GinataColors.secondary.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: GinataColors.primary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Please add a property in the Estates tab before confirming bookings.',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GinataColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      DropdownButtonFormField<String>(
                        key: ValueKey('prop_$_selectedPropertyId'),
                        initialValue: _selectedPropertyId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Select Property *'),
                        items: _properties.map<DropdownMenuItem<String>>((p) {
                          return DropdownMenuItem(
                            value: p['id'].toString(),
                            child: Text(p['name'].toString(), overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: _onPropertySelected,
                        validator: (val) => val == null ? 'Select property' : null,
                      ),
                      if (units.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          key: ValueKey('unit_$_selectedUnitId'),
                          initialValue: _selectedUnitId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Unit / Suite'),
                          items: units.map<DropdownMenuItem<String>>((u) {
                            return DropdownMenuItem(value: u['id'].toString(), child: Text(u['name'].toString()));
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedUnitId = val);
                            _checkConflictsRealtime();
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // 2. Primary Guest
                      _buildSectionTitle('2. Guest Details'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _firstNameCtrl,
                        decoration: const InputDecoration(labelText: 'First Name *', hintText: 'Amina'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _lastNameCtrl,
                        decoration: const InputDecoration(labelText: 'Last Name *', hintText: 'Kariuki'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone Number', hintText: '+254 700 000 000'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email Address', hintText: 'guest@email.com'),
                      ),
                      const SizedBox(height: 16),

                      // 3. Stay Dates, Times & Guest Count
                      _buildSectionTitle('3. Stay Dates & Length of Stay'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 730)),
                            initialDateRange: DateTimeRange(start: _checkIn, end: _checkOut),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: GinataColors.primary,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: GinataColors.textPrimary,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (range != null) {
                            setState(() {
                              _checkIn = range.start;
                              _checkOut = range.end;
                            });
                            _checkConflictsRealtime();
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: GinataColors.surfaceSubdued,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: GinataColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month, color: GinataColors.primary, size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Check-In & Check-Out Dates',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: GinataColors.primary),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: GinataColors.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$_nights ${_nights == 1 ? "Night" : "Nights"}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.5)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('CHECK-IN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: GinataColors.textSecondary)),
                                          const SizedBox(height: 2),
                                          Text(DateFormat('EEE, MMM d, yyyy').format(_checkIn), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GinataColors.textPrimary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.arrow_forward, size: 16, color: GinataColors.secondary),
                                  ),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.5)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('CHECK-OUT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: GinataColors.textSecondary)),
                                          const SizedBox(height: 2),
                                          Text(DateFormat('EEE, MMM d, yyyy').format(_checkOut), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GinataColors.textPrimary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text('Tap anywhere on this card to open interactive date picker', style: TextStyle(fontSize: 10, color: GinataColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _guestsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Guests *'),
                              validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Min 1' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _bookingSource,
                              decoration: const InputDecoration(labelText: 'Booking Channel'),
                              items: const [
                                DropdownMenuItem(value: 'direct', child: Text('Direct (Host)')),
                                DropdownMenuItem(value: 'phone', child: Text('Phone / Walk-in')),
                                DropdownMenuItem(value: 'airbnb', child: Text('Airbnb')),
                                DropdownMenuItem(value: 'booking_com', child: Text('Booking.com')),
                                DropdownMenuItem(value: 'other', child: Text('Other')),
                              ],
                              onChanged: (v) => setState(() => _bookingSource = v ?? 'direct'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Conflict Warning Box
                      if (_hasConflict) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: GinataColors.errorContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: GinataColors.alertTerracotta),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 18, color: GinataColors.alertTerracotta),
                                  SizedBox(width: 6),
                                  Text(
                                    'CALENDAR CONFLICT DETECTED',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GinataColors.alertTerracotta),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _conflictMessage ?? 'Dates overlap with an existing confirmed stay.',
                                style: const TextStyle(fontSize: 12, color: GinataColors.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: const Text('Authorized Override Conflict', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                value: _overrideConflict,
                                activeColor: GinataColors.primary,
                                onChanged: (v) => setState(() => _overrideConflict = v ?? false),
                              ),
                              if (_overrideConflict)
                                TextFormField(
                                  controller: _overrideReasonCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Override Reason *',
                                    hintText: 'e.g. Upgraded unit with host approval',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 4. Financial Calculations in KES
                      _buildSectionTitle('4. Pricing & Rates (KES)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nightlyRateCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Nightly Rate (KES) *', prefixText: 'KES '),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cleaningFeeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Cleaning Fee', prefixText: 'KES '),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _discountCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Discount', prefixText: 'KES '),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Apple-style Grand Total Summary Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: GinataColors.surfaceSubdued,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x15101828)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_nights night${_nights > 1 ? 's' : ''} stay',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GinataColors.textPrimary),
                                  ),
                                  const Text(
                                    '0.00% VAT · Direct Kenyan Rate',
                                    style: TextStyle(fontSize: 10, color: GinataColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                GinataFormatters.formatKES(_grandTotal),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GinataColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. Agent Referral
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x18101828)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Agent / Broker Referral', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: const Text('Track commission payout automatically', style: TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                              value: _hasAgent,
                              activeThumbColor: GinataColors.primary,
                              onChanged: (val) => setState(() => _hasAgent = val),
                            ),
                            if (_hasAgent) ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _agentNameCtrl,
                                decoration: const InputDecoration(labelText: 'Agent Name *', hintText: 'e.g. John Kamau'),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _agentCommissionPctCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Commission Percentage (%)', suffixText: '%'),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Commission: ${GinataFormatters.formatKES(_agentCommissionAmount)}', style: TextStyle(fontSize: 11, color: Colors.deepPurple.shade800)),
                                    Text('Net Host: ${GinataFormatters.formatKES(_netHostPayout)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade900)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 6. Notes & Status
                      _buildSectionTitle('6. Status & Notes'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _reservationStatus,
                        decoration: const InputDecoration(labelText: 'Reservation Status'),
                        items: const [
                          DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                          DropdownMenuItem(value: 'draft', child: Text('Draft Hold')),
                        ],
                        onChanged: (v) => setState(() => _reservationStatus = v ?? 'confirmed'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _internalNotesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Host Notes / Lockbox Code',
                          hintText: 'Notes for cleaning and arrival rituals...',
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 16, color: Color(0x15101828)),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, size: 16),
                      label: Text(
                        _isSaving ? 'Saving...' : ((widget.initialData != null && widget.initialData!['id'] != null) ? 'Save Changes' : 'Confirm Booking'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isSaving ? null : _submitBooking,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: GinataColors.primary,
      ),
    );
  }
}
