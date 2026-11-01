import 'web_receipt_printer_stub.dart'
    if (dart.library.js_interop) 'web_receipt_printer_web.dart';

/// Web va Native printer ko'prigi (HTML chop etish va modalda ko'rish)
class WebReceiptPrinter {
  WebReceiptPrinter._();

  /// HTML chekni yashirin iframe orqali chop etish
  static Future<bool> printHtml(String htmlContent) async {
    return printHtmlViaHiddenIframe(htmlContent);
  }

  /// HTML chekni sahifa ichidagi modalda (iframe srcdoc) ko'rsatish
  static void showModal(String htmlContent) {
    showReceiptModalInPage(htmlContent);
  }

  /// Brauzer manzilidagi hashni yangilash
  static void setHash(String hash) {
    setBrowserHash(hash);
  }
}
