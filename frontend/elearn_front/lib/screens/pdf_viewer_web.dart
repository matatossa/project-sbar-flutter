import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

void createPdfIframe(String iframeId, String pdfUrl) {
  // Register the iframe element for web
  ui_web.platformViewRegistry.registerViewFactory(
    iframeId,
    (int viewId) {
      final iframe = html.IFrameElement()
        ..src = pdfUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    },
  );
}
