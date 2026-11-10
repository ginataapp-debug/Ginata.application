import 'package:flutter/material.dart';
import '../theme/ginata_theme.dart';
import '../services/api_service.dart';
import '../widgets/pdf_viewer.dart';

class TemplateSettingsScreen extends StatefulWidget {
  const TemplateSettingsScreen({super.key});

  @override
  State<TemplateSettingsScreen> createState() => _TemplateSettingsScreenState();
}

const List<List<String>> _colorPresets = [
  ['Forest & Sage', '#003329', '#466557'],
  ['Midnight & Brass', '#101828', '#B89758'],
  ['Deep Teal & Gold', '#0B3D2E', '#B89758'],
  ['Charcoal & Terracotta', '#1C1C18', '#D92D20'],
  ['Navy & Steel', '#1D2939', '#475467'],
];

const Map<String, String> _layoutLabels = {
  'minimalist_luxury': 'Minimalist Luxury (Default)',
  'classic_monograph': 'Classic Monograph',
  'modern_corporate': 'Modern Corporate',
};

const Map<String, String> _fontLabels = {
  'Plus Jakarta Sans': 'Helvetica · Sans (Default)',
  'Helvetica / Arial': 'Helvetica · Sans',
  'Playfair Display': 'Times · Serif',
  'Courier': 'Courier · Monospace',
};

Color _hexToColor(String hex, Color fallback) {
  try {
    var s = hex.trim().replaceFirst('#', '');
    if (s.length == 6) s = 'FF$s';
    return Color(int.parse(s, radix: 16));
  } catch (_) {
    return fallback;
  }
}

class _TemplateSettingsScreenState extends State<TemplateSettingsScreen> {
  final _businessNameCtrl = TextEditingController(text: '');
  final _emailCtrl = TextEditingController(text: '');
  final _phoneCtrl = TextEditingController(text: '');
  final _addressCtrl = TextEditingController(text: '');
  final _cityCtrl = TextEditingController(text: 'Nairobi');
  final _countryCtrl = TextEditingController(text: 'Kenya');

  final _paymentInstructionsCtrl = TextEditingController(text: '');
  final _taxNotesCtrl = TextEditingController(
    text: 'Tax amounts are itemized where applicable.',
  );
  final _footerTextCtrl = TextEditingController(
    text: 'Thank you for staying with us.',
  );

