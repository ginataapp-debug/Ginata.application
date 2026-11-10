import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/ginata_theme.dart';

/// Message Template Studio — a library of pre-built guest messages a host can
/// create, edit, personalise (fill in {{variables}}), and copy to paste straight
/// into Airbnb, Booking.com, WhatsApp, SMS or email.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

// --- shared helpers --------------------------------------------------------
const List<List<String>> _kCategories = [
  ['all', 'All'],
  ['airbnb', 'Airbnb'],
  ['booking_com', 'Booking.com'],
  ['whatsapp', 'WhatsApp'],
  ['sms', 'SMS'],
  ['email', 'Email'],
  ['general', 'General'],
];

final RegExp _varRegex = RegExp(r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}');

List<String> _extractVars(String body) {
  final seen = <String>[];
  for (final m in _varRegex.allMatches(body)) {
    final k = (m.group(1) ?? '').trim();
    if (k.isNotEmpty && !seen.contains(k)) seen.add(k);
  }
  return seen;
}

Color _categoryColor(String cat) {
  switch (cat.toLowerCase()) {
    case 'airbnb':
      return const Color(0xFFFF5A5F);
    case 'booking_com':
      return const Color(0xFF003580);
    case 'whatsapp':
      return const Color(0xFF25D366);
    case 'sms':
      return Colors.teal;
    case 'email':
      return const Color(0xFF7C3AED);
    default:
      return GinataColors.secondary;
  }
}

IconData _categoryIcon(String cat) {
  switch (cat.toLowerCase()) {
    case 'airbnb':
      return Icons.home_work_outlined;
    case 'booking_com':
      return Icons.hotel;
    case 'whatsapp':
      return Icons.chat;
    case 'sms':
      return Icons.sms_outlined;
    case 'email':
      return Icons.mail_outline;
    default:
      return Icons.campaign_outlined;
  }
}

String _categoryLabel(String cat) {
  for (final c in _kCategories) {
    if (c[0] == cat.toLowerCase()) return c[1];
  }
  return cat.isEmpty ? 'General' : cat[0].toUpperCase() + cat.substring(1);
}

const Map<String, String> _varLabels = {
  'guest_name': 'Guest name',
  'property': 'Property name',
  'check_in': 'Check-in date',
  'check_out': 'Check-out date',
  'check_in_time': 'Check-in time',
  'check_out_time': 'Check-out time',
  'nights': 'Number of nights',
  'guests': 'Number of guests',
  'host_name': 'Your name',
  'address': 'Property address',
  'door_code': 'Door / gate code',
  'wifi_name': 'WiFi network',
  'wifi_password': 'WiFi password',
  'bin_day': 'Bin collection day',
  'pets_allowed': 'Pets policy',
  'balance_due': 'Balance due',
  'due_date': 'Payment due date',
  'mpesa_number': 'M-Pesa number',
};

