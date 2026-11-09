import 'package:flutter/material.dart';
import '../theme/ginata_theme.dart';
import '../services/api_service.dart';

class DocumentArchiveScreen extends StatefulWidget {
  const DocumentArchiveScreen({super.key});

  @override
  State<DocumentArchiveScreen> createState() => _DocumentArchiveScreenState();
}

class _DocumentArchiveScreenState extends State<DocumentArchiveScreen> {
  List<dynamic> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    setState(() => _isLoading = true);
    final docs = await ApiService.fetchDocuments();
    setState(() {
      _documents = docs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Archive'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDocs),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: GinataColors.primary))
          : _documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_open, size: 48, color: GinataColors.outline),
                      const SizedBox(height: 12),
                      const Text('No archived documents yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Export invoices or receipts to archive downloadable PDF and DOCX files.', style: TextStyle(color: GinataColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: _documents.length,
                  itemBuilder: (ctx, idx) {
                    final doc = _documents[idx];
                    final format = (doc['file_format'] ?? 'pdf').toString().toUpperCase();
                    final isPdf = format == 'PDF';
                    final token = doc['secure_token'];
                    final dlUrl = '${ApiService.baseUrl}/public/documents/$token/download';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPdf ? GinataColors.primaryContainer : GinataColors.secondaryContainer,
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf : Icons.description,
                            color: isPdf ? Colors.white : GinataColors.primary,
                            size: 18,
                          ),
                        ),
                        title: Text(doc['file_name'] ?? 'Document', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '$format • ${(doc['file_size'] / 1024).toStringAsFixed(1)} KB • v${doc['version']}',
                          style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 30),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Secure Download Link'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText(
                                      dlUrl,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: GinataColors.primary),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text('Link uses an unguessable token and expires in 14 days.', style: TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                                ],
                              ),
                            );
                          },
                          child: const Text('Download', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