  String _layoutStyle = 'minimalist_luxury';
  String _fontFamily = 'Plus Jakarta Sans';
  String _primaryColor = '#003329';
  String _secondaryColor = '#466557';
  String? _templateId;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isApplying = false;
  bool _isPreviewing = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _businessNameCtrl,
      _taxNotesCtrl,
      _footerTextCtrl,
      _paymentInstructionsCtrl,
    ]) {
      controller.addListener(() {
        if (mounted && !_isLoading) setState(() {});
      });
    }
    _loadProfileAndTemplate();
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _paymentInstructionsCtrl.dispose();
    _taxNotesCtrl.dispose();
    _footerTextCtrl.dispose();
    super.dispose();
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
        final tpl = templates.firstWhere(
          (t) => t['is_default'] == true,
          orElse: () => templates.first,
        );
        _templateId = tpl['id']?.toString();
        _layoutStyle = (tpl['layout_style'] ?? _layoutStyle).toString();
        _fontFamily = (tpl['font_family'] ?? _fontFamily).toString();
        _primaryColor = (tpl['primary_color'] ?? _primaryColor).toString();
        _secondaryColor = (tpl['secondary_color'] ?? _secondaryColor)
            .toString();
        if (tpl['payment_instructions'] != null &&
            tpl['payment_instructions'].toString().isNotEmpty) {
          _paymentInstructionsCtrl.text = tpl['payment_instructions'];
        }
        if (tpl['tax_notes'] != null &&
            tpl['tax_notes'].toString().isNotEmpty) {
          _taxNotesCtrl.text = tpl['tax_notes'];
        }
        if (tpl['footer_text'] != null &&
            tpl['footer_text'].toString().isNotEmpty) {
          _footerTextCtrl.text = tpl['footer_text'];
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _templatePayload() => {
    'is_default': true,
    'layout_style': _layoutStyle,
    'font_family': _fontFamily,
    'primary_color': _primaryColor,
    'secondary_color': _secondaryColor,
    'payment_instructions': _paymentInstructionsCtrl.text.trim(),
    'tax_notes': _taxNotesCtrl.text.trim(),
    'footer_text': _footerTextCtrl.text.trim(),
    'header_text': _businessNameCtrl.text.trim(),
  };

  Future<bool> _saveSettings() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.updateOrganization({
        'name': _businessNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        'currency': 'KES',
      });

      final payload = _templatePayload();
      if (_templateId != null) {
        await ApiService.updateTemplate(_templateId!, payload);
      } else {
        final created = await ApiService.createTemplate({
          ...payload,
          'name': 'Host Document Template',
          'is_default': true,
        });
        _templateId = created['id']?.toString();
      }

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Host profile and document design saved.'),
            backgroundColor: GinataColors.primary,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: GinataColors.alertTerracotta,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _previewPdf() async {
    setState(() => _isPreviewing = true);
    try {
      final bytes = await ApiService.previewDocumentTemplate(
        _templatePayload(),
      );
      if (!mounted) return;
      await openPdfViewer(
        context,
        title: 'Document Design Preview',
        fileName: 'design_preview.pdf',
        bytes: bytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Preview failed: $e')));
    } finally {
      if (mounted) setState(() => _isPreviewing = false);
    }
  }

  Future<void> _applyToDocuments() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply to existing documents?'),
        content: const Text(
          'This re-renders every archived invoice and receipt PDF with the current '
          'layout, typography and colors. New documents will use this design too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GinataColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply Design'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _isApplying = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await _saveSettings() || !mounted) return;
      final result = await ApiService.applyTemplateToDocuments(_templateId!);
      if (!mounted) return;
      final count = result['documents_regenerated'] ?? 0;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Design applied — $count archived document${count == 1 ? '' : 's'} regenerated.',
          ),
          backgroundColor: GinataColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not apply design: $e'),
          backgroundColor: GinataColors.alertTerracotta,
        ),
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GinataColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Host Profile & Brand Studio',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: GinataColors.primary),
            tooltip: 'Reload',
            onPressed: _loadProfileAndTemplate,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GinataColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check, size: 16),
              label: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _isSaving || _isApplying ? null : _saveSettings,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GinataColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                _buildBrandCard(),
                const SizedBox(height: 16),
                _buildPreviewCard(),
                const SizedBox(height: 16),
                _buildHostProfileCard(),
                const SizedBox(height: 16),
                _buildDocumentDesignCard(),
                const SizedBox(height: 16),
                _buildApplyCard(),
              ],
            ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GinataColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14174A3F)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: GinataColors.secondary,
      ),
    );
  }

  Widget _buildBrandCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('OFFICIAL LOGO & BRAND IDENTITY'),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 120,
                height: 60,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GinataColors.surfaceSubdued,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GinataColors.surfaceContainerHigh),
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/logo.png',
                  errorBuilder: (context, error, stack) => const Text(
                    'Ginata',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: GinataColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Official Ginata Brand Mark',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: GinataColors.primary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Applied automatically across guest portals, PDF invoices and receipts.',
                      style: TextStyle(
                        fontSize: 11,
                        color: GinataColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? get _previewFontFamily {
    final f = _fontFamily.toLowerCase();
    if (f.contains('playfair') || f.contains('serif') || f.contains('times')) {
      return 'serif';
    }
    if (f.contains('courier') || f.contains('mono')) return 'monospace';
    return null;
  }

  Widget _buildPreviewCard() {
    final primary = _hexToColor(_primaryColor, GinataColors.primary);
    final secondary = _hexToColor(_secondaryColor, GinataColors.secondary);
    final business = _businessNameCtrl.text.trim().isEmpty
        ? 'Your Business Name'
        : _businessNameCtrl.text.trim();

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _sectionLabel('LIVE DOCUMENT PREVIEW')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _layoutLabels[_layoutStyle] ?? 'Custom',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Typography: ${_fontLabels[_fontFamily] ?? _fontFamily}',
            style: const TextStyle(fontSize: 10, color: GinataColors.textMuted),
          ),
          const SizedBox(height: 12),
          _buildPaperPreview(business, primary, secondary),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isPreviewing ? null : _previewPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(
              _isPreviewing ? 'Preparing PDF...' : 'Open actual PDF preview',
            ),
          ),
          const Text(
            'Sample figures only. The PDF preview shows the exact printed typography.',
            style: TextStyle(fontSize: 10, color: GinataColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperPreview(String business, Color primary, Color secondary) {
    final ff = _previewFontFamily;
    TextStyle h(double size, {FontWeight w = FontWeight.bold, Color? c}) =>
        TextStyle(
          fontFamily: ff,
          fontSize: size,
          fontWeight: w,
          color: c ?? primary,
        );
    TextStyle b(
      double size, {
      Color? c,
      FontStyle s = FontStyle.normal,
      FontWeight w = FontWeight.normal,
    }) => TextStyle(
      fontFamily: ff,
      fontSize: size,
      color: c ?? GinataColors.textSecondary,
      fontStyle: s,
      fontWeight: w,
    );

    Widget header;
    if (_layoutStyle == 'modern_corporate') {
      header = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                business,
                style: h(12, c: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('INVOICE', style: h(11, c: Colors.white)),
                Text('No: INV-0001', style: b(8, c: Colors.white70)),
              ],
            ),
          ],
        ),
      );
    } else if (_layoutStyle == 'classic_monograph') {
      header = Column(
        children: [
          Text(business, style: h(13), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(
            'INVOICE',
            style: b(10, c: secondary, w: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text('No: INV-0001  ·  09 Nov 2026', style: b(8)),
          const SizedBox(height: 6),
          Container(height: 2, color: primary),
          const SizedBox(height: 2),
          Container(height: 0.7, color: secondary),
        ],
      );
    } else {
      header = Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  business,
                  style: h(12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('INVOICE', style: h(11)),
                  Text(
                    'No: INV-0001',
                    style: b(8, c: secondary, w: FontWeight.bold),
                  ),
                  Text('09 Nov 2026', style: b(8)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(
            height: 1,
            thickness: 0.7,
            color: GinataColors.outlineVariant,
          ),
        ],
      );
    }

    final tableHeaderFilled = _layoutStyle != 'classic_monograph';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GinataColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ISSUED BY',
                      style: b(7.5, c: secondary, w: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      business,
                      style: b(
                        8.5,
                        c: GinataColors.textPrimary,
                        w: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('Nairobi, Kenya', style: b(8)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BILLED TO',
                      style: b(7.5, c: secondary, w: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Amina Kariuki',
                      style: b(
                        8.5,
                        c: GinataColors.textPrimary,
                        w: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'amina.k@example.com',
                      style: b(8),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildItemsTable(primary, tableHeaderFilled, ff),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Balance Due', style: h(10)),
              Text('KES 103,000', style: h(11)),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 0.7, color: GinataColors.outlineVariant),
          const SizedBox(height: 6),
          Text(
            _taxNotesCtrl.text.trim().isEmpty
                ? '0.00% VAT - Direct Rates'
                : _taxNotesCtrl.text.trim(),
            style: b(7.5, s: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(Color primary, bool filled, String? ff) {
    final headTextColor = filled ? Colors.white : primary;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: GinataColors.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: filled ? primary : Colors.transparent,
              border: filled
                  ? null
                  : const Border(
                      bottom: BorderSide(color: GinataColors.outlineVariant),
                    ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'Description',
                    style: TextStyle(
                      fontFamily: ff,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: headTextColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Qty',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: ff,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: headTextColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: ff,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: headTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _previewRow('Accommodation · 4 nights', '4', 'KES 100,000', ff),
          _previewRow('Cleaning & turnover', '1', 'KES 4,000', ff, alt: true),
          _previewRow('Stay discount', '1', '-KES 1,000', ff),
        ],
      ),
    );
  }

  Widget _previewRow(
    String desc,
    String qty,
    String total,
    String? ff, {
    bool alt = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: alt ? GinataColors.surfaceSubdued : Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              desc,
              style: TextStyle(
                fontFamily: ff,
                fontSize: 8.5,
                color: GinataColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              qty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: ff,
                fontSize: 8.5,
                color: GinataColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              total,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: ff,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: GinataColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostProfileCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _sectionLabel('HOST PROFILE & BUSINESS DETAILS')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: GinataColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'KES PRIMARY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: GinataColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _businessNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Host / Legal Entity Name *',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Host Contact Email *',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Host Phone / Concierge *',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Physical / Postal Address',
            ),
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
    );
  }

  Widget _buildDocumentDesignCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('DOCUMENT DESIGN & PAYMENT INSTRUCTIONS'),
          TextButton.icon(
            onPressed: () => setState(() {
              _layoutStyle = 'minimalist_luxury';
              _fontFamily = 'Plus Jakarta Sans';
              _primaryColor = '#003329';
              _secondaryColor = '#466557';
            }),
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Restore original design'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey('layout-$_layoutStyle'),
            initialValue: _layoutStyle,
            decoration: const InputDecoration(labelText: 'Document Layout'),
            items: _layoutLabels.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: (v) =>
                setState(() => _layoutStyle = v ?? 'minimalist_luxury'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey('font-$_fontFamily'),
            initialValue: _fontFamily,
            decoration: const InputDecoration(labelText: 'Typography'),
            items: _fontLabels.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: (v) =>
                setState(() => _fontFamily = v ?? 'Plus Jakarta Sans'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Brand Colors',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _colorPresets.map((preset) {
              final name = preset[0];
              final p = preset[1];
              final s = preset[2];
              final selected =
                  _primaryColor.toLowerCase() == p.toLowerCase() &&
                  _secondaryColor.toLowerCase() == s.toLowerCase();
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() {
                  _primaryColor = p;
                  _secondaryColor = s;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? GinataColors.secondaryContainer.withValues(alpha: 0.5)
                        : GinataColors.surfaceSubdued,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? GinataColors.primary
                          : GinataColors.outlineVariant,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _hexToColor(p, GinataColors.primary),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _hexToColor(s, GinataColors.secondary),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: GinataColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _paymentInstructionsCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Payment Instructions (M-Pesa Paybill / Bank Wire) *',
              hintText: 'e.g. M-Pesa Paybill 247247, Acc GINATA-STAY',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _taxNotesCtrl,
            decoration: const InputDecoration(
              labelText: 'Tax Notes & Legal Disclaimer',
              hintText: '0.00% VAT - Direct Rates',
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
    );
  }

  Widget _buildApplyCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('APPLY DESIGN'),
          const SizedBox(height: 6),
          const Text(
            'Save this design and refresh every archived invoice and receipt PDF. Financial amounts are unchanged.',
            style: TextStyle(fontSize: 12, color: GinataColors.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isApplying || _isSaving ? null : _applyToDocuments,
              style: ElevatedButton.styleFrom(
                backgroundColor: GinataColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _isApplying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                _isApplying
                    ? 'Applying...'
                    : 'Apply to Current Invoices & Receipts',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