String _humanizeVar(String key) {
  final known = _varLabels[key];
  if (known != null) return known;
  final words = key.replaceAll('_', ' ').split(' ');
  return words.map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _templates = [];
  String _categoryFilter = 'all';
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.fetchMessageTemplates();
      if (mounted) {
        setState(() {
          _templates = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _varsOf(Map<String, dynamic> t) {
    final raw = t['variables'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return _extractVars((t['body'] ?? '').toString());
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    return _templates.where((t) {
      final cat = (t['category'] ?? 'general').toString().toLowerCase();
      if (_categoryFilter != 'all' && cat != _categoryFilter) return false;
      if (q.isEmpty) return true;
      final title = (t['title'] ?? '').toString().toLowerCase();
      final body = (t['body'] ?? '').toString().toLowerCase();
      return title.contains(q) || body.contains(q);
    }).toList();
  }

  void _bumpUseCount(String id) {
    if (!mounted) return;
    setState(() {
      final idx = _templates.indexWhere((e) => e['id'].toString() == id);
      if (idx >= 0) {
        final cur = (_templates[idx]['use_count'] as num?)?.toInt() ?? 0;
        _templates[idx] = {..._templates[idx], 'use_count': cur + 1};
      }
    });
  }

  // --- actions -------------------------------------------------------------
  Future<void> _copyRaw(Map<String, dynamic> t) async {
    final body = (t['body'] ?? '').toString();
    await Clipboard.setData(ClipboardData(text: body));
    ApiService.markMessageTemplateUsed(t['id'].toString());
    _bumpUseCount(t['id'].toString());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('Copied "${t['title']}" — now paste it into your channel')),
      ]),
      backgroundColor: GinataColors.successSage,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _openEditor({Map<String, dynamic>? template}) async {
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TemplateEditorDialog(template: template),
    );
    if (saved == null || !mounted) return;
    setState(() {
      final id = saved['id'].toString();
      final idx = _templates.indexWhere((e) => e['id'].toString() == id);
      if (idx >= 0) {
        _templates[idx] = saved;
      } else {
        _templates.insert(0, saved);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(template == null ? 'Template created' : 'Template updated'),
      backgroundColor: GinataColors.primary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  void _duplicate(Map<String, dynamic> t) {
    _openEditor(template: {
      'title': '${t['title']} (copy)',
      'category': t['category'],
      'body': t['body'],
      'is_active': t['is_active'] ?? true,
    });
  }

  Future<void> _delete(Map<String, dynamic> t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete template?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Text('“${t['title']}” will be permanently removed from your library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GinataColors.alertTerracotta, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ApiService.deleteMessageTemplate(t['id'].toString());
    if (!mounted) return;
    setState(() => _templates.removeWhere((e) => e['id'].toString() == t['id'].toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Template deleted'),
      backgroundColor: GinataColors.textSecondary,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));
  }

  void _openPersonalise(Map<String, dynamic> t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PersonaliseSheet(template: t, onCopied: () => _bumpUseCount(t['id'].toString())),
    );
  }

  // --- build ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GinataColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Message Templates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: GinataColors.primary), onPressed: _load, tooltip: 'Refresh'),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: GinataColors.primary), onPressed: () => _openEditor(), tooltip: 'New template'),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: GinataColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Template', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _buildIntroCard(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _buildSearchField(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildCategoryChips(),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: GinataColors.primary))
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    final total = _templates.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [GinataColors.primary, GinataColors.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.quickreply, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your message library · $total saved', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 3),
                const Text(
                  'Tap a template to personalise it, then copy & paste into Airbnb, Booking.com or WhatsApp.',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _search = v),
      decoration: InputDecoration(
        hintText: 'Search templates…',
        prefixIcon: const Icon(Icons.search, size: 20, color: GinataColors.textMuted),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () {
                _searchController.clear();
                setState(() => _search = '');
              }),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: GinataColors.outlineVariant.withValues(alpha: 0.8))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: GinataColors.outlineVariant.withValues(alpha: 0.8))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GinataColors.primary, width: 1.4)),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _kCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final key = _kCategories[i][0];
          final label = _kCategories[i][1];
          final selected = _categoryFilter == key;
          final accent = key == 'all' ? GinataColors.primary : _categoryColor(key);
          return ChoiceChip(
            label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: selected ? Colors.white : GinataColors.textPrimary)),
            selected: selected,
            selectedColor: accent,
            backgroundColor: Colors.white,
            side: BorderSide(color: selected ? accent : GinataColors.outlineVariant),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            showCheckmark: false,
            onSelected: (_) => setState(() => _categoryFilter = key),
          );
        },
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return _buildEmpty();
    }
    return RefreshIndicator(
      color: GinataColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _buildTemplateCard(items[i]),
      ),
    );
  }

  Widget _buildEmpty() {
    final isFiltered = _search.isNotEmpty || _categoryFilter != 'all';
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
      children: [
        Icon(isFiltered ? Icons.filter_alt_off_outlined : Icons.forum_outlined, size: 52, color: Colors.grey.shade400),
        const SizedBox(height: 14),
        Center(
          child: Text(
            isFiltered ? 'No templates match your filter' : 'Your library is empty',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: GinataColors.textPrimary),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            isFiltered ? 'Try a different channel or search term.' : 'Create your first pre-built message, or pull in the starter library.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: GinataColors.textSecondary),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            onPressed: isFiltered ? () {
              _searchController.clear();
              setState(() {
                _search = '';
                _categoryFilter = 'all';
              });
            } : () => _openEditor(),
            icon: Icon(isFiltered ? Icons.clear_all : Icons.add),
            label: Text(isFiltered ? 'Clear filters' : 'New Template'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GinataColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> t) {
    final cat = (t['category'] ?? 'general').toString().toLowerCase();
    final color = _categoryColor(cat);
    final title = (t['title'] ?? 'Untitled').toString();
    final body = (t['body'] ?? '').toString();
    final vars = _varsOf(t);
    final useCount = (t['use_count'] as num?)?.toInt() ?? 0;
    final active = t['is_active'] != false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openPersonalise(t),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                      child: Icon(_categoryIcon(cat), color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GinataColors.textPrimary))),
                              if (!active) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: GinataColors.warningContainer, borderRadius: BorderRadius.circular(5)),
                                  child: const Text('DRAFT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: GinataColors.warningOchre)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _catPill(cat, color),
                              const SizedBox(width: 8),
                              Icon(Icons.content_copy, size: 11, color: Colors.grey.shade500),
                              const SizedBox(width: 3),
                              Text('$useCount copied', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      icon: const Icon(Icons.more_vert, size: 20, color: GinataColors.textMuted),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) {
                        if (v == 'personalise') _openPersonalise(t);
                        if (v == 'copy') _copyRaw(t);
                        if (v == 'edit') _openEditor(template: t);
                        if (v == 'duplicate') _duplicate(t);
                        if (v == 'delete') _delete(t);
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'personalise', child: ListTile(leading: Icon(Icons.tune, size: 20), title: Text('Personalise & copy'), dense: true, contentPadding: EdgeInsets.zero)),
                        PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.copy, size: 20), title: Text('Copy as-is'), dense: true, contentPadding: EdgeInsets.zero)),
                        PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined, size: 20), title: Text('Edit'), dense: true, contentPadding: EdgeInsets.zero)),
                        PopupMenuItem(value: 'duplicate', child: ListTile(leading: Icon(Icons.content_copy_outlined, size: 20), title: Text('Duplicate'), dense: true, contentPadding: EdgeInsets.zero)),
                        PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, size: 20, color: GinataColors.alertTerracotta), title: Text('Delete', style: TextStyle(color: GinataColors.alertTerracotta)), dense: true, contentPadding: EdgeInsets.zero)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: GinataColors.surfaceSubdued, borderRadius: BorderRadius.circular(12)),
                  child: Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: GinataColors.textSecondary, height: 1.45)),
                ),
                if (vars.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: vars.map((v) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: GinataColors.secondaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6)),
                      child: Text('{{$v}}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: GinataColors.onSecondaryContainer)),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _copyRaw(t),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GinataColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openEditor(template: t),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GinataColors.primary,
                          side: BorderSide(color: GinataColors.outlineVariant.withValues(alpha: 0.9)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _openPersonalise(t),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GinataColors.secondary,
                        side: BorderSide(color: GinataColors.outlineVariant.withValues(alpha: 0.9)),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Icon(Icons.tune, size: 18),
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

  Widget _catPill(String cat, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
      child: Text(_categoryLabel(cat).toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// ---------------------------------------------------------------------------
// Create / Edit dialog
// ---------------------------------------------------------------------------
class _TemplateEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? template;
  const _TemplateEditorDialog({this.template});

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late String _category;
  late bool _active;
  bool _saving = false;

  static const List<String> _quickVars = [
    'guest_name', 'property', 'check_in', 'check_out', 'check_in_time',
    'host_name', 'wifi_name', 'wifi_password', 'door_code', 'balance_due',
  ];

  bool get _isEditing => widget.template != null && widget.template!['id'] != null;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _titleController = TextEditingController(text: t?['title']?.toString() ?? '');
    _bodyController = TextEditingController(text: t?['body']?.toString() ?? '');
    _category = (t?['category']?.toString() ?? 'general').toLowerCase();
    _active = t?['is_active'] != false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _insertVar(String key) {
    final text = _bodyController.text;
    final sel = _bodyController.selection;
    final insert = '{{$key}}';
    final int start = sel.isValid ? sel.start : text.length;
    final int end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, insert);
    _bodyController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: start + insert.length));
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = {
      'title': _titleController.text.trim(),
      'category': _category,
      'body': _bodyController.text,
      'variables': _extractVars(_bodyController.text),
      'is_active': _active,
    };
    try {
      final saved = _isEditing
          ? await ApiService.updateMessageTemplate(widget.template!['id'].toString(), payload)
          : await ApiService.createMessageTemplate(payload);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save template: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vars = _extractVars(_bodyController.text);
    return Dialog(
      backgroundColor: GinataColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: GinataColors.secondaryContainer, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.edit_note, color: GinataColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_isEditing ? 'Edit template' : 'New template', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: GinataColors.primary))),
                      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Template name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleController,
                    decoration: _fieldDeco('e.g. Welcome & Booking Confirmation'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Give your template a name' : null,
                  ),
                  const SizedBox(height: 14),
                  const Text('Channel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: _fieldDeco(''),
                    items: const [
                      DropdownMenuItem(value: 'airbnb', child: Text('Airbnb')),
                      DropdownMenuItem(value: 'booking_com', child: Text('Booking.com')),
                      DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                      DropdownMenuItem(value: 'sms', child: Text('SMS')),
                      DropdownMenuItem(value: 'email', child: Text('Email')),
                      DropdownMenuItem(value: 'general', child: Text('General')),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Message body', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      Text('${_bodyController.text.length} chars', style: const TextStyle(fontSize: 10.5, color: GinataColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _bodyController,
                    maxLines: 8,
                    minLines: 5,
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDeco('Write the message your guest will receive…'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'The message body cannot be empty' : null,
                  ),
                  const SizedBox(height: 10),
                  const Text('Tap to insert a variable', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: GinataColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _quickVars.map((v) => ActionChip(
                      label: Text('{{$v}}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                      backgroundColor: GinataColors.surfaceSubdued,
                      side: BorderSide(color: GinataColors.outlineVariant.withValues(alpha: 0.9)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onPressed: () => _insertVar(v),
                    )).toList(),
                  ),
                  if (vars.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: GinataColors.secondaryContainer.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 15, color: GinataColors.onSecondaryContainer),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Personalisable fields: ${vars.join(', ')}', style: const TextStyle(fontSize: 11, color: GinataColors.onSecondaryContainer))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: GinataColors.primary,
                    title: const Text('Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Inactive templates are kept as drafts', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GinataColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _saving
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(_isEditing ? 'Save changes' : 'Create template'),
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

  InputDecoration _fieldDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: GinataColors.textMuted, fontSize: 12.5),
      filled: true,
      fillColor: GinataColors.surfaceSubdued,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: GinataColors.outlineVariant.withValues(alpha: 0.7))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GinataColors.primary, width: 1.4)),
    );
  }
}

