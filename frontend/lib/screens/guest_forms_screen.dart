import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/ginata_theme.dart';
import '../theme/ginata_ui.dart';
import '../services/api_service.dart';
import '../services/notification_center.dart';

class GuestRecordFocus {
  final String entityType;
  final String entityId;

  const GuestRecordFocus(this.entityType, this.entityId);
}

class GuestFormsScreen extends StatefulWidget {
  const GuestFormsScreen({super.key});

  static final ValueNotifier<GuestRecordFocus?> focusRequest = ValueNotifier<GuestRecordFocus?>(null);

  @override
  State<GuestFormsScreen> createState() => _GuestFormsScreenState();
}

class _GuestFormsScreenState extends State<GuestFormsScreen> with WidgetsBindingObserver {
  final TextEditingController _formCtrl = TextEditingController();

  bool _isLoading = true;
  bool _busy = false;
  bool _awaitingGoogle = false;
  String? _googleError;
  Map<String, dynamic> _account = const {};
  Map<String, dynamic> _form = const {};
  List<Map<String, dynamic>> _responses = [];
  List<dynamic> _submissions = [];
  List<dynamic> _properties = [];
  String? _propertyId;
  int _seenVersion = NotificationCenter.instance.guestDataVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationCenter.instance.addListener(_onNotifications);
    GuestFormsScreen.focusRequest.addListener(_onFocusRequest);
    _loadData().then((_) => _onFocusRequest());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationCenter.instance.removeListener(_onNotifications);
    GuestFormsScreen.focusRequest.removeListener(_onFocusRequest);
    _formCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingGoogle) {
      _awaitingGoogle = false;
      _loadData(silent: true);
    }
  }

  void _onNotifications() {
    final version = NotificationCenter.instance.guestDataVersion;
    if (version != _seenVersion) {
      _seenVersion = version;
      _loadData(silent: true);
    }
  }

  Future<void> _onFocusRequest() async {
    final focus = GuestFormsScreen.focusRequest.value;
    if (focus == null || !mounted || _isLoading) return;
    GuestFormsScreen.focusRequest.value = null;
    if (focus.entityType == 'google_form_response') {
      Map<String, dynamic>? record;
      for (final r in _responses) {
        if (r['id'].toString() == focus.entityId) record = r;
      }
      if (record == null) {
        try {
          record = await ApiService.fetchGoogleFormResponse(focus.entityId);
        } catch (e) {
          _toast('$e', error: true);
          return;
        }
      }
      if (mounted) _openResponse(record);
    } else if (focus.entityType == 'guest_form_submission') {
      await _loadData(silent: true);
      for (final s in _submissions) {
        if (s['id'].toString() == focus.entityId) {
          _openSubmission(Map<String, dynamic>.from(s as Map));
          return;
        }
      }
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    String? googleError;
    var account = _account;
    var form = _form;
    var responses = _responses;
    try {
      final results = await Future.wait([
        ApiService.fetchGoogleAccountStatus(),
        ApiService.fetchGoogleFormsStatus(),
      ]);
      account = results[0];
      form = results[1];
      if (form['form_linked'] == true) {
        responses = (await ApiService.fetchGoogleFormResponses(limit: 60))
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        responses = [];
      }
    } catch (e) {
      googleError = '$e';
    }
    final submissions = await ApiService.fetchGuestSubmissions();
    final properties = _properties.isEmpty ? await ApiService.fetchProperties() : _properties;
    if (!mounted) return;
    setState(() {
      _googleError = googleError;
      _account = account;
      _form = form;
      _responses = responses;
      _submissions = submissions;
      _properties = properties;
      _isLoading = false;
    });
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? GinataColors.alertTerracotta : GinataColors.primary,
    ));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectGoogle() => _run(() async {
        final url = await ApiService.getGoogleAuthorizationUrl();
        final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!opened) throw const ApiException(0, 'Could not open the Google sign-in page.');
        _awaitingGoogle = true;
        _toast('Finish connecting in the Google window, then come back here.');
      });

  Future<void> _disconnectGoogle() async {
    final ok = await _confirm(
      'Disconnect Google?',
      'Ginata will stop receiving guest check-ins from your Google Form until you reconnect.',
      'Disconnect',
    );
    if (!ok) return;
    await _run(() async {
      await ApiService.disconnectGoogleAccount();
      _toast('Google account disconnected.');
      await _loadData(silent: true);
    });
  }

  Future<void> _linkForm() async {
    final value = _formCtrl.text.trim();
    if (value.isEmpty) {
      _toast('Paste your Google Form edit link or form ID first.', error: true);
      return;
    }
    await _run(() async {
      final res = await ApiService.linkGoogleForm(value, propertyId: _propertyId);
      _formCtrl.clear();
      _toast('"${res['form_title'] ?? 'Google Form'}" linked. Existing responses imported.');
      NotificationCenter.instance.markGuestDataChanged();
      await _loadData(silent: true);
    });
  }

  Future<void> _unlinkForm() async {
    final ok = await _confirm(
      'Unlink this form?',
      'Already imported check-ins stay in Ginata. New responses will no longer sync.',
      'Unlink',
    );
    if (!ok) return;
    await _run(() async {
      await ApiService.unlinkGoogleForm();
      _toast('Google Form unlinked.');
      await _loadData(silent: true);
    });
  }

  Future<void> _syncNow() => _run(() async {
        final res = await ApiService.syncGoogleForms();
        _toast(
          res['message']?.toString() ?? 'Sync complete.',
          error: res['status'] == 'failed' || res['status'] == 'reconnect_required',
        );
        NotificationCenter.instance.markGuestDataChanged();
        await _loadData(silent: true);
      });

  Future<bool> _confirm(String title, String message, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _reviewSubmission(dynamic sub, String action) => _run(() async {
        await ApiService.reviewGuestSubmission(sub['id'].toString(), action);
        _toast(action == 'complete' ? 'Check-in verified.' : 'Marked for review.');
        await _loadData(silent: true);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Guest Check-ins'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadData(), tooltip: 'Refresh'),
        ],
      ),
      body: _isLoading
          ? const GLoadingState(message: 'Loading guest check-ins…')
          : RefreshIndicator(
              color: GinataColors.primary,
              onRefresh: () => _loadData(silent: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(GSpace.md, GSpace.xs, GSpace.md, 120),
                children: [
                  _buildGoogleCard(),
                  const SizedBox(height: GSpace.lg),
                  ..._buildGoogleResponses(),
                  const SizedBox(height: GSpace.lg),
                  ..._buildHostedSubmissions(),
                ],
              ),
            ),
    );
  }

  Widget _buildGoogleCard() {
    final googleConnected = _account['connected'] == true;
    final formLinked = _form['form_linked'] == true;

    return GSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(GSpace.xs),
                decoration: BoxDecoration(
                  color: const Color(0xFF673AB7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(GSpace.radiusSm),
                ),
                child: const Icon(Icons.description_outlined, size: 20, color: Color(0xFF673AB7)),
              ),
              const SizedBox(width: GSpace.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Google Forms check-in', style: GText.cardTitle),
                    Text('Guest responses arrive in Ginata automatically', style: GText.caption),
                  ],
                ),
              ),
              const SizedBox(width: GSpace.xs),
              _formStatusChip(googleConnected, formLinked),
            ],
          ),
          const SizedBox(height: GSpace.md),
          if (_googleError != null) ...[
            GErrorState(message: _googleError!, onRetry: () => _loadData()),
            const SizedBox(height: GSpace.sm),
          ],
          if (_googleError == null && !googleConnected) _buildConnectStep(),
          if (_googleError == null && googleConnected) ...[
            _buildAccountRow(),
            const SizedBox(height: GSpace.sm),
            formLinked ? _buildLinkedForm() : _buildLinkStep(),
          ],
        ],
      ),
    );
  }

  Widget _formStatusChip(bool googleConnected, bool formLinked) {
    if (_googleError != null) return const GStatusChip(label: 'Unavailable', tone: GStatusTone.danger);
    if (!googleConnected) return const GStatusChip(label: 'Not connected');
    if (!formLinked) return const GStatusChip(label: 'No form', tone: GStatusTone.info);
    return switch (_form['sync_status']) {
      'syncing' => const GStatusChip(label: 'Syncing', tone: GStatusTone.info, icon: Icons.sync),
      'failed' => const GStatusChip(label: 'Failed', tone: GStatusTone.danger, icon: Icons.error_outline),
      'reconnect_required' => const GStatusChip(label: 'Reconnect', tone: GStatusTone.danger, icon: Icons.link_off),
      _ => const GStatusChip(label: 'Synced', tone: GStatusTone.success, icon: Icons.check_circle_outline),
    };
  }

  Widget _buildConnectStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Connect your own Google account so Ginata can read responses from your guest check-in form. '
          'Access is private to your host account and can be revoked anytime.',
          style: GText.body,
        ),
        const SizedBox(height: GSpace.sm),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: GinataColors.primary, minimumSize: const Size.fromHeight(46)),
          onPressed: _busy ? null : _connectGoogle,
          icon: _busy ? _spinner() : const Icon(Icons.login, size: 18),
          label: const Text('Connect Google account'),
        ),
        if (_awaitingGoogle) ...[
          const SizedBox(height: GSpace.xs),
          TextButton.icon(
            onPressed: () {
              _awaitingGoogle = false;
              _loadData(silent: true);
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("I've finished connecting"),
          ),
        ],
      ],
    );
  }

  Widget _buildAccountRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: GSpace.sm, vertical: GSpace.xxs),
      decoration: BoxDecoration(
        color: GinataColors.surfaceSubdued,
        borderRadius: BorderRadius.circular(GSpace.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_circle_outlined, size: 18, color: GinataColors.secondary),
          const SizedBox(width: GSpace.xs),
          Expanded(
            child: Text(
              _account['email']?.toString() ?? 'Google account connected',
              style: GText.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: _busy ? null : _disconnectGoogle, child: const Text('Disconnect')),
        ],
      ),
    );
  }

  Widget _buildLinkStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Link your check-in form', style: GText.cardTitle),
        const SizedBox(height: GSpace.xxs),
        const Text(
          'Open the form in Google Forms (edit view) and paste the link from the address bar. '
          'Include questions for name, email, phone, booking reference and check-in date for the best matching.',
          style: GText.caption,
        ),
        const SizedBox(height: GSpace.sm),
        TextField(
          controller: _formCtrl,
          decoration: const InputDecoration(
            labelText: 'Google Form edit link or form ID',
            hintText: 'https://docs.google.com/forms/d/…/edit',
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _linkForm(),
        ),
        const SizedBox(height: GSpace.sm),
        DropdownButtonFormField<String?>(
          initialValue: _propertyId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Property (optional)', prefixIcon: Icon(Icons.villa_outlined)),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All my properties')),
            for (final p in _properties)
              DropdownMenuItem<String?>(
                value: p['id'].toString(),
                child: Text(p['name']?.toString() ?? 'Property', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _propertyId = v),
        ),
        const SizedBox(height: GSpace.sm),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: GinataColors.primary, minimumSize: const Size.fromHeight(46)),
          onPressed: _busy ? null : _linkForm,
          icon: _busy ? _spinner() : const Icon(Icons.add_link, size: 18),
          label: const Text('Link form & import responses'),
        ),
      ],
    );
  }

  Widget _buildLinkedForm() {
    final counts = Map<String, dynamic>.from((_form['counts'] as Map?) ?? const {});
    final realtime = _form['realtime'] == 'push';
    final lastSync = _formatDateTime(_form['last_sync_at']);
    final responderUrl = _form['responder_url']?.toString();
    final editUrl = _form['edit_url']?.toString();
    final lastError = _form['last_error']?.toString();
    final needsReconnect = _form['sync_status'] == 'reconnect_required';
    final processing = (counts['processing'] as num?) ?? 0;
    final failed = (counts['failed'] as num?) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_form['form_title']?.toString() ?? 'Linked Google Form', style: GText.cardTitle),
        const SizedBox(height: GSpace.xxs),
        GInfoRow(icon: Icons.schedule, label: 'Last sync', value: lastSync ?? 'Not yet'),
        GInfoRow(
          icon: realtime ? Icons.bolt : Icons.timer_outlined,
          label: 'Updates',
          value: realtime
              ? 'Instant (Google push notifications)'
              : 'Checked automatically every ${_form['poll_seconds'] ?? 60} seconds',
        ),
        if (_form['property_id'] != null)
          GInfoRow(icon: Icons.villa_outlined, label: 'Property', value: _propertyName(_form['property_id'].toString())),
        const SizedBox(height: GSpace.xs),
        Wrap(
          spacing: GSpace.xs,
          runSpacing: GSpace.xs,
          children: [
            GStatusChip(label: '${counts['synced'] ?? 0} synced', tone: GStatusTone.success),
            GStatusChip(label: '${counts['pending_review'] ?? 0} pending review', tone: GStatusTone.warning),
            if (processing > 0) GStatusChip(label: '$processing processing', tone: GStatusTone.info),
            if (failed > 0) GStatusChip(label: '$failed failed', tone: GStatusTone.danger),
          ],
        ),
        if (lastError != null && lastError.isNotEmpty && _form['sync_status'] != 'connected') ...[
          const SizedBox(height: GSpace.sm),
          GErrorState(message: lastError),
        ],
        const SizedBox(height: GSpace.sm),
        if (needsReconnect)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: GinataColors.alertTerracotta,
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: _busy ? null : _connectGoogle,
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Reconnect Google'),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: GinataColors.primary, minimumSize: const Size.fromHeight(46)),
            onPressed: _busy ? null : _syncNow,
            icon: _busy ? _spinner() : const Icon(Icons.sync, size: 18),
            label: Text(_busy ? 'Syncing…' : 'Sync now'),
          ),
        const SizedBox(height: GSpace.xs),
        Wrap(
          spacing: GSpace.xs,
          runSpacing: GSpace.xxs,
          children: [
            if (responderUrl != null)
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: responderUrl));
                  _toast('Guest check-in link copied.');
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy guest link'),
              ),
            if (editUrl != null)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(editUrl), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open form'),
              ),
            TextButton(onPressed: _busy ? null : _unlinkForm, child: const Text('Unlink form')),
          ],
        ),
      ],
    );
  }

  bool _needsAttention(Map<String, dynamic> r) =>
      r['match_status'] == 'unmatched' || r['sync_status'] == 'failed' || r['sync_status'] == 'pending_review';

  List<Widget> _buildGoogleResponses() {
    if (_form['form_linked'] != true) return const [];
    final attention = _responses.where(_needsAttention).toList();
    final done = _responses.where((r) => !_needsAttention(r)).toList();
    return [
      GSectionHeader(
        title: 'Needs attention',
        subtitle: 'Unmatched check-ins or answers to review before arrival.',
        trailing: GStatusChip(
          label: '${attention.length}',
          tone: attention.isEmpty ? GStatusTone.success : GStatusTone.warning,
        ),
      ),
      const SizedBox(height: GSpace.sm),
      if (attention.isEmpty)
        const GEmptyState(
          icon: Icons.task_alt,
          title: 'All caught up',
          message: 'New Google Form check-ins that need your attention will appear here.',
        )
      else
        ...attention.map(_buildResponseCard),
      if (done.isNotEmpty) ...[
        const SizedBox(height: GSpace.lg),
        const GSectionHeader(title: 'Synced check-ins', subtitle: 'Matched to bookings and saved to guest profiles.'),
        const SizedBox(height: GSpace.sm),
        ...done.map(_buildResponseCard),
      ],
    ];
  }

  ({String label, GStatusTone tone}) _responseStatus(Map<String, dynamic> r) {
    if (r['sync_status'] == 'failed') return (label: 'Failed', tone: GStatusTone.danger);
    if (r['sync_status'] == 'processing') return (label: 'Processing', tone: GStatusTone.info);
    if (r['match_status'] == 'unmatched') return (label: 'Needs match', tone: GStatusTone.warning);
    if (r['sync_status'] == 'pending_review') return (label: 'Pending review', tone: GStatusTone.warning);
    return (label: 'Synced', tone: GStatusTone.success);
  }

  Widget _buildResponseCard(Map<String, dynamic> r) {
    final name = r['guest_name']?.toString() ?? 'Guest';
    final status = _responseStatus(r);
    final checkIn = _formatDate(r['check_in_date']);
    final submitted = _formatDateTime(r['submitted_at']);
    final contact = [r['guest_email'], r['guest_phone']].where((v) => v != null && '$v'.isNotEmpty).join(' · ');
    return GSectionCard(
      margin: const EdgeInsets.only(bottom: GSpace.sm),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(GSpace.radiusLg),
        onTap: () => _openResponse(r),
        child: Padding(
          padding: const EdgeInsets.all(GSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _avatar(name),
                  const SizedBox(width: GSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (contact.isNotEmpty)
                          Text(contact, style: GText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: GSpace.xs),
                  GStatusChip(label: status.label, tone: status.tone),
                ],
              ),
              const SizedBox(height: GSpace.sm),
              Wrap(
                spacing: GSpace.md,
                runSpacing: GSpace.xxs,
                children: [
                  if (r['booking_reference'] != null)
                    _meta(Icons.confirmation_number_outlined, '${r['booking_reference']}'),
                  if (checkIn != null) _meta(Icons.login, 'Check-in $checkIn'),
                  if (submitted != null) _meta(Icons.schedule, 'Sent $submitted'),
                ],
              ),
              if (r['match_reason'] != null && r['match_status'] == 'unmatched') ...[
                const SizedBox(height: GSpace.xs),
                Text('${r['match_reason']}', style: GText.caption),
              ],
              if (r['match_status'] == 'unmatched') ...[
                const SizedBox(height: GSpace.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: GinataColors.primary),
                    onPressed: _busy ? null : () => _assign(r),
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text('Match to booking'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _assign(Map<String, dynamic> r) async {
    final reservations = (await ApiService.fetchReservations())
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => !['cancelled', 'draft'].contains(e['reservation_status']))
        .toList();
    final target = DateTime.tryParse(r['check_in_date']?.toString() ?? '') ?? DateTime.now();
    reservations.sort((a, b) {
      final da = DateTime.tryParse(a['check_in_date']?.toString() ?? '') ?? target;
      final db = DateTime.tryParse(b['check_in_date']?.toString() ?? '') ?? target;
      return da.difference(target).abs().compareTo(db.difference(target).abs());
    });
    if (!mounted) return;
    if (reservations.isEmpty) {
      _toast('There are no active bookings to match this check-in to.', error: true);
      return;
    }
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(GSpace.md, 0, GSpace.md, GSpace.xs),
                child: GSectionHeader(
                  title: 'Match ${r['guest_name'] ?? 'guest'}',
                  subtitle: 'Choose the booking this check-in belongs to. Closest dates are listed first.',
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: reservations.length,
                  itemBuilder: (_, i) {
                    final res = reservations[i];
                    final guest = Map<String, dynamic>.from((res['primary_guest'] as Map?) ?? const {});
                    final prop = Map<String, dynamic>.from((res['property'] as Map?) ?? const {});
                    final guestName = '${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}'.trim();
                    final ref = res['booking_reference'] != null ? ' · ${res['booking_reference']}' : '';
                    return ListTile(
                      leading: _avatar(guestName.isEmpty ? 'G' : guestName),
                      title: Text(
                        guestName.isEmpty ? 'Guest' : guestName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${prop['name'] ?? 'Property'} · ${_formatDate(res['check_in_date']) ?? ''}'
                        ' – ${_formatDate(res['check_out_date']) ?? ''}$ref',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(ctx, res),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null) return;
    await _run(() async {
      await ApiService.assignGoogleFormResponse(r['id'].toString(), chosen['id'].toString());
      _toast('Check-in matched to the booking.');
      NotificationCenter.instance.markGuestDataChanged();
      await _loadData(silent: true);
    });
  }

  void _openResponse(Map<String, dynamic> r) {
    final answers = ((r['answers'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final status = _responseStatus(r);
    _showDetails(
      title: r['guest_name']?.toString() ?? 'Guest check-in',
      status: GStatusChip(label: status.label, tone: status.tone),
      rows: [
        if (r['guest_email'] != null) GInfoRow(icon: Icons.email_outlined, label: 'Email', value: '${r['guest_email']}'),
        if (r['guest_phone'] != null) GInfoRow(icon: Icons.phone_outlined, label: 'Phone', value: '${r['guest_phone']}'),
        if (r['booking_reference'] != null)
          GInfoRow(icon: Icons.confirmation_number_outlined, label: 'Booking ref', value: '${r['booking_reference']}'),
        if (r['check_in_date'] != null)
          GInfoRow(
            icon: Icons.login,
            label: 'Check-in',
            value: _formatDate(r['check_in_date']) ?? '${r['check_in_date']}',
          ),
        if (r['submitted_at'] != null)
          GInfoRow(icon: Icons.schedule, label: 'Submitted', value: _formatDateTime(r['submitted_at']) ?? ''),
        if (r['match_reason'] != null)
          GInfoRow(icon: Icons.info_outline, label: 'Matching', value: '${r['match_reason']}'),
        if (r['last_error'] != null) GInfoRow(icon: Icons.error_outline, label: 'Error', value: '${r['last_error']}'),
        if (answers.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: GSpace.sm, bottom: GSpace.xxs),
            child: Text('Form answers', style: GText.cardTitle),
          ),
          for (final a in answers)
            Padding(
              padding: const EdgeInsets.only(bottom: GSpace.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${a['question'] ?? ''}', style: GText.label),
                  Text('${a['answer'] ?? ''}', style: GText.body),
                ],
              ),
            ),
        ],
      ],
      action: r['match_status'] == 'unmatched'
          ? FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: GinataColors.primary, minimumSize: const Size.fromHeight(46)),
              onPressed: () {
                Navigator.pop(context);
                _assign(r);
              },
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Match to booking'),
            )
          : null,
    );
  }

  void _openSubmission(Map<String, dynamic> s) {
    _showDetails(
      title: s['guest_name']?.toString() ?? 'Guest check-in',
      status: _submissionChip(s),
      rows: [
        if (s['guest_email'] != null) GInfoRow(icon: Icons.email_outlined, label: 'Email', value: '${s['guest_email']}'),
        if (s['guest_phone'] != null) GInfoRow(icon: Icons.phone_outlined, label: 'Phone', value: '${s['guest_phone']}'),
        if (s['eta'] != null) GInfoRow(icon: Icons.schedule, label: 'Arrival', value: '${s['eta']}'),
        if (s['flight_number'] != null)
          GInfoRow(icon: Icons.flight_land, label: 'Flight', value: '${s['flight_number']}'),
        if (s['transport_mode'] != null)
          GInfoRow(icon: Icons.directions_car_outlined, label: 'Transport', value: '${s['transport_mode']}'),
        if (s['id_number'] != null) GInfoRow(icon: Icons.badge_outlined, label: 'ID', value: '${s['id_number']}'),
        if (s['dietary_requirements'] != null)
          GInfoRow(icon: Icons.restaurant_outlined, label: 'Dietary', value: '${s['dietary_requirements']}'),
        if (s['special_requests'] != null)
          GInfoRow(icon: Icons.notes, label: 'Requests', value: '${s['special_requests']}'),
      ],
    );
  }

  void _showDetails({required String title, required Widget status, required List<Widget> rows, Widget? action}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(GSpace.lg, 0, GSpace.lg, GSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: GText.title, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: GSpace.xs),
                    status,
                  ],
                ),
                const SizedBox(height: GSpace.sm),
                ...rows,
                if (action != null) ...[const SizedBox(height: GSpace.md), action],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHostedSubmissions() {
    if (_submissions.isEmpty && _form['form_linked'] == true) return const [];
    return [
      GSectionHeader(
        title: 'Ginata check-in links',
        subtitle: 'Responses from check-in links sent from a booking.',
        trailing: GStatusChip(label: '${_submissions.length}', tone: GStatusTone.info),
      ),
      const SizedBox(height: GSpace.sm),
      if (_submissions.isEmpty)
        const GEmptyState(
          icon: Icons.assignment_outlined,
          title: 'No guest responses yet',
          message: 'Connect Google above, or send a check-in link from a booking, and responses will appear here automatically.',
        )
      else
        ..._submissions.map((s) => _buildSubmissionCard(Map<String, dynamic>.from(s as Map))),
    ];
  }

  GStatusChip _submissionChip(Map<String, dynamic> s) => switch (s['form_status']) {
        'completed' => const GStatusChip(label: 'Verified', tone: GStatusTone.success),
        'submitted' || 'needs_review' => const GStatusChip(label: 'Pending review', tone: GStatusTone.warning),
        'revoked' => const GStatusChip(label: 'Revoked', tone: GStatusTone.neutral),
        _ => const GStatusChip(label: 'Awaiting guest', tone: GStatusTone.neutral),
      };

  Widget _buildSubmissionCard(Map<String, dynamic> sub) {
    final guestName = sub['guest_name']?.toString() ?? 'Guest';
    final contact = [sub['guest_email'], sub['guest_phone']].where((v) => v != null && '$v'.isNotEmpty).join(' · ');
    final canReview = sub['form_status'] == 'submitted' || sub['form_status'] == 'needs_review';
    return GSectionCard(
      margin: const EdgeInsets.only(bottom: GSpace.sm),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(GSpace.radiusLg),
        onTap: () => _openSubmission(sub),
        child: Padding(
          padding: const EdgeInsets.all(GSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _avatar(guestName),
                  const SizedBox(width: GSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(guestName, style: GText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (contact.isNotEmpty)
                          Text(contact, style: GText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: GSpace.xs),
                  _submissionChip(sub),
                ],
              ),
              const SizedBox(height: GSpace.sm),
              Wrap(
                spacing: GSpace.md,
                runSpacing: GSpace.xxs,
                children: [
                  if (sub['eta'] != null) _meta(Icons.schedule, 'Arrival ${sub['eta']}'),
                  if (sub['flight_number'] != null) _meta(Icons.flight_land, '${sub['flight_number']}'),
                  if (sub['id_number'] != null) _meta(Icons.badge_outlined, 'ID ${sub['id_number']}'),
                ],
              ),
              if (canReview) ...[
                const SizedBox(height: GSpace.sm),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: GSpace.xs,
                  runSpacing: GSpace.xxs,
                  children: [
                    OutlinedButton(
                      onPressed: _busy ? null : () => _reviewSubmission(sub, 'needs_review'),
                      child: const Text('Flag for review'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: GinataColors.primary),
                      onPressed: _busy ? null : () => _reviewSubmission(sub, 'complete'),
                      child: const Text('Verify'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(String name) => CircleAvatar(
        radius: 18,
        backgroundColor: GinataColors.primaryContainer,
        child: Text(
          name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'G',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: GinataColors.secondary),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: GText.caption, overflow: TextOverflow.ellipsis)),
        ],
      );

  Widget _spinner() => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );

  String _propertyName(String id) {
    for (final p in _properties) {
      if (p['id'].toString() == id) return p['name']?.toString() ?? 'Property';
    }
    return 'Selected property';
  }

  String? _formatDate(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '');
    return d == null ? null : DateFormat('d MMM yyyy').format(d);
  }

  String? _formatDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    final hasZone = raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
    final d = DateTime.tryParse(hasZone ? raw : '${raw}Z');
    return d == null ? null : DateFormat('d MMM, HH:mm').format(d.toLocal());
  }
}
