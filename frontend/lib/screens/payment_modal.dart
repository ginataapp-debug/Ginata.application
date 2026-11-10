import 'package:flutter/material.dart';
import '../theme/ginata_theme.dart';
import '../services/api_service.dart';
import '../widgets/pdf_viewer.dart';

class PaymentModal extends StatefulWidget {
  final String reservationId;
  final String? invoiceId;
  final double suggestedAmount;
  final double totalAmount;
  final double amountPaid;
  final double balanceDue;
  final String? guestName;

  const PaymentModal({
    super.key,
    required this.reservationId,
    this.invoiceId,
    this.suggestedAmount = 0,
    this.totalAmount = 0,
    this.amountPaid = 0,
    this.balanceDue = 0,
    this.guestName,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _amountCtrl;
  final _txRefCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _paymentMethod = 'mpesa';
  bool _isVerified = false;
  bool _isSubmitting = false;
  String _payMode = 'full'; // full | half | custom

  Map<String, dynamic>? _generatedReceipt;
  bool _preparingPdf = false;

  double get _outstanding {
    final bal = widget.balanceDue > 0 ? widget.balanceDue : widget.suggestedAmount;
    return bal > 0 ? bal : 0;
  }

  @override
  void initState() {
    super.initState();
    final owed = _outstanding;
    _amountCtrl = TextEditingController(
      text: owed > 0 ? owed.toStringAsFixed(0) : (widget.suggestedAmount > 0 ? widget.suggestedAmount.toStringAsFixed(0) : ''),
    );
    _payMode = owed > 0 ? 'full' : 'custom';
  }

  void _applyPayMode(String mode) {
    setState(() {
      _payMode = mode;
      final owed = _outstanding;
      if (mode == 'full') {
        _amountCtrl.text = owed.toStringAsFixed(0);
      } else if (mode == 'half') {
        _amountCtrl.text = (owed / 2).toStringAsFixed(0);
      }
    });
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'reservation_id': widget.reservationId,
        'invoice_id': widget.invoiceId,
        'amount': double.tryParse(_amountCtrl.text) ?? 0,
        'currency': 'KES',
        'payment_method': _paymentMethod,
        'transaction_reference': _txRefCtrl.text.trim().isNotEmpty ? _txRefCtrl.text.trim() : null,
        'is_verified': _isVerified,
        'verification_source': _isVerified ? 'mpesa_c2b' : 'manual',
        'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      };

      final payment = await ApiService.recordPayment(payload);
      final receipt = (payment['receipt'] is Map)
          ? Map<String, dynamic>.from(payment['receipt'] as Map)
          : (payment['receipt_number'] != null ? Map<String, dynamic>.from(payment) : null);

      setState(() {
        _generatedReceipt = receipt;
        _isSubmitting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment Error: $e'), backgroundColor: GinataColors.alertTerracotta),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_generatedReceipt != null) {
      return _buildReceiptView(_generatedReceipt!);
    }

    return Dialog(
      backgroundColor: GinataColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FINANCIAL TRANSACTION', style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: GinataColors.secondary)),
                            Text('Record Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
                    ],
                  ),
                  const Divider(height: 24, color: GinataColors.surfaceContainerHigh),

                  // Amount owed banner
                  if (_outstanding > 0 || widget.totalAmount > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [GinataColors.primary, GinataColors.primaryContainer]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AMOUNT OWED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Colors.white70)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(GinataFormatters.formatKES(_outstanding), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                          if (widget.totalAmount > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _owedMini('Total billed', GinataFormatters.formatKES(widget.totalAmount))),
                                Container(width: 1, height: 22, color: Colors.white24),
                                Expanded(child: _owedMini('Paid so far', GinataFormatters.formatKES(widget.amountPaid))),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Full / Half / Custom selector
                    const Text('How much is being paid?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GinataColors.textPrimary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _payModeChip('full', 'Pay in full', Icons.check_circle_outline)),
                        const SizedBox(width: 8),
                        Expanded(child: _payModeChip('half', 'Half', Icons.pie_chart_outline)),
                        const SizedBox(width: 8),
                        Expanded(child: _payModeChip('custom', 'Custom', Icons.edit_outlined)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Amount in KES
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount Received (KES) *',
                      prefixText: 'KES ',
                      helperText: 'Editing this switches to a custom amount.',
                    ),
                    onChanged: (_) {
                      if (_payMode != 'custom') setState(() => _payMode = 'custom');
                    },
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid amount' : null,
                  ),
                  const SizedBox(height: 12),

                  // Payment Method
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method *'),
                    items: const [
                      DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa (Till / Paybill)')),
                      DropdownMenuItem(value: 'card', child: Text('Credit / Debit Card')),
                      DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Wire / EFT')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash at Concierge')),
                    ],
                    onChanged: (v) => setState(() => _paymentMethod = v ?? 'mpesa'),
                  ),
                  const SizedBox(height: 16),

                  // Transaction reference section (prominent)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: GinataColors.surfaceSubdued,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GinataColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.confirmation_number_outlined, size: 16, color: GinataColors.primary),
                            const SizedBox(width: 6),
                            const Text('Transaction reference code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('Enter the actual M-Pesa / bank code so the receipt matches the real transfer.', style: TextStyle(fontSize: 10, color: GinataColors.textSecondary)),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _txRefCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'e.g. QKH91823JK',
                            prefixIcon: Icon(Icons.tag, size: 18),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Verification Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Verified by Payment Provider', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Distinguishes manually entered cash from gateway confirmed payouts.', style: TextStyle(fontSize: 11)),
                    value: _isVerified,
                    activeThumbColor: GinataColors.primary,
                    onChanged: (v) => setState(() => _isVerified = v),
                  ),
                  const SizedBox(height: 8),

                  // Internal Notes
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Payment Notes',
                      hintText: 'e.g. Balance settlement for October stay',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Buttons — full width so the label never gets clipped
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GinataColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.receipt_long, size: 18),
                      label: Text(_isSubmitting ? 'Recording…' : 'Record & Issue Receipt', style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _isSubmitting ? null : _submitPayment,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _owedMini(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))),
        ],
      ),
    );
  }

  Widget _payModeChip(String mode, String label, IconData icon) {
    final selected = _payMode == mode;
    return InkWell(
      onTap: () => _applyPayMode(mode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? GinataColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? GinataColors.primary : GinataColors.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: selected ? Colors.white : GinataColors.secondary),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? Colors.white : GinataColors.textPrimary), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Future<void> _openReceiptPdf(Map<String, dynamic> receipt, {bool download = false}) async {
    final receiptId = receipt['id']?.toString();
    if (receiptId == null || receiptId.isEmpty || receiptId.startsWith('rcpt-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This receipt was saved offline. Reconnect to generate a PDF.'), backgroundColor: GinataColors.warningOchre),
      );
      return;
    }
    setState(() => _preparingPdf = true);
    try {
      final doc = await ApiService.exportReceipt(receiptId);
      final token = doc['secure_token']?.toString();
      final fileName = (doc['file_name'] ?? 'receipt-${receipt['receipt_number'] ?? ''}.pdf').toString();
      final apiPath = token != null && token.isNotEmpty ? '/public/documents/$token/download' : '/documents/${doc['id']}/download';
      if (!mounted) return;
      setState(() => _preparingPdf = false);
      if (download) {
        final bytes = await ApiService.downloadBytes(apiPath);
        if (mounted) await saveDocumentToDevice(context, bytes: bytes, fileName: fileName);
      } else {
        await openPdfViewer(context, title: 'Receipt', fileName: fileName, apiPath: apiPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _preparingPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: GinataColors.alertTerracotta),
        );
      }
    }
  }

  Widget _buildReceiptView(Map<String, dynamic> receipt) {
    final hostName = (receipt['issued_by_name']?.toString().isNotEmpty ?? false)
        ? receipt['issued_by_name'].toString()
        : (ApiService.hostName.isNotEmpty ? ApiService.hostName : 'Host');
    return Dialog(
      backgroundColor: GinataColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(color: GinataColors.secondaryContainer, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: GinataColors.primary, size: 28),
                ),
                const SizedBox(height: 12),
                const Text('Payment Recorded & Receipt Issued', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                const SizedBox(height: 4),
                Text('Receipt #${receipt['receipt_number']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GinataColors.secondary)),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GinataColors.surfaceSubdued,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildReceiptRow('Amount Received', GinataFormatters.formatKES(receipt['amount_received'])),
                      const Divider(height: 16),
                      _buildReceiptRow('Payment Method', (receipt['payment_method'] ?? 'mpesa').toString().toUpperCase()),
                      const Divider(height: 16),
                      _buildReceiptRow('Transaction Ref', (receipt['transaction_reference']?.toString().isNotEmpty ?? false) ? receipt['transaction_reference'].toString() : '—'),
                      const Divider(height: 16),
                      _buildReceiptRow('Issued To', (receipt['issued_to_name']?.toString().isNotEmpty ?? false) ? receipt['issued_to_name'].toString() : (widget.guestName ?? 'Valued Guest')),
                      const Divider(height: 16),
                      _buildReceiptRow('Issued By', hostName),
                      const Divider(height: 16),
                      _buildReceiptRow('Remaining Balance', GinataFormatters.formatKES(receipt['remaining_balance']), isBold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _preparingPdf
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.visibility_outlined, size: 17, color: GinataColors.primary),
                        label: Text('View PDF', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GinataColors.primary), overflow: TextOverflow.ellipsis),
                        onPressed: _preparingPdf ? null : () => _openReceiptPdf(receipt),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 17, color: GinataColors.primary),
                        label: Text('Download', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GinataColors.primary), overflow: TextOverflow.ellipsis),
                        onPressed: _preparingPdf ? null : () => _openReceiptPdf(receipt, download: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GinataColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: GinataColors.textSecondary))),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: GinataColors.primary),
          ),
        ),
      ],
    );
  }
}
