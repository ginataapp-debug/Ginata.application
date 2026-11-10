import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/ginata_theme.dart';
import '../services/api_service.dart';
import '../widgets/pdf_viewer.dart';

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
    if (!mounted) return;
    setState(() {
      _documents = docs;
      _isLoading = false;
    });
  }

  String _downloadPath(dynamic doc) => '/documents/${doc['id']}/download';

  void _openDoc(dynamic doc) {
    final format = (doc['file_format'] ?? 'pdf').toString().toLowerCase();
    final fileName = (doc['file_name'] ?? 'document.$format').toString();
    if (format == 'pdf') {
      openPdfViewer(
        context,
        title: 'Document',
        fileName: fileName,
        apiPath: _downloadPath(doc),
      );
    } else {
      _downloadDoc(doc);
    }
  }

  Future<void> _downloadDoc(dynamic doc) async {
    final format = (doc['file_format'] ?? 'pdf').toString().toLowerCase();
    final fileName = (doc['file_name'] ?? 'document.$format').toString();
    try {
      final bytes = await ApiService.downloadBytes(_downloadPath(doc));
      if (mounted) {
        await saveDocumentToDevice(
          context,
          bytes: bytes,
          fileName: fileName,
          mimeType: format == 'pdf'
              ? 'application/pdf'
              : 'application/octet-stream',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: GinataColors.alertTerracotta,
          ),
        );
      }
    }
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
          ? const Center(
              child: CircularProgressIndicator(color: GinataColors.primary),
            )
          : _documents.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.folder_open,
                    size: 48,
                    color: GinataColors.outline,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No archived documents yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Export invoices or receipts to archive downloadable PDF and DOCX files.',
                    style: TextStyle(color: GinataColors.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: _documents.length,
              itemBuilder: (ctx, idx) {
                final doc = _documents[idx];
                final format = (doc['file_format'] ?? 'pdf')
                    .toString()
                    .toUpperCase();
                final isPdf = format == 'PDF';
                final token = doc['secure_token'];
                final dlUrl =
                    '${ApiService.baseUrl}/public/documents/$token/download';
                final sizeKb =
                    (double.tryParse(doc['file_size']?.toString() ?? '0') ??
                        0) /
                    1024;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    onTap: () => _openDoc(doc),
                    leading: CircleAvatar(
                      backgroundColor: isPdf
                          ? GinataColors.primaryContainer
                          : GinataColors.secondaryContainer,
                      child: Icon(
                        isPdf ? Icons.picture_as_pdf : Icons.description,
                        color: isPdf ? Colors.white : GinataColors.primary,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      doc['file_name'] ?? 'Document',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '$format • ${sizeKb.toStringAsFixed(1)} KB • v${doc['version']}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: GinataColors.textSecondary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPdf)
                          IconButton(
                            tooltip: 'View fullscreen',
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 20,
                              color: GinataColors.primary,
                            ),
                            onPressed: () => _openDoc(doc),
                          ),
                        IconButton(
                          tooltip: 'Copy secure link',
                          icon: const Icon(
                            Icons.link,
                            size: 20,
                            color: GinataColors.secondary,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Secure download link copied (expires in 14 days).',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            Clipboard.setData(ClipboardData(text: dlUrl));
                          },
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GinataColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 14),
                          label: const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _downloadDoc(doc),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
