import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/ginata_theme.dart';
import '../services/api_service.dart';

class InvoiceStudioScreen extends StatefulWidget {
  final String? initialReservationId;

  const InvoiceStudioScreen({super.key, this.initialReservationId});

  @override
  State<InvoiceStudioScreen> createState() => _InvoiceStudioScreenState();
}

class _InvoiceStudioScreenState extends State<InvoiceStudioScreen> {
  // Tab switcher: 'invoices' or 'receipts'
  String _activeTab = 'invoices';

  List<dynamic> _invoices = [];
  Map<String, dynamic>? _selectedInvoice;

  List<dynamic> _receipts = [];
  Map<String, dynamic>? _selectedReceipt;
  Map<String, dynamic>? _orgProfile;

  bool _isLoading = true;
  bool _isExporting = false;
  bool _isIssuing = false;

  // Selected template layout style
  String _layoutStyle = 'minimalist_luxury';
  String _mobileView = 'list'; // 'list' or 'preview'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final invs = await ApiService.fetchInvoices();
    final recs = await ApiService.fetchReceipts();
    final org = await ApiService.fetchOrganization();
    if (!mounted) return;
    setState(() {
      _orgProfile = org;
      _invoices = invs;
      if (invs.isNotEmpty) {
        _selectedInvoice = invs.first as Map<String, dynamic>;
      } else {
        _selectedInvoice = null;
      }

      _receipts = recs;
      if (recs.isNotEmpty) {
        _selectedReceipt = recs.first as Map<String, dynamic>;
      } else {
        _selectedReceipt = null;
      }

      _isLoading = false;
    });
  }

  void _exportInvoiceDoc(String format) async {
    if (_selectedInvoice == null) return;
    setState(() => _isExporting = true);

    try {
      final doc = await ApiService.exportInvoice(_selectedInvoice!['id'], format);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('${format.toUpperCase()} Document Generated'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${doc['file_name']}'),
                const SizedBox(height: 6),
                Text('Size: ${(doc['file_size'] / 1024).toStringAsFixed(1)} KB'),
                const SizedBox(height: 12),
                const Text('Public Secure Download Link:'),
                const SizedBox(height: 4),
                SelectableText(
                  '${ApiService.baseUrl}/public/documents/${doc['secure_token']}/download',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: GinataColors.primary),
                ),
                const SizedBox(height: 8),
                const Text('Link expires in 14 days and avoids exposing internal database IDs.', style: TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _exportReceiptDoc() async {
    if (_selectedReceipt == null) return;
    setState(() => _isExporting = true);

    try {
      final doc = await ApiService.exportReceipt(_selectedReceipt!['id'].toString());
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('PDF Receipt Generated'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${doc['file_name']}'),
                const SizedBox(height: 6),
                Text('Size: ${(doc['file_size'] / 1024).toStringAsFixed(1)} KB'),
                const SizedBox(height: 12),
                const Text('Public Secure Download Link:'),
                const SizedBox(height: 4),
                SelectableText(
                  '${ApiService.baseUrl}/public/documents/${doc['secure_token']}/download',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: GinataColors.primary),
                ),
                const SizedBox(height: 8),
                const Text('Link expires in 14 days and guarantees official authenticity.', style: TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _issueInvoice() async {
    if (_selectedInvoice == null) return;
    setState(() => _isIssuing = true);

    try {
      final updated = await ApiService.issueInvoice(_selectedInvoice!['id']);
      setState(() => _selectedInvoice = updated);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice issued successfully!'), backgroundColor: GinataColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Issue error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isIssuing = false);
    }
  }

  // --- EDIT INVOICE DIALOG ---
  void _openEditInvoiceDialog() {
    if (_selectedInvoice == null) return;
    final inv = _selectedInvoice!;

    String docType = inv['document_type'] ?? 'invoice';
    final nameCtrl = TextEditingController(text: inv['billing_name'] ?? '');
    final emailCtrl = TextEditingController(text: inv['billing_email'] ?? '');
    final phoneCtrl = TextEditingController(text: inv['billing_phone'] ?? '');
    final compNameCtrl = TextEditingController(text: inv['billing_company_name'] ?? '');
    final compAddrCtrl = TextEditingController(text: inv['billing_company_address'] ?? '');
    final termsCtrl = TextEditingController(text: inv['payment_terms'] ?? '');
    final notesCtrl = TextEditingController(text: inv['notes'] ?? '');
    DateTime dueDate = DateTime.tryParse(inv['due_date'].toString()) ?? DateTime.now().add(const Duration(days: 7));

    // Editable line items list
    List<Map<String, dynamic>> items = [];
    final rawItems = inv['line_items'] as List<dynamic>?;
    if (rawItems != null && rawItems.isNotEmpty) {
      for (final it in rawItems) {
        items.add({
          'description': it['description'] ?? '',
          'quantity': it['quantity'] ?? 1,
          'unit_price': it['unit_price'] ?? 0,
          'tax_rate': it['tax_rate'] ?? 0.0,
          'discount_amount': it['discount_amount'] ?? 0,
        });
      }
    } else {
      items.add({
        'description': 'Accommodation Stay',
        'quantity': 1,
        'unit_price': inv['grand_total'] ?? 25000,
        'tax_rate': 0.0,
        'discount_amount': 0,
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double calcTotal() {
            double total = 0;
            for (final it in items) {
              final qty = double.tryParse(it['quantity'].toString()) ?? 1;
              final price = double.tryParse(it['unit_price'].toString()) ?? 0;
              final disc = double.tryParse(it['discount_amount'].toString()) ?? 0;
              final taxRate = double.tryParse(it['tax_rate'].toString()) ?? 0.0;
              final sub = (qty * price) - disc;
              total += sub + (sub * taxRate);
            }
            return total;
          }

          return Dialog(
            backgroundColor: GinataColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DOCUMENT STUDIO EDITOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: GinataColors.secondary)),
                            Text('Edit Invoice: ${inv['invoice_number']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogCtx)),
                      ],
                    ),
                    const Divider(height: 20, color: GinataColors.surfaceContainerHigh),

                    Expanded(
                      child: ListView(
                        children: [
                          // Document type & Due Date
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: docType,
                                  decoration: const InputDecoration(labelText: 'Document Type'),
                                  items: const [
                                    DropdownMenuItem(value: 'invoice', child: Text('Direct Stay Invoice')),
                                    DropdownMenuItem(value: 'pro_forma', child: Text('Pro Forma Invoice')),
                                    DropdownMenuItem(value: 'quotation', child: Text('Price Quotation')),
                                  ],
                                  onChanged: (v) => setDialogState(() => docType = v ?? 'invoice'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: dueDate,
                                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setDialogState(() => dueDate = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(labelText: 'Due Date *'),
                                    child: Text(DateFormat('yyyy-MM-dd').format(dueDate)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Billing Contact
                          const Text('Billing Contact (Guest)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(labelText: 'Primary Guest / Billing Name *'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: emailCtrl,
                                  decoration: const InputDecoration(labelText: 'Billing Email'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: phoneCtrl,
                                  decoration: const InputDecoration(labelText: 'Billing Phone'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Company Billing
                          const Text('Company Billing Identifiers (Optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: compNameCtrl,
                                  decoration: const InputDecoration(labelText: 'Company / Employer Name'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: compAddrCtrl,
                                  decoration: const InputDecoration(labelText: 'Company Address'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Itemized Line Items Table
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Itemized Line Items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                              TextButton.icon(
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text('Add Item', style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  setDialogState(() {
                                    items.add({
                                      'description': 'Additional Concierge / Stay Service',
                                      'quantity': 1,
                                      'unit_price': 5000,
                                      'tax_rate': 0.0,
                                      'discount_amount': 0,
                                    });
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          ...items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final it = entry.value;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: GinataColors.surfaceSubdued,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  TextFormField(
                                    initialValue: it['description']?.toString(),
                                    decoration: const InputDecoration(labelText: 'Description *', isDense: true),
                                    onChanged: (v) => it['description'] = v,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 70,
                                        child: TextFormField(
                                          initialValue: it['quantity']?.toString(),
                                          decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                                          keyboardType: TextInputType.number,
                                          onChanged: (v) => setDialogState(() => it['quantity'] = double.tryParse(v) ?? 1),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: it['unit_price']?.toString(),
                                          decoration: const InputDecoration(labelText: 'Rate (KES)', isDense: true),
                                          keyboardType: TextInputType.number,
                                          onChanged: (v) => setDialogState(() => it['unit_price'] = double.tryParse(v) ?? 0),
                                        ),
                                      ),
                                      if (items.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: GinataColors.alertTerracotta),
                                          onPressed: () {
                                            setDialogState(() => items.removeAt(idx));
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Computed Grand Total: ${GinataFormatters.formatKES(calcTotal())}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GinataColors.primary),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: notesCtrl,
                            decoration: const InputDecoration(labelText: 'Invoice Notes & Special Mentions'),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: termsCtrl,
                            decoration: const InputDecoration(labelText: 'Payment Terms'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 20, color: GinataColors.surfaceContainerHigh),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(dialogCtx);
                            try {
                              final payload = {
                                'document_type': docType,
                                'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
                                'billing_name': nameCtrl.text.trim(),
                                'billing_email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                                'billing_phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                                'billing_company_name': compNameCtrl.text.trim().isNotEmpty ? compNameCtrl.text.trim() : null,
                                'billing_company_address': compAddrCtrl.text.trim().isNotEmpty ? compAddrCtrl.text.trim() : null,
                                'payment_terms': termsCtrl.text.trim().isNotEmpty ? termsCtrl.text.trim() : null,
                                'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                'line_items': items.map((it) => {
                                  'description': it['description'],
                                  'quantity': it['quantity'],
                                  'unit_price': it['unit_price'],
                                  'tax_rate': it['tax_rate'] ?? 0.0,
                                  'discount_amount': it['discount_amount'] ?? 0,
                                }).toList(),
                                'force_edit': true,
                              };
                              final updated = await ApiService.updateInvoice(inv['id'], payload);
                              setState(() => _selectedInvoice = updated);
                              _loadData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invoice updated successfully!'), backgroundColor: GinataColors.primary),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update error: $e')));
                              }
                            }
                          },
                          child: const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- EDIT RECEIPT DIALOG ---
  void _openEditReceiptDialog() {
    if (_selectedReceipt == null) return;
    final rec = _selectedReceipt!;

    final toNameCtrl = TextEditingController(text: rec['issued_to_name'] ?? '');
    final byNameCtrl = TextEditingController(text: rec['issued_by_name'] ?? 'Host');
    final txRefCtrl = TextEditingController(text: rec['transaction_reference'] ?? '');
    final amountCtrl = TextEditingController(text: rec['amount_received']?.toString() ?? '0');
    final balanceCtrl = TextEditingController(text: rec['remaining_balance']?.toString() ?? '0');
    String method = rec['payment_method'] ?? 'mpesa';
    DateTime recDate = DateTime.tryParse(rec['receipt_date'].toString()) ?? DateTime.now();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: GinataColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('OFFICIAL PAYMENT RECEIPT EDITOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: GinataColors.secondary)),
                          Text('Edit Receipt: ${rec['receipt_number']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogCtx)),
                    ],
                  ),
                  const Divider(height: 20, color: GinataColors.surfaceContainerHigh),

                  Expanded(
                    child: ListView(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: recDate,
                                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now().add(const Duration(days: 30)),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => recDate = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Payment Date *'),
                                  child: Text(DateFormat('yyyy-MM-dd').format(recDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: method,
                                decoration: const InputDecoration(labelText: 'Payment Method'),
                                items: const [
                                  DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                                  DropdownMenuItem(value: 'card', child: Text('Credit / Debit Card')),
                                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                                ],
                                onChanged: (v) => setDialogState(() => method = v ?? 'mpesa'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: txRefCtrl,
                          decoration: const InputDecoration(labelText: 'Transaction / M-Pesa Code', hintText: 'e.g. QK8912KLM'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: amountCtrl,
                                decoration: const InputDecoration(labelText: 'Amount Received (KES) *'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: balanceCtrl,
                                decoration: const InputDecoration(labelText: 'Remaining Balance (KES)'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: toNameCtrl,
                          decoration: const InputDecoration(labelText: 'Issued To (Guest Name) *'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: byNameCtrl,
                          decoration: const InputDecoration(labelText: 'Issued By (Host Name) *'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20, color: GinataColors.surfaceContainerHigh),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogCtx);
                          try {
                            final payload = {
                              'receipt_date': DateFormat('yyyy-MM-dd').format(recDate),
                              'payment_method': method,
                              'transaction_reference': txRefCtrl.text.trim().isNotEmpty ? txRefCtrl.text.trim() : null,
                              'amount_received': double.tryParse(amountCtrl.text) ?? 0,
                              'remaining_balance': double.tryParse(balanceCtrl.text) ?? 0,
                              'issued_to_name': toNameCtrl.text.trim(),
                              'issued_by_name': byNameCtrl.text.trim(),
                            };
                            final updated = await ApiService.updateReceipt(rec['id'].toString(), payload);
                            setState(() => _selectedReceipt = updated);
                            _loadData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Receipt updated successfully!'), backgroundColor: GinataColors.primary),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update error: $e')));
                            }
                          }
                        },
                        child: const Text('Save Receipt'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSendDialog() {
    if (_selectedInvoice == null) return;
    final guestEmail = _selectedInvoice!['billing_email'] ?? 'guest@example.com';
    final guestPhone = _selectedInvoice!['billing_phone'] ?? '+254 700 000 000';

    final emailCtrl = TextEditingController(text: guestEmail);
    final phoneCtrl = TextEditingController(text: guestPhone);
    String channel = 'email';
    bool sending = false;
    Map<String, dynamic>? deliveryResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          if (deliveryResult != null) {
            return AlertDialog(
              title: const Text('Delivery Attempt Recorded'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        deliveryResult!['status'] == 'sent' || deliveryResult!['status'] == 'delivered'
                            ? Icons.check_circle
                            : Icons.error,
                        color: deliveryResult!['status'] == 'sent' || deliveryResult!['status'] == 'delivered'
                            ? GinataColors.secondary
                            : GinataColors.alertTerracotta,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status: ${deliveryResult!['status'].toString().toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Recipient: ${deliveryResult!['recipient']}'),
                  Text('Channel: ${deliveryResult!['channel']}'),
                  if (deliveryResult!['error_message'] != null) ...[
                    const SizedBox(height: 8),
                    Text('Error: ${deliveryResult!['error_message']}', style: const TextStyle(color: GinataColors.alertTerracotta)),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Done')),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Send Invoice to Guest'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose verified delivery channel:', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: channel,
                  items: const [
                    DropdownMenuItem(value: 'email', child: Text('Email with PDF Attachment')),
                    DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp Business Invite')),
                    DropdownMenuItem(value: 'secure_link', child: Text('Generate Secure Download Link')),
                  ],
                  onChanged: (v) => setDialogState(() => channel = v ?? 'email'),
                ),
                const SizedBox(height: 12),
                if (channel == 'email')
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Guest Email Address *'),
                  ),
                if (channel == 'whatsapp')
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Guest WhatsApp Number *'),
                  ),
                if (channel == 'secure_link')
                  const Text('Generates an unguessable 14-day download URL without sensitive record IDs.', style: TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
              ElevatedButton.icon(
                icon: sending
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, size: 16),
                label: Text(sending ? 'Sending...' : 'Send Now'),
                onPressed: sending
                    ? null
                    : () async {
                        setDialogState(() => sending = true);
                        try {
                          final recipient = channel == 'email'
                              ? emailCtrl.text.trim()
                              : channel == 'whatsapp'
                                  ? phoneCtrl.text.trim()
                                  : 'secure_guest_link';

                          final res = await ApiService.sendInvoice(_selectedInvoice!['id'], channel, recipient);
                          setDialogState(() {
                            deliveryResult = res;
                            sending = false;
                          });
                        } catch (e) {
                          setDialogState(() => sending = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delivery error: $e')));
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _openCreateInvoiceDialog() async {
    final resList = await ApiService.fetchReservations();
    if (!mounted) return;

    String? selectedResId = resList.isNotEmpty ? resList.first['id'].toString() : null;
    String docType = 'invoice';
    final guestNameCtrl = TextEditingController(text: 'Valued Guest');
    final propNameCtrl = TextEditingController(text: 'Residence Suite');
    final nightsCtrl = TextEditingController(text: '3');
    final rateCtrl = TextEditingController(text: '15000');
    bool isCustom = resList.isEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: GinataColors.secondaryContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.note_add_outlined, color: GinataColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Generate Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: docType,
                  decoration: const InputDecoration(labelText: 'Document Type'),
                  items: const [
                    DropdownMenuItem(value: 'invoice', child: Text('Direct Stay Invoice')),
                    DropdownMenuItem(value: 'pro_forma', child: Text('Pro Forma Invoice')),
                    DropdownMenuItem(value: 'quotation', child: Text('Price Quotation')),
                  ],
                  onChanged: (v) => setDialogState(() => docType = v ?? 'invoice'),
                ),
                const SizedBox(height: 12),
                if (resList.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('From Existing Stay'),
                          selected: !isCustom,
                          onSelected: (val) => setDialogState(() => isCustom = !val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Custom Direct Bill'),
                          selected: isCustom,
                          onSelected: (val) => setDialogState(() => isCustom = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (!isCustom && resList.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedResId,
                    decoration: const InputDecoration(labelText: 'Select Stay *'),
                    isExpanded: true,
                    items: resList.map<DropdownMenuItem<String>>((r) {
                      final guest = r['primary_guest'] ?? {};
                      final name = '${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}'.trim();
                      final prop = r['property']?['name'] ?? 'Residence';
                      return DropdownMenuItem(
                        value: r['id'].toString(),
                        child: Text('${name.isNotEmpty ? name : "Guest"} ($prop)', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedResId = v),
                  ),
                ] else ...[
                  TextField(
                    controller: guestNameCtrl,
                    decoration: const InputDecoration(labelText: 'Guest / Client Name *', hintText: 'e.g. Amina Kariuki'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: propNameCtrl,
                    decoration: const InputDecoration(labelText: 'Estate / Property *', hintText: 'e.g. Primary Residence'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nightsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Nights *'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: rateCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Nightly Rate (KES) *', prefixText: 'KES '),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GinataColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                try {
                  String targetResId = selectedResId ?? '';
                  if (isCustom || targetResId.isEmpty) {
                    final n = int.tryParse(nightsCtrl.text) ?? 1;
                    final r = double.tryParse(rateCtrl.text) ?? 15000;
                    final props = await ApiService.fetchProperties();
                    String propId;
                    if (props.isNotEmpty) {
                      propId = props.first['id'].toString();
                    } else {
                      final newProp = await ApiService.createProperty({
                        'name': propNameCtrl.text.trim().isNotEmpty ? propNameCtrl.text.trim() : 'Primary Estate',
                        'city': 'Nairobi',
                        'country': 'Kenya',
                        'base_rate_night': r,
                      });
                      propId = newProp['id'].toString();
                    }
                    final now = DateTime.now();
                    final checkInStr = DateFormat('yyyy-MM-dd').format(now);
                    final checkOutStr = DateFormat('yyyy-MM-dd').format(now.add(Duration(days: n)));

                    final directRes = await ApiService.createReservation({
                      'property_id': propId,
                      'guest_first_name': guestNameCtrl.text.trim().isNotEmpty ? guestNameCtrl.text.trim() : 'Valued Guest',
                      'guest_last_name': '',
                      'check_in_date': checkInStr,
                      'check_out_date': checkOutStr,
                      'number_of_nights': n,
                      'nightly_rate': r,
                      'booking_source': 'direct',
                    });
                    targetResId = directRes['id'].toString();
                  }

                  final newInv = await ApiService.createInvoice(targetResId, {'document_type': docType});
                  if (!mounted) return;
                  setState(() {
                    _activeTab = 'invoices';
                    _selectedInvoice = newInv;
                    _mobileView = 'preview';
                  });
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Created ${newInv['invoice_number']}!'), backgroundColor: GinataColors.primary),
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Generate Document'),
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
        title: const Text('Invoices & Receipts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: GinataColors.primary),
            tooltip: 'Reload',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined, color: GinataColors.primary, size: 24),
            tooltip: 'New Document',
            onPressed: _openCreateInvoiceDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: GinataColors.primary))
          : LayoutBuilder(
              builder: (ctx, constraints) {
                final isWide = constraints.maxWidth >= 720;

                Widget navPanel = Container(
                  width: isWide ? 320 : double.infinity,
                  decoration: BoxDecoration(
                    color: GinataColors.surface,
                    border: isWide ? const Border(right: BorderSide(color: GinataColors.surfaceContainerHigh)) : null,
                  ),
                  child: Column(
                    children: [
                      // Segmented Control: Invoices vs Receipts
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: GinataColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _activeTab = 'invoices'),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _activeTab == 'invoices' ? GinataColors.surface : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Invoices (${_invoices.length})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: _activeTab == 'invoices' ? FontWeight.bold : FontWeight.w500,
                                        color: _activeTab == 'invoices' ? GinataColors.primary : GinataColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _activeTab = 'receipts'),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _activeTab == 'receipts' ? GinataColors.surface : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Receipts (${_receipts.length})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: _activeTab == 'receipts' ? FontWeight.bold : FontWeight.w500,
                                        color: _activeTab == 'receipts' ? GinataColors.primary : GinataColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Document List Items
                      Expanded(
                        child: _activeTab == 'invoices'
                            ? _buildInvoicesList()
                            : _buildReceiptsList(),
                      ),
                    ],
                  ),
                );

                Widget previewPanel = Column(
                  children: [
                    if (!isWide)
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('Back to Documents List'),
                              onPressed: () => setState(() => _mobileView = 'list'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _activeTab == 'invoices'
                          ? _buildInvoiceStudioPreview()
                          : _buildReceiptStudioPreview(),
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    children: [
                      navPanel,
                      Expanded(child: previewPanel),
                    ],
                  );
                } else {
                  return _mobileView == 'list' ? navPanel : previewPanel;
                }
              },
            ),
    );
  }

  Widget _buildInvoicesList() {
    if (_invoices.isEmpty) {
      return const Center(child: Text('No invoices generated yet.'));
    }
    return ListView.builder(
      itemCount: _invoices.length,
      itemBuilder: (ctx, idx) {
        final inv = _invoices[idx];
        final isSel = _selectedInvoice?['id'] == inv['id'];
        final isIssued = inv['status'] == 'issued';
        final isPaid = inv['status'] == 'paid';

        return Material(
          color: isSel ? GinataColors.surfaceContainerLow : Colors.transparent,
          child: ListTile(
            onTap: () => setState(() { _selectedInvoice = inv as Map<String, dynamic>; _mobileView = 'preview'; }),
            leading: CircleAvatar(
              backgroundColor: isPaid ? GinataColors.secondaryContainer : GinataColors.surfaceContainerHigh,
              child: Icon(
                isPaid ? Icons.check : Icons.receipt_long,
                size: 16,
                color: isPaid ? GinataColors.primary : GinataColors.textSecondary,
              ),
            ),
            title: Text(inv['invoice_number'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text('${inv['billing_name'] ?? ''} • ${GinataFormatters.formatKES(inv['grand_total'])}', style: const TextStyle(fontSize: 11)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isIssued || isPaid ? GinataColors.secondaryContainer : GinataColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (inv['status'] ?? 'draft').toString().toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isIssued || isPaid ? GinataColors.primary : GinataColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptsList() {
    if (_receipts.isEmpty) {
      return const Center(child: Text('No payment receipts recorded yet.'));
    }
    return ListView.builder(
      itemCount: _receipts.length,
      itemBuilder: (ctx, idx) {
        final rec = _receipts[idx];
        final isSel = _selectedReceipt?['id'] == rec['id'];

        return Material(
          color: isSel ? GinataColors.surfaceContainerLow : Colors.transparent,
          child: ListTile(
            onTap: () => setState(() { _selectedReceipt = rec as Map<String, dynamic>; _mobileView = 'preview'; }),
            leading: const CircleAvatar(
              backgroundColor: GinataColors.secondaryContainer,
              child: Icon(Icons.verified, size: 16, color: GinataColors.primary),
            ),
            title: Text(rec['receipt_number'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text('${rec['issued_to_name'] ?? 'Guest'} • ${GinataFormatters.formatKES(rec['amount_received'])}', style: const TextStyle(fontSize: 11)),
            trailing: Text(
              rec['receipt_date'] ?? '',
              style: const TextStyle(fontSize: 10, color: GinataColors.textSecondary),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoiceStudioPreview() {
    if (_selectedInvoice == null) {
      return const Center(child: Text('Select an invoice to preview'));
    }

    return Container(
      color: GinataColors.background,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Studio Controls Ribbon
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            spacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Brand Layout: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                  DropdownButton<String>(
                    value: _layoutStyle,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'minimalist_luxury', child: Text('Minimalist Luxury')),
                      DropdownMenuItem(value: 'classic_monograph', child: Text('Classic Monograph')),
                      DropdownMenuItem(value: 'modern_corporate', child: Text('Modern Corporate')),
                    ],
                    onChanged: (v) => setState(() => _layoutStyle = v ?? 'minimalist_luxury'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Edit Invoice Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GinataColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit Invoice', style: TextStyle(fontSize: 11)),
                    onPressed: _openEditInvoiceDialog,
                  ),
                  if (_selectedInvoice!['status'] == 'draft')
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: _isIssuing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.lock_outline, size: 14),
                      label: const Text('Issue Document', style: TextStyle(fontSize: 11)),
                      onPressed: _isIssuing ? null : _issueInvoice,
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 14, color: GinataColors.primary),
                    label: const Text('PDF', style: TextStyle(fontSize: 11)),
                    onPressed: _isExporting ? null : () => _exportInvoiceDoc('pdf'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.description, size: 14, color: GinataColors.secondary),
                    label: const Text('Word DOCX', style: TextStyle(fontSize: 11)),
                    onPressed: _isExporting ? null : () => _exportInvoiceDoc('docx'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.table_chart, size: 14, color: GinataColors.textSecondary),
                    label: const Text('CSV', style: TextStyle(fontSize: 11)),
                    onPressed: _isExporting ? null : () => _exportInvoiceDoc('csv'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GinataColors.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.send, size: 14),
                    label: const Text('Send to Guest', style: TextStyle(fontSize: 11)),
                    onPressed: _openSendDialog,
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24, color: GinataColors.surfaceContainerHigh),

          // Interactive Live Preview Card (Clean - NO KRA PIN)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Center(
                  child: Container(
                    width: 620,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: GinataColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F0D2620),
                          blurRadius: 24,
                          offset: Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: const Color(0x14174A3F)),
                    ),
                    child: _buildLiveInvoicePreviewContent(_selectedInvoice!),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptStudioPreview() {
    if (_selectedReceipt == null) {
      return const Center(child: Text('Select a receipt to preview'));
    }

    final rec = _selectedReceipt!;

    return Container(
      color: GinataColors.background,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Studio Controls Ribbon for Receipt
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            spacing: 12,
            children: [
              Text(
                'PAYMENT RECEIPT: ${rec['receipt_number']}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GinataColors.primary),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GinataColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit Receipt', style: TextStyle(fontSize: 11)),
                    onPressed: _openEditReceiptDialog,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 14, color: GinataColors.primary),
                    label: const Text('Download PDF Receipt', style: TextStyle(fontSize: 11)),
                    onPressed: _isExporting ? null : _exportReceiptDoc,
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24, color: GinataColors.surfaceContainerHigh),

          // Live Official Receipt Card
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Center(
                  child: Container(
                    width: 580,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: GinataColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F0D2620),
                          blurRadius: 24,
                          offset: Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: const Color(0x14174A3F)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with Logo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Image.asset('assets/images/logo.png', height: 42, errorBuilder: (context, error, stackTrace) => const Icon(Icons.villa, color: GinataColors.primary, size: 36)),
                                const SizedBox(height: 6),
                                Text(_orgProfile?['name']?.isNotEmpty == true ? _orgProfile!['name'] : 'Ginata Host', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                                Text('${_orgProfile?['city'] ?? "Nairobi, Kenya"}${_orgProfile?["email"]?.isNotEmpty == true ? " • ${_orgProfile!["email"]}" : ""}', style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('PAYMENT RECEIPT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                                const SizedBox(height: 4),
                                Text('Receipt No: ${rec['receipt_number']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GinataColors.secondary)),
                                Text('Date: ${rec['receipt_date']}', style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: GinataColors.surfaceContainerHigh),
                        const SizedBox(height: 16),

                        // Amount Received Big Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: GinataColors.secondaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: GinataColors.secondary.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('AMOUNT RECEIVED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: GinataColors.secondary)),
                              const SizedBox(height: 6),
                              Text(
                                GinataFormatters.formatKES(rec['amount_received']),
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: GinataColors.primary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Payment Method: ${(rec['payment_method'] ?? 'M-Pesa').toString().toUpperCase()}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GinataColors.textPrimary),
                              ),
                              if (rec['transaction_reference'] != null)
                                Text(
                                  'Transaction Ref: ${rec['transaction_reference']}',
                                  style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Details Grid
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: GinataColors.surfaceSubdued,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildTotalRow('Issued To (Payer)', rec['issued_to_name'] ?? 'Valued Guest', isBold: true),
                              const SizedBox(height: 6),
                              _buildTotalRow('Issued By (Host)', rec['issued_by_name'] ?? (_orgProfile?['name'] ?? 'Host')),
                              const SizedBox(height: 6),
                              _buildTotalRow('Currency', rec['currency'] ?? 'KES'),
                              const Divider(height: 16),
                              _buildTotalRow('Remaining Balance Due', GinataFormatters.formatKES(rec['remaining_balance']), isLarge: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Footer Thank You Note
                        Center(
                          child: Column(
                            children: [
                              const Text('Official Verification & Financial Audit Record', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GinataColors.secondary)),
                              SizedBox(height: 2),
                              Text('Thank you for choosing ${_orgProfile?['name'] ?? 'Ginata Luxury Accommodations'}.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: GinataColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveInvoicePreviewContent(Map<String, dynamic> inv) {
    final docType = (inv['document_type'] ?? 'invoice').toString();
    final docTitle = docType == 'pro_forma' ? 'PRO FORMA INVOICE' : docType == 'quotation' ? 'PRICE QUOTATION' : 'DIRECT STAY INVOICE';
    final lineItems = (inv['line_items'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Document Top Header with Logo (NO KRA PIN)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/images/logo.png', height: 40, errorBuilder: (context, error, stackTrace) => const Icon(Icons.villa, color: GinataColors.primary, size: 36)),
                  const SizedBox(height: 6),
                  Text(inv['supplier_name'] ?? (_orgProfile?['name']?.isNotEmpty == true ? _orgProfile!['name'] : 'Ginata Host'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                  Text(inv['supplier_address'] ?? (_orgProfile?['address']?.isNotEmpty == true ? _orgProfile!['address'] : 'Nairobi, Kenya'), style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                  if ((inv['supplier_email'] ?? _orgProfile?['email']) != null && (inv['supplier_email'] ?? _orgProfile?['email']).toString().isNotEmpty)
                    Text(inv['supplier_email'] ?? _orgProfile!['email'], style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(docTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                const SizedBox(height: 4),
                Text('Invoice No: ${inv['invoice_number']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GinataColors.secondary)),
                Text('Date: ${inv['issue_date']}', style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                Text('Due: ${inv['due_date']}', style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: GinataColors.secondaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    (inv['status'] ?? 'draft').toString().toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: GinataColors.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(color: GinataColors.surfaceContainerHigh),
        const SizedBox(height: 12),

        // Billing Details (Personal & Optional Company)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: GinataColors.surfaceSubdued, borderRadius: BorderRadius.circular(10)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BILLED TO (GUEST):', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GinataColors.secondary)),
                    const SizedBox(height: 2),
                    Text(inv['billing_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GinataColors.textPrimary)),
                    if (inv['billing_email'] != null) Text(inv['billing_email'], style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                    if (inv['billing_phone'] != null) Text(inv['billing_phone'], style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                  ],
                ),
              ),
              if (inv['billing_company_name'] != null) ...[
                Container(width: 1, height: 50, color: GinataColors.outlineVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('COMPANY BILLING IDENTIFIERS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GinataColors.secondary)),
                      const SizedBox(height: 2),
                      Text(inv['billing_company_name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                      if (inv['billing_company_address'] != null) Text(inv['billing_company_address'], style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Itemized Line Items Table
        Table(
          columnWidths: const {
            0: FlexColumnWidth(4),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
          },
          border: TableBorder.all(color: GinataColors.surfaceContainerHigh, width: 0.5),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: GinataColors.primary),
              children: const [
                Padding(padding: EdgeInsets.all(8), child: Text('Description', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(8), child: Text('Qty', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(8), child: Text('Unit Price', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(8), child: Text('Total (KES)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              ],
            ),
            ...lineItems.map((li) => TableRow(
              children: [
                Padding(padding: const EdgeInsets.all(8), child: Text(li['description'] ?? '', style: const TextStyle(fontSize: 11))),
                Padding(padding: const EdgeInsets.all(8), child: Text(li['quantity']?.toString() ?? '1', style: const TextStyle(fontSize: 11))),
                Padding(padding: const EdgeInsets.all(8), child: Text(GinataFormatters.formatKES(li['unit_price']), style: const TextStyle(fontSize: 11))),
                Padding(padding: const EdgeInsets.all(8), child: Text(GinataFormatters.formatKES(li['total_amount']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              ],
            )),
          ],
        ),
        const SizedBox(height: 16),

        // Financial Totals Alignment
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Column(
              children: [
                _buildTotalRow('Subtotal', GinataFormatters.formatKES(inv['subtotal'])),
                _buildTotalRow('Taxes (0.00% VAT)', GinataFormatters.formatKES(inv['tax_total'])),
                if ((double.tryParse(inv['discount_total'].toString()) ?? 0) > 0)
                  _buildTotalRow('Discount', '-${GinataFormatters.formatKES(inv['discount_total'])}'),
                const Divider(),
                _buildTotalRow('Grand Total', GinataFormatters.formatKES(inv['grand_total']), isBold: true),
                _buildTotalRow('Payments Received', GinataFormatters.formatKES(inv['amount_paid'])),
                const SizedBox(height: 4),
                _buildTotalRow('Balance Due', GinataFormatters.formatKES(inv['balance_due']), isLarge: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Payment Instructions Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: GinataColors.surfaceSubdued, borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PAYMENT INSTRUCTIONS & BANK DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GinataColors.secondary)),
              const SizedBox(height: 4),
              Text(
                inv['payment_instructions'] ?? (_orgProfile?['payment_instructions']?.isNotEmpty == true ? _orgProfile!['payment_instructions'] : 'Contact host for payment details'),
                style: const TextStyle(fontSize: 11, color: GinataColors.textPrimary),
              ),
              if (inv['notes'] != null) ...[
                const SizedBox(height: 6),
                Text('Notes: ${inv['notes']}', style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: isLarge ? 13 : 11, fontWeight: isBold || isLarge ? FontWeight.bold : FontWeight.normal, color: GinataColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: isLarge ? 14 : 11, fontWeight: isBold || isLarge ? FontWeight.bold : FontWeight.normal, color: isLarge ? GinataColors.primary : GinataColors.textPrimary)),
        ],
      ),
    );
  }
}
