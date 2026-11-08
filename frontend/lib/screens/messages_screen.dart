import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/ginata_theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;
  List<dynamic> _threads = [];
  Map<String, dynamic>? _selectedThread;
  List<dynamic> _messages = [];
  bool _loadingMessages = false;
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedChannelFilter = 'All';

  final List<String> _channels = ['All', 'whatsapp', 'airbnb', 'booking.com', 'sms', 'direct'];

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    setState(() => _loading = true);
    try {
      final threads = await ApiService.fetchMessageThreads();
      if (mounted) {
        setState(() {
          _threads = threads;
          _loading = false;
          if (_threads.isNotEmpty && _selectedThread == null) {
            _selectThread(_threads.first);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectThread(Map<String, dynamic> thread) async {
    setState(() {
      _selectedThread = thread;
      _loadingMessages = true;
    });

    try {
      final msgs = await ApiService.fetchThreadMessages(thread['id'].toString());
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _selectedThread == null) return;

    final threadId = _selectedThread!['id'].toString();
    _replyController.clear();

    try {
      final newMsg = await ApiService.sendThreadMessage(
        threadId,
        text,
        senderType: 'host',
        senderName: 'Host',
      );
      setState(() {
        _messages.add(newMsg);
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _openNewThreadModal() {
    showDialog(
      context: context,
      builder: (ctx) => _NewThreadDialog(
        onCreated: (newThread) {
          Navigator.pop(ctx);
          _loadThreads().then((_) {
            _selectThread(newThread);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredThreads = _threads.where((t) {
      if (_selectedChannelFilter == 'All') return true;
      return (t['channel'] ?? '').toString().toLowerCase() == _selectedChannelFilter.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: GinataColors.background,
      appBar: AppBar(
        title: const Text(
          'Unified Guest Inbox & Messages',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: GinataColors.primary),
            onPressed: _loadThreads,
            tooltip: 'Refresh Messages',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _openNewThreadModal,
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('New Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GinataColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GinataColors.primary))
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 750;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Pane: Thread List
                        SizedBox(
                          width: 320,
                          child: _buildThreadsPane(filteredThreads),
                        ),
                        const SizedBox(width: 16),
                        // Right Pane: Active Chat Conversation
                        Expanded(
                          child: _buildChatPane(),
                        ),
                      ],
                    );
                  } else {
                    // Narrow / Mobile View: Switch between thread list and active chat
                    if (_selectedThread != null && _messages.isNotEmpty) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => setState(() => _selectedThread = null),
                                icon: const Icon(Icons.arrow_back, size: 18),
                                label: const Text('All Conversations'),
                              ),
                            ],
                          ),
                          Expanded(child: _buildChatPane()),
                        ],
                      );
                    }
                    return _buildThreadsPane(filteredThreads);
                  }
                },
              ),
            ),
    );
  }

  Widget _buildThreadsPane(List<dynamic> filteredThreads) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Channel filter chips
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _channels.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (ctx, i) {
                  final ch = _channels[i];
                  final isSelected = _selectedChannelFilter == ch;
                  return ChoiceChip(
                    label: Text(
                      ch.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : GinataColors.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: GinataColors.primary,
                    backgroundColor: GinataColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onSelected: (_) => setState(() => _selectedChannelFilter = ch),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1),
          // Thread list
          Expanded(
            child: filteredThreads.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.forum_outlined, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          const Text('No conversations found', style: TextStyle(fontWeight: FontWeight.w600, color: GinataColors.textSecondary)),
                          const SizedBox(height: 4),
                          const Text('Click New Message to reach a guest.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredThreads.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
                    itemBuilder: (ctx, i) {
                      final t = filteredThreads[i];
                      final isSelected = _selectedThread != null && _selectedThread!['id'] == t['id'];
                      final guestName = t['guest_name'] ?? 'Guest';
                      final channel = t['channel'] ?? 'whatsapp';
                      final lastMsg = t['last_message'] ?? 'No messages yet';

                      return InkWell(
                        onTap: () => _selectThread(t),
                        child: Container(
                          color: isSelected ? GinataColors.primary.withValues(alpha: 0.06) : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _getChannelColor(channel).withValues(alpha: 0.15),
                                    child: Text(
                                      guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: _getChannelColor(channel)),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: Icon(_getChannelIcon(channel), size: 12, color: _getChannelColor(channel)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            guestName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: GinataColors.textPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getChannelColor(channel).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            channel.toUpperCase(),
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _getChannelColor(channel)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lastMsg,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPane() {
    if (_selectedThread == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Text('Select a conversation to start messaging'),
        ),
      );
    }

    final guestName = _selectedThread!['guest_name'] ?? 'Guest';
    final channel = _selectedThread!['channel'] ?? 'whatsapp';
    final phone = _selectedThread!['guest_phone'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Chat Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _getChannelColor(channel).withValues(alpha: 0.2),
                  child: Text(
                    guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _getChannelColor(channel)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(guestName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GinataColors.textPrimary)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(_getChannelIcon(channel), size: 12, color: _getChannelColor(channel)),
                          const SizedBox(width: 4),
                          Text(
                            '${channel.toUpperCase()} ${phone.isNotEmpty ? "· $phone" : ""}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Sync Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Message Stream
          Expanded(
            child: _loadingMessages
                ? const Center(child: CircularProgressIndicator(color: GinataColors.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            const Text('No messages yet in this thread.', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            const Text('Send a welcome message or check-in guide.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          final isHost = (msg['sender_type'] ?? '') == 'host';
                          final content = msg['content'] ?? '';
                          final time = (msg['created_at'] ?? '').toString().split('T').last.split('.').first;

                          return Align(
                            alignment: isHost ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              constraints: const BoxConstraints(maxWidth: 480),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isHost ? GinataColors.primary : const Color(0xFFF1EDE6),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(isHost ? 14 : 2),
                                  bottomRight: Radius.circular(isHost ? 2 : 14),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isHost ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    content,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isHost ? Colors.white : GinataColors.textPrimary,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    time.isNotEmpty ? time.substring(0, 5) : '',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isHost ? Colors.white.withValues(alpha: 0.7) : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: 'Type message to $guestName...',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: GinataColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                  onPressed: _sendMessage,
                  tooltip: 'Send Message',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getChannelColor(String channel) {
    switch (channel.toLowerCase()) {
      case 'whatsapp':
        return const Color(0xFF25D366);
      case 'airbnb':
        return const Color(0xFFFF5A5F);
      case 'booking.com':
        return const Color(0xFF003580);
      case 'sms':
        return Colors.teal;
      default:
        return GinataColors.primary;
    }
  }

  IconData _getChannelIcon(String channel) {
    switch (channel.toLowerCase()) {
      case 'whatsapp':
        return Icons.chat;
      case 'airbnb':
        return Icons.home_work_outlined;
      case 'booking.com':
        return Icons.hotel;
      case 'sms':
        return Icons.sms_outlined;
      default:
        return Icons.message_outlined;
    }
  }
}

class _NewThreadDialog extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onCreated;

  const _NewThreadDialog({required this.onCreated});

  @override
  State<_NewThreadDialog> createState() => _NewThreadDialogState();
}

class _NewThreadDialogState extends State<_NewThreadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _firstMsgController = TextEditingController();
  String _channel = 'whatsapp';
  bool _submitting = false;

  final List<String> _channels = ['whatsapp', 'airbnb', 'booking.com', 'sms', 'direct'];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final thread = await ApiService.createMessageThread({
        'guest_name': _nameController.text.trim(),
        'guest_phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'channel': _channel,
        'last_message': _firstMsgController.text.trim().isEmpty ? 'Conversation started' : _firstMsgController.text.trim(),
      });

      if (_firstMsgController.text.trim().isNotEmpty) {
        await ApiService.sendThreadMessage(
          thread['id'].toString(),
          _firstMsgController.text.trim(),
          senderType: 'host',
          senderName: 'Host',
        );
      }

      widget.onCreated(thread);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate conversation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
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
                    const Text('New Guest Message Thread', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Channel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _channel,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _channels.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
                  onChanged: (val) => setState(() => _channel = val ?? _channel),
                ),
                const SizedBox(height: 14),
                const Text('Guest Full Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Liam Evans',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                const Text('Phone / Contact', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    hintText: 'e.g. +254 712 345 678',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Initial Message', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _firstMsgController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Hello Liam, welcome to Ginata! Your check-in pin is 4819.',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GinataColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _submitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Start Thread'),
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
}
