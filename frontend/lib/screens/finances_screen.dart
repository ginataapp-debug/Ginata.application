import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/ginata_theme.dart';

class FinancesScreen extends StatefulWidget {
  const FinancesScreen({super.key});

  @override
  State<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends State<FinancesScreen> {
  bool _loading = true;
  List<dynamic> _properties = [];
  List<dynamic> _expenses = [];
  Map<String, dynamic> _summary = {};
  String? _selectedPropertyId;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Maintenance',
    'Utilities',
    'Cleaning',
    'Supplies',
    'Staff',
    'HOA & Security',
    'Wifi & Tech',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final props = await ApiService.fetchProperties();
      final summary = await ApiService.fetchFinancialSummary(propertyId: _selectedPropertyId);
      final expenses = await ApiService.fetchExpenses(
        propertyId: _selectedPropertyId,
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      );

      if (mounted) {
        setState(() {
          _properties = props;
          _summary = summary;
          _expenses = expenses;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openRecordExpenseModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RecordExpenseDialog(
        properties: _properties,
        onCreated: () {
          Navigator.of(ctx).pop();
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense successfully recorded!'),
              backgroundColor: GinataColors.primary,
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteExpense(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense Record?'),
        content: const Text('This will remove this expense record and update property accounting.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GinataColors.alertTerracotta),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteExpense(id);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting expense: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GinataColors.background,
      appBar: AppBar(
        title: const Text(
          'Finances & Expenses',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: GinataColors.primary),
            onPressed: _loadData,
            tooltip: 'Refresh Ledger',
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: GinataColors.primary),
            onPressed: () {
              final exportUrl = '${ApiService.baseUrl}/finances/expenses/export';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Expenses exported! $exportUrl'),
                  backgroundColor: GinataColors.primary,
                ),
              );
            },
            tooltip: 'Export CSV',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _openRecordExpenseModal,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Expense', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: GinataColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GinataColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: GinataColors.primary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Overview Banner
                    _buildOverviewCards(),
                    const SizedBox(height: 24),

                    // Filter Toolbar
                    _buildFilters(),
                    const SizedBox(height: 16),

                    // Property-Level Breakdown (if All is selected)
                    if (_selectedPropertyId == null && _properties.isNotEmpty) ...[
                      const Text(
                        'House Financial Profiles',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GinataColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      _buildPropertyCardsList(),
                      const SizedBox(height: 24),
                    ],

                    // Expenses Ledger Table / Cards
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expense Ledger (${_expenses.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GinataColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '0.00% VAT - Direct Rates (No KRA Tax)',
                          style: TextStyle(fontSize: 11, color: GinataColors.textSecondary.withValues(alpha: 0.8), fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_expenses.isEmpty)
                      _buildEmptyLedger()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _expenses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _buildExpenseItemCard(_expenses[i]),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    final gross = (_summary['gross_revenue'] ?? 0.0).toDouble();
    final commissions = (_summary['total_agent_commissions'] ?? 0.0).toDouble();
    final expenses = (_summary['total_expenses'] ?? 0.0).toDouble();
    final netProfit = (_summary['net_operating_profit'] ?? 0.0).toDouble();
    final collected = (_summary['collected_revenue'] ?? 0.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Net Host Profit', style: TextStyle(fontSize: 12, color: GinataColors.textSecondary, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            GinataFormatters.formatKES(netProfit),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: netProfit >= 0 ? GinataColors.primary : GinataColors.alertTerracotta,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: GinataColors.secondaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: GinataColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Cash: ${GinataFormatters.formatKES(collected)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GinataColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Gross Bookings',
                  amount: gross,
                  color: GinataColors.textPrimary,
                  icon: Icons.trending_up,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(
                child: _buildMetricTile(
                  label: 'Agent Commissions',
                  amount: commissions,
                  color: Colors.deepPurple,
                  icon: Icons.handshake_outlined,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(
                child: _buildMetricTile(
                  label: 'House Expenses',
                  amount: expenses,
                  color: GinataColors.alertTerracotta,
                  icon: Icons.receipt_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({required String label, required double amount, required Color color, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            GinataFormatters.formatKES(amount),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Property Dropdown
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedPropertyId,
              isExpanded: true,
              hint: const Text('All Properties', style: TextStyle(fontSize: 13, color: GinataColors.textPrimary)),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Properties', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                ..._properties.map((p) => DropdownMenuItem<String?>(
                      value: p['id'].toString(),
                      child: Text(p['name'] ?? 'House', style: const TextStyle(fontSize: 13)),
                    )),
              ],
              onChanged: (val) {
                setState(() => _selectedPropertyId = val);
                _loadData();
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Category Chips / Scrollable
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : GinataColors.textPrimary)),
                selected: isSelected,
                selectedColor: GinataColors.primary,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: isSelected ? GinataColors.primary : Colors.grey.shade300),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedCategory = cat);
                    _loadData();
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyCardsList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
          ),
          itemCount: _properties.length,
          itemBuilder: (ctx, i) {
            final p = _properties[i];
            return InkWell(
              onTap: () {
                setState(() => _selectedPropertyId = p['id'].toString());
                _loadData();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: GinataColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.home, size: 16, color: GinataColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p['name'] ?? 'Property',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: GinataColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rate: ${GinataFormatters.formatKES(p['base_rate_night'] ?? 0)}/night',
                          style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary),
                        ),
                        Row(
                          children: [
                            const Text('Filter Ledger', style: TextStyle(fontSize: 11, color: GinataColors.primary, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 2),
                            const Icon(Icons.chevron_right, size: 14, color: GinataColors.primary),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExpenseItemCard(Map<String, dynamic> item) {
    final amount = (item['amount'] ?? 0.0).toDouble();
    final category = item['category'] ?? 'General';
    final vendor = item['vendor_name'] ?? '';
    final ref = item['receipt_reference'] ?? '';
    final date = item['expense_date'] ?? '';
    final propName = item['property_name'] ?? 'Property';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GinataColors.alertTerracotta.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getCategoryIcon(category), size: 20, color: GinataColors.alertTerracotta),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] ?? 'Expense',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GinataColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: GinataColors.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.domain, size: 12, color: GinataColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(propName, style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (vendor.isNotEmpty)
                      Text('- Vendor: $vendor', style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                    if (ref.isNotEmpty)
                      Text('- Ref: $ref', style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                  ],
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Date: $date', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '- ${GinataFormatters.formatKES(amount)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: GinataColors.alertTerracotta),
              ),
              const SizedBox(height: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                onPressed: () => _deleteExpense(item['id'].toString()),
                tooltip: 'Delete Expense',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'maintenance':
        return Icons.build_outlined;
      case 'utilities':
        return Icons.bolt_outlined;
      case 'cleaning':
        return Icons.cleaning_services_outlined;
      case 'supplies':
        return Icons.inventory_2_outlined;
      case 'staff':
        return Icons.people_outline;
      case 'hoa & security':
        return Icons.shield_outlined;
      case 'wifi & tech':
        return Icons.wifi;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Widget _buildEmptyLedger() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No expenses recorded yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: GinataColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Track maintenance, fundi fees, electricity, water, and staff payouts for each house.',
            style: TextStyle(fontSize: 13, color: GinataColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openRecordExpenseModal,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Record First Expense'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GinataColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordExpenseDialog extends StatefulWidget {
  final List<dynamic> properties;
  final VoidCallback onCreated;

  const _RecordExpenseDialog({required this.properties, required this.onCreated});

  @override
  State<_RecordExpenseDialog> createState() => _RecordExpenseDialogState();
}

class _RecordExpenseDialogState extends State<_RecordExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _propertyId;
  String _category = 'Maintenance';
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _vendorController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  final DateTime _expenseDate = DateTime.now();
  String _paymentMethod = 'M-Pesa';
  bool _submitting = false;

  final List<String> _categories = [
    'Maintenance',
    'Utilities',
    'Cleaning',
    'Supplies',
    'Staff',
    'HOA & Security',
    'Wifi & Tech',
    'Other',
  ];

  final List<String> _paymentMethods = [
    'M-Pesa',
    'Bank Transfer',
    'Cash',
    'Card',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.properties.isNotEmpty) {
      _propertyId = widget.properties.first['id'].toString();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_propertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a property')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      await ApiService.createExpense({
        'property_id': _propertyId,
        'title': _titleController.text.trim(),
        'category': _category,
        'amount': amount,
        'currency': 'KES',
        'expense_date': _expenseDate.toIso8601String().split('T').first,
        'vendor_name': _vendorController.text.trim().isEmpty ? null : _vendorController.text.trim(),
        'receipt_reference': _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
        'payment_method': _paymentMethod,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      });
      widget.onCreated();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record expense: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                      const Text(
                        'Record House Expense',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: GinataColors.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Property Picker
                  const Text('Property / House *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _propertyId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: widget.properties.map<DropdownMenuItem<String>>((p) {
                      return DropdownMenuItem<String>(
                        value: p['id'].toString(),
                        child: Text(p['name'] ?? 'House'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _propertyId = val),
                  ),
                  const SizedBox(height: 14),

                  // Category & Amount
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _category,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (val) => setState(() => _category = val ?? _category),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Amount (KES) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                prefixText: 'KES ',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title
                  const Text('Expense Description *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Master Bedroom AC repair & gas refill',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter expense description' : null,
                  ),
                  const SizedBox(height: 14),

                  // Vendor & Payment Method
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fundi / Vendor Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _vendorController,
                              decoration: InputDecoration(
                                hintText: 'e.g. Fundi Peter',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _paymentMethod,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (val) => setState(() => _paymentMethod = val ?? _paymentMethod),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Receipt Reference
                  const Text('Receipt / M-Pesa Reference', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _referenceController,
                    decoration: InputDecoration(
                      hintText: 'e.g. MPESA QWE492 or Invoice #104',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GinataColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _submitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save Expense'),
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
}
