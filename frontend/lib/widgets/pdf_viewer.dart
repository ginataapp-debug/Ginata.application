import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import '../theme/ginata_theme.dart';
import '../services/api_service.dart';

/// Saves raw document bytes to the device (native save dialog on mobile/desktop,
/// browser download on web). Returns true when a file was written.
Future<bool> saveDocumentToDevice(
  BuildContext context, {
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'application/pdf',
}) async {
  try {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: 'Save $fileName',
    );
    if (uri == null && !kIsWeb) return false;
    if (context.mounted) {
      final message = kIsWeb ? 'Download started for "$fileName".' : 'Saved "$fileName" to your device.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: GinataColors.successSage),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save file: $e'), backgroundColor: GinataColors.alertTerracotta),
      );
    }
    return false;
  }
}

/// Fetches bytes (when [apiPath] is given) and opens a fullscreen, fit-to-screen,
/// pinch/wheel-zoomable PDF viewer. Shows a loading indicator while preparing.
Future<void> openPdfViewer(
  BuildContext context, {
  required String title,
  required String fileName,
  Uint8List? bytes,
  String? apiPath,
}) async {
  Uint8List? data = bytes;
  if (data == null && apiPath != null) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: GinataColors.primary),
                SizedBox(height: 16),
                Text('Preparing document…', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      data = await ApiService.downloadBytes(apiPath);
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: GinataColors.alertTerracotta),
        );
      }
      return;
    }
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  if (data == null || data.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This document has no downloadable file yet.'), backgroundColor: GinataColors.alertTerracotta),
      );
    }
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PdfViewerScreen(title: title, fileName: fileName, bytes: data!),
    ),
  );
}

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String fileName;
  final Uint8List bytes;

  const PdfViewerScreen({super.key, required this.title, required this.fileName, required this.bytes});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfControllerPinch _controller;
  int _page = 1;
  int _pages = 0;
  bool _checking = true;
  bool _supported = true;
  bool _saving = false;
  Size _viewport = Size.zero;
  bool _needsFit = true;
  bool _fitScheduled = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // PDF.js transfers its buffer to a worker; retain the original for downloads.
    _controller = PdfControllerPinch(document: PdfDocument.openData(Uint8List.fromList(widget.bytes)));
    _controller.addListener(_scheduleInitialFit);
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    bool ok = true;
    try {
      ok = await hasPdfSupport();
    } catch (_) {
      ok = false;
    }
    if (mounted) setState(() { _supported = ok; _checking = false; });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoomBy(double factor) {
    if (_viewport == Size.zero) return;
    final m = _controller.value.clone();
    final scale = m.getMaxScaleOnAxis();
    if (scale == 0) return;
    final target = (scale * factor).clamp(0.05, 12.0);
    final real = target / scale;
    final cx = _viewport.width / 2;
    final cy = _viewport.height / 2;
    final result = Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..multiply(Matrix4.identity()..scaleByDouble(real, real, 1.0, 1.0))
      ..translateByDouble(-cx, -cy, 0, 1)
      ..multiply(m);
    _controller.value = result;
    setState(() {});
  }

  void _scheduleInitialFit() {
    if (!_needsFit || _fitScheduled || !mounted) return;
    _fitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitScheduled = false;
      if (mounted) _fitToScreen();
    });
  }

  void _fitToScreen({int? page}) {
    final targetPage = page ?? _page;
    if (_viewport.isEmpty || (_controller.pagesCount ?? 0) < targetPage) return;
    final rect = _controller.getPageRect(targetPage)?.inflate(14);
    if (rect == null || rect.isEmpty) return;
    final scale = math.min(_viewport.width / rect.width, _viewport.height / rect.height);
    _needsFit = false;
    _controller.value = Matrix4.identity()
      ..translateByDouble(
        _viewport.width / 2 - rect.center.dx * scale,
        _viewport.height / 2 - rect.center.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
    setState(() => _page = targetPage);
  }

  Future<void> _download() async {
    setState(() => _saving = true);
    await saveDocumentToDevice(context, bytes: widget.bytes, fileName: widget.fileName);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final zoomPct = (_controller.zoomRatio * 100).round();
    return Scaffold(
      backgroundColor: const Color(0xFF1B2430),
      appBar: AppBar(
        backgroundColor: GinataColors.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
            Text(widget.fileName, style: const TextStyle(fontSize: 10, color: Colors.white70), overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download_rounded),
            onPressed: _saving ? null : _download,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : !_supported
              ? _buildFallback()
              : Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
                          if (_viewport != viewport) {
                            _viewport = viewport;
                            _needsFit = true;
                            _scheduleInitialFit();
                          }
                          if (_loadError != null) {
                            return _buildError();
                          }
                          return PdfViewPinch(
                            controller: _controller,
                            padding: 14,
                            minScale: 0.05,
                            maxScale: 12.0,
                            backgroundDecoration: const BoxDecoration(color: Color(0xFFE9EDF2)),
                            onInteractionEnd: (_) => setState(() {}),
                            onPageChanged: (p) => setState(() => _page = p),
                            onDocumentLoaded: (doc) => setState(() => _pages = doc.pagesCount),
                            onDocumentError: (e) => setState(() => _loadError = e.toString()),
                          );
                        },
                      ),
                    ),
                    _buildToolbar(zoomPct),
                  ],
                ),
    );
  }

  Widget _buildToolbar(int zoomPct) {
    return Container(
      color: GinataColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Previous page',
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: _page > 1 ? () => _fitToScreen(page: _page - 1) : null,
                  ),
                  Text(
                    _pages > 0 ? 'Page $_page / $_pages' : 'Page $_page',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: _page < _pages ? () => _fitToScreen(page: _page + 1) : null,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(tooltip: 'Zoom out', icon: const Icon(Icons.zoom_out, color: Colors.white, size: 20), onPressed: () => _zoomBy(1 / 1.25)),
                  SizedBox(
                    width: 48,
                    child: Text('$zoomPct%', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(tooltip: 'Zoom in', icon: const Icon(Icons.zoom_in, color: Colors.white, size: 20), onPressed: () => _zoomBy(1.25)),
                  IconButton(tooltip: 'Fit to screen', icon: const Icon(Icons.fit_screen, color: Colors.white, size: 20), onPressed: _fitToScreen),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            const Text('Could not render this PDF', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_loadError ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: GinataColors.primary),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download instead'),
              onPressed: _download,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.white70, size: 52),
            const SizedBox(height: 14),
            const Text('Inline preview unavailable', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'This platform cannot render PDFs inline. Download the file to open it in your preferred PDF app.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: GinataColors.primary, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
              icon: const Icon(Icons.download_rounded),
              label: Text(_saving ? 'Saving…' : 'Download ${widget.fileName}'),
              onPressed: _saving ? null : _download,
            ),
          ],
        ),
      ),
    );
  }
}