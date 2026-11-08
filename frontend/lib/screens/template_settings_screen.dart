import 'package:flutter/material.dart';
import '../theme/ginata_theme.dart';
import '../services/api_service.dart';

class TemplateSettingsScreen extends StatefulWidget {
  const TemplateSettingsScreen({super.key});

  @override
  State<TemplateSettingsScreen> createState() => _TemplateSettingsScreenState();
}

class _TemplateSettingsScreenState extends State<TemplateSettingsScreen> {
  // Host profile controllers
  final _businessNameCtrl = TextEditingController(text: '');
  final _emailCtrl = TextEditingController(text: '');
  final _phoneCtrl = TextEditingController(text: '');
  final _addressCtrl = TextEditingController(text: '');
  final _cityCtrl = TextEditingController(text: 'Nairobi');
  final _countryCtrl = TextEditingController(text: 'Kenya');

  // Document template controllers
  final _paymentInstructionsCtrl = TextEditingController(text: '');
  final _taxNotesCtrl = TextEditingController(
    text: '0.00% VAT - Direct Rates (No KRA Tax)',
  );
  final _footerTextCtrl = TextEditingController(
    text: 'Thank you for staying with us.',
  );

  String _layoutStyle = 'minimalist_luxury';
  String _fontFamily = 'Plus Jakarta Sans';
  String? _templateId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfileAndTemplate();
  }

  Future<void> _loadProfileAndTemplate() async {
    setState(() => _isLoading = true);
    try {
      final org = await ApiService.fetchOrganization();
      if (org != null) {
        _businessNameCtrl.text = org['name'] ?? _businessNameCtrl.text;
        _emailCtrl.text = org['email'] ?? _emailCtrl.text;
        _phoneCtrl.text = org['phone'] ?? _phoneCtrl.text;
        _addressCtrl.text = org['address'] ?? _addressCtrl.text;
        _cityCtrl.text = org['city'] ?? _cityCtrl.text;
        _countryCtrl.text = org['country'] ?? _countryCtrl.text;
      }

      final templates = await ApiService.fetchTemplates();
      if (templates.isNotEmpty) {
        final tpl = templates.first;
        _templateId = tpl['id']?.toString();
        _layoutStyle = tpl['layout_style'] ?? _layoutStyle;
        _fontFamily = tpl['font_family'] ?? _fontFamily;
        if (tpl['payment_instructions'] != null && tpl['payment_instructions'].toString().isNotEmpty) {
          _paymentInstructionsCtrl.text = tpl['payment_instructions'];
        }
        if (tpl['tax_notes'] != null && tpl['tax_notes'].toString().isNotEmpty) {
          _taxNotesCtrl.text = tpl['tax_notes'];
        }
        if (tpl['footer_text'] != null && tpl['footer_text'].toString().isNotEmpty) {
          _footerTextCtrl.text = tpl['footer_text'];
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 1. Update Organization Profile
      await ApiService.updateOrganization({
        'name': _businessNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        'currency': 'KES',
      });

      // 2. Update Template if available
      if (_templateId != null) {
        await ApiService.updateTemplate(_templateId!, {
          'layout_style': _layoutStyle,
          'font_family': _fontFamily,
          'payment_instructions': _paymentInstructionsCtrl.text.trim(),
          'tax_notes': _taxNotesCtrl.text.trim(),
          'footer_text': _footerTextCtrl.text.trim(),
          'header_text': _businessNameCtrl.text.trim(),
        });
      }

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Host profile and document templates saved successfully!'),
            backgroundColor: GinataColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: GinataColors.alertTerracotta,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Profile & Brand Studio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _loadProfileAndTemplate,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GinataColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check, size: 16),
              label: Text(_isSaving ? 'Saving...' : 'Save', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: _isSaving ? null : _saveSettings,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: GinataColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                // Logo & Official Brand Mark Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: GinataColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x14174A3F)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('OFFICIAL LOGO & BRAND IDENTITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: GinataColors.secondary)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 140,
                            height: 64,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: GinataColors.surfaceSubdued,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: GinataColors.surfaceContainerHigh),
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/images/logo.png',
                              errorBuilder: (context, error, stack) => const Text('Ginata', style: TextStyle(fontWeight: FontWeight.bold, color: GinataColors.primary)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Official Ginata Brand Mark', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                                const SizedBox(height: 2),
                                const Text('Preserved and applied automatically across guest portals, PDF invoices, and receipts.', style: TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: GinataColors.secondaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Design System: Forest Green, Sage & Warm Cream (KES)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Host Business & Profile Information
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: GinataColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x14174A3F)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('HOST PROFILE & BUSINESS DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: GinataColors.secondary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: GinataColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('KES PRIMARY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _businessNameCtrl,
                        decoration: const InputDecoration(labelText: 'Host / Legal Entity Name *'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Host Contact Email *'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Host Phone / Concierge *'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(labelText: 'Physical / Postal Address'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cityCtrl,
                        decoration: const InputDecoration(labelText: 'City *'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _countryCtrl,
                        decoration: const InputDecoration(labelText: 'Country *'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Template Formatting & Payment Instructions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: GinataColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x14174A3F)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FINANCIAL DOCUMENTS & PAYMENT INSTRUCTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: GinataColors.secondary)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _layoutStyle,
                        decoration: const InputDecoration(labelText: 'Document Layout'),
                        items: const [
                          DropdownMenuItem(value: 'minimalist_luxury', child: Text('Minimalist Luxury (Default)')),
                          DropdownMenuItem(value: 'classic_monograph', child: Text('Classic Monograph')),
                          DropdownMenuItem(value: 'modern_corporate', child: Text('Modern Corporate')),
                        ],
                        onChanged: (v) => setState(() => _layoutStyle = v ?? 'minimalist_luxury'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _fontFamily,
                        decoration: const InputDecoration(labelText: 'Typography'),
                        items: const [
                          DropdownMenuItem(value: 'Plus Jakarta Sans', child: Text('Plus Jakarta Sans')),
                          DropdownMenuItem(value: 'Playfair Display', child: Text('Playfair Display')),
                          DropdownMenuItem(value: 'Helvetica / Arial', child: Text('Helvetica / Arial')),
                        ],
                        onChanged: (v) => setState(() => _fontFamily = v ?? 'Plus Jakarta Sans'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _paymentInstructionsCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Payment Instructions (M-Pesa Paybill / Bank Wire) *',
                          hintText: 'e.g. M-Pesa Till / Paybill or Bank Wire...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _taxNotesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tax Notes & Legal Disclaimer',
                          hintText: 'VAT 16% inclusive',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _footerTextCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Document Footer Message',
                          hintText: 'Thank you for staying with Ginata.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
