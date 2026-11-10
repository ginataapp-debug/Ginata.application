import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/ginata_theme.dart';
import '../services/api_service.dart';

class GuestFormsScreen extends StatefulWidget {
  const GuestFormsScreen({super.key});

  @override
  State<GuestFormsScreen> createState() => _GuestFormsScreenState();
}

class _GuestFormsScreenState extends State<GuestFormsScreen> {
  final String _filterCategory = 'all';

  List<dynamic> _submissions = [];
  Map<String, dynamic> _googleStatus = {};
  bool _isLoading = true;
  bool _isSyncingGoogle = false;
  final TextEditingController _sheetUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _sheetUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final subs = await ApiService.fetchGuestSubmissions(
      statusFilter: _filterCategory == 'all' ? null : _filterCategory,
    );
    final gStatus = await ApiService.fetchGoogleFormsStatus();
    if (mounted) {
      setState(() {
        _submissions = subs;
        _googleStatus = gStatus;
        if (gStatus['google_sheet_url'] != null) {
          _sheetUrlCtrl.text = gStatus['google_sheet_url'];
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _syncGoogle() async {
    setState(() => _isSyncingGoogle = true);
    try {
      final res = await ApiService.syncGoogleForms();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Google Form entries synced!'),
            backgroundColor: GinataColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: GinataColors.alertTerracotta,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingGoogle = false);
    }
  }

  void _reviewSubmission(dynamic sub, String action) async {
    try {
      await ApiService.reviewGuestSubmission(sub['id'], action);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'complete'
                  ? 'Submission matched and confirmed!'
                  : 'Marked for review',
            ),
            backgroundColor: GinataColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Guest Registration Forms'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh entries',
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
                // Google Forms & Sheet Sync Hub Card
                _buildGoogleFormsHub(),
                const SizedBox(height: 20),

                // Intake Review Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Guest Submissions',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: GinataColors.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: GinataColors.secondaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_submissions.length} Total',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: GinataColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Guest check-in information automatically imported from your Google Form responses.',
                  style: TextStyle(
                    fontSize: 12,
                    color: GinataColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),

                // Submissions Feed
                if (_submissions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: GinataColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x14174A3F)),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 44,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Guest Responses Yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: GinataColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'When guests complete your Google Form, click "Sync Google Responses" above to import their data.',
                          style: TextStyle(
                            fontSize: 12,
                            color: GinataColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ..._submissions.map((sub) => _buildSubmissionCard(sub)),
              ],
            ),
    );
  }

  Widget _buildGoogleFormsHub() {
    final isConnected = _googleStatus['is_connected'] == true;
    final email =
        _googleStatus['connected_email'] ?? 'concierge-sync@ginata.co.ke';
    final sheetId =
        _googleStatus['google_sheet_id'] ??
        '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GinataColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14174A3F)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF673AB7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description,
                      size: 20,
                      color: Color(0xFF673AB7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google Forms Integration',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: GinataColors.primary,
                        ),
                      ),
                      Text(
                        'Sync guest pre-arrival responses',
                        style: TextStyle(
                          fontSize: 11,
                          color: GinataColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isConnected
                      ? GinataColors.secondaryContainer
                      : GinataColors.secondaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isConnected ? 'ACTIVE SYNC' : 'READY TO SYNC',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: GinataColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Google Form / Sheet URL field with quick copy
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GinataColors.surfaceSubdued,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Connected Sheet ID / Responses:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: GinataColors.textSecondary,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: sheetId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sheet ID copied!')),
                        );
                      },
                      child: const Row(
                        children: [
                          Icon(
                            Icons.copy,
                            size: 12,
                            color: GinataColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Copy ID',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: GinataColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  sheetId,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: GinataColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Connected Google Account: $email',
                  style: const TextStyle(
                    fontSize: 11,
                    color: GinataColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action buttons: Sync Now + Help
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GinataColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _isSyncingGoogle
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.sync, size: 16),
                  label: Text(
                    _isSyncingGoogle ? 'Syncing...' : 'Sync Responses Now',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _isSyncingGoogle ? null : _syncGoogle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // How to connect step-by-step
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'How to connect your own Google Form in 3 easy steps:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: GinataColors.primary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '1. Create your Google Form with fields: Guest Name, Email, Phone, Arrival Time, ID / Passport.',
                  style: TextStyle(
                    fontSize: 11,
                    color: GinataColors.textSecondary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '2. In Google Form Responses, click "Link to Sheets" to create a spreadsheet.',
                  style: TextStyle(
                    fontSize: 11,
                    color: GinataColors.textSecondary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '3. Share that Sheet with Viewer access, then click "Sync Responses Now" anytime.',
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
    );
  }

  Widget _buildSubmissionCard(dynamic sub) {
    final guestName = sub['guest_name'] ?? 'Direct Guest';
    final email = sub['guest_email'] ?? 'No email';
    final phone = sub['guest_phone'] ?? 'No phone';
    final eta = sub['eta'] ?? 'Unspecified';
    final flight = sub['flight_number'] ?? 'None';
    final dietary = sub['dietary_requirements'] ?? 'None';
    final idNumber = sub['id_number'];
    final status = sub['form_status'] ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: GinataColors.primaryContainer,
                      child: Text(
                        guestName.isNotEmpty ? guestName[0] : 'G',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guestName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: GinataColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$email · $phone',
                            style: const TextStyle(
                              fontSize: 11,
                              color: GinataColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'completed'
                      ? GinataColors.secondaryContainer
                      : GinataColors.warningContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status == 'completed' ? 'VERIFIED' : 'PENDING REVIEW',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: status == 'completed'
                        ? GinataColors.primary
                        : GinataColors.warningOchre,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Detail Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GinataColors.surfaceSubdued,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Arrival Time: $eta',
                      style: const TextStyle(
                        fontSize: 11,
                        color: GinataColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Flight / Transport: $flight',
                      style: const TextStyle(
                        fontSize: 11,
                        color: GinataColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (idNumber != null && idNumber.toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'National ID / Passport: $idNumber',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: GinataColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (dietary != 'None') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Dietary / Notes: $dietary',
                        style: const TextStyle(
                          fontSize: 11,
                          color: GinataColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 30),
                ),
                onPressed: () => _reviewSubmission(sub, 'flag'),
                child: const Text('Flag Note', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GinataColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 30),
                ),
                onPressed: () => _reviewSubmission(sub, 'complete'),
                child: const Text(
                  'Verify & Match',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
