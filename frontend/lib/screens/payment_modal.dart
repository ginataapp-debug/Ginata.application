import 'package:flutter/material.dart';
import '../theme/ginata_theme.dart';
import '../services/api_service.dart';

class PaymentModal extends StatefulWidget {
  final String reservationId;
  final String? invoiceId;
  final double suggestedAmount;

  const PaymentModal({
    super.key,
    required this.reservationId,
    this.invoiceId,
    this.suggestedAmount = 0,
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

  Map<String, dynamic>? _generatedReceipt;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.suggestedAmount > 0 ? widget.suggestedAmount.toStringAsFixed(0) : '25000',
    );
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
      final receipt = payment['receipt'];

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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('FINANCIAL TRANSACTION', style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: GinataColors.secondary)),
                        Text('Record Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
                  ],
                ),
                const Divider(height: 24, color: GinataColors.surfaceContainerHigh),

                // Amount in KES
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount Received (KES) *',
                    prefixText: 'KES ',
                  ),
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
                const SizedBox(height: 12),

                // Transaction Reference
                TextFormField(
                  controller: _txRefCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Code / Reference',
                    hintText: 'e.g. QKH91823JK or Bank Ref',
                  ),
                ),
                const SizedBox(height: 12),

                // Verification Toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Verified by Payment Provider', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Distinguishes manually entered cash from gateway confirmed payouts.', style: TextStyle(fontSize: 11)),
                  value: _isVerified,
                  activeThumbColor: GinataColors.primary,
                  onChanged: (v) => setState(() => _isVerified = v),
                ),
                const SizedBox(height: 12),

                // Internal Notes
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Payment Notes',
                    hintText: 'e.g. Balance settlement for October stay',
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.receipt, size: 16),
                      label: Text(_isSubmitting ? 'Recording...' : 'Record & Issue Receipt'),
                      onPressed: _isSubmitting ? null : _submitPayment,
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

  Widget _buildReceiptView(Map<String, dynamic> receipt) {
    return Dialog(
      backgroundColor: GinataColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              const Text('Payment Recorded & Receipt Issued', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GinataColors.primary)),
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
                    _buildReceiptRow('Transaction Ref', receipt['transaction_reference'] ?? 'Direct Entry'),
                    const Divider(height: 16),
                    _buildReceiptRow('Issued To', receipt['issued_to_name'] ?? 'Valued Guest'),
                    const Divider(height: 16),
                    _buildReceiptRow('Remaining Balance', GinataFormatters.formatKES(receipt['remaining_balance']), isBold: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: GinataColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: GinataColors.primary)),
      ],
    );
  }
}
