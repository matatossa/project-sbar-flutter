import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:provider/provider.dart';
import '../widgets/app_navbar.dart';
import '../services/auth_service.dart';

// Conditional imports for web
import 'pdf_viewer_web_stub.dart'
    if (dart.library.html) 'pdf_viewer_web.dart' as web;

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerScreen({
    Key? key,
    required this.pdfUrl,
    required this.title,
  }) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final String _iframeId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _iframeId = 'pdf-iframe-${DateTime.now().millisecondsSinceEpoch}';
      web.createPdfIframe(_iframeId, widget.pdfUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: AppNavbar(
        title: widget.title.length > 40 
            ? '${widget.title.substring(0, 40)}...' 
            : widget.title,
        showBackButton: true,
      ),
      body: kIsWeb
          ? _buildWebViewer()
          : _buildMobileViewer(),
    );
  }

  Widget _buildWebViewer() {
    // For web, use iframe to display PDF inline
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(16),
      child: HtmlElementView(viewType: _iframeId),
    );
  }

  Widget _buildMobileViewer() {
    // For mobile/desktop, use Syncfusion PDF viewer
    final authService = Provider.of<AuthService>(context, listen: false);
    final headers = <String, String>{
      'Authorization': 'Bearer ${authService.jwt}',
    };
    
    return SfPdfViewer.network(
      widget.pdfUrl,
      headers: headers,
    );
  }
}