// ---------------------------------------------------------------------------
// Personalise & copy sheet
// ---------------------------------------------------------------------------
class _PersonaliseSheet extends StatefulWidget {
  final Map<String, dynamic> template;
  final VoidCallback onCopied;
  const _PersonaliseSheet({required this.template, required this.onCopied});

  @override
  State<_PersonaliseSheet> createState() => _PersonaliseSheetState();
}

class _PersonaliseSheetState extends State<_PersonaliseSheet> {
  final Map<String, TextEditingController> _controllers = {};
  late final List<String> _vars;
  late final String _body;

  @override
  void initState() {
    super.initState();
    _body = (widget.template['body'] ?? '').toString();
    final raw = widget.template['variables'];
    _vars = raw is List ? raw.map((e) => e.toString()).toList() : _extractVars(_body);
    for (final v in _vars) {
      _controllers[v] = TextEditingController();
    }
    final hostCtrl = _controllers['host_name'];
    if (hostCtrl != null && hostCtrl.text.isEmpty) {
      hostCtrl.text = ApiService.hostName;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _preview {
    return _body.replaceAllMapped(_varRegex, (m) {
      final key = (m.group(1) ?? '').trim();
      final val = _controllers[key]?.text.trim() ?? '';
      return val.isEmpty ? m.group(0)! : val;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _preview));
    ApiService.markMessageTemplateUsed(widget.template['id'].toString());
    widget.onCopied();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(children: [
        Icon(Icons.check_circle, color: Colors.white, size: 18),
        SizedBox(width: 8),
        Expanded(child: Text('Message copied — paste it into your channel now')),
      ]),
      backgroundColor: GinataColors.successSage,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cat = (widget.template['category'] ?? 'general').toString().toLowerCase();
    final color = _categoryColor(cat);
    final title = (widget.template['title'] ?? 'Template').toString();
    final kb = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(
          color: GinataColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: GinataColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 6),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(_categoryIcon(cat), color: color, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: GinataColors.textPrimary)),
                      Text(_categoryLabel(cat), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                    ],
                  )),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_vars.isNotEmpty) ...[
                      const Text('Fill in the details (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: GinataColors.textSecondary)),
                      const SizedBox(height: 10),
                      ..._vars.map((v) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: _controllers[v],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: _humanizeVar(v),
                            isDense: true,
                            filled: true,
                            fillColor: GinataColors.surfaceSubdued,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: GinataColors.outlineVariant.withValues(alpha: 0.7))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GinataColors.primary, width: 1.4)),
                          ),
                        ),
                      )),
                      const SizedBox(height: 6),
                      const Text('Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: GinataColors.textSecondary)),
                      const SizedBox(height: 8),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: GinataColors.surfaceSubdued,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.9)),
                      ),
                      child: Text(_preview, style: const TextStyle(fontSize: 13, height: 1.5, color: GinataColors.textPrimary)),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _copy,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GinataColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.copy_all, size: 18),
                        label: const Text('Copy message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(child: Text('Then paste it into ${_categoryLabel(cat)}.', style: const TextStyle(fontSize: 11, color: GinataColors.textMuted))),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
