/// Stub for non-web platforms (Mobile / Desktop)
Future<bool> printHtmlViaHiddenIframe(String htmlContent) async {
  return false;
}

void showReceiptModalInPage(String htmlContent) {}

void setBrowserHash(String hash) {}

Future<String?> renderHtmlToPng(String htmlContent, {int widthPx = 576}) async {
  return null;
}

