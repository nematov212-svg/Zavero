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

  /// Mavjud chek HTML'ini 1:1 formatda PNG rasmga (base64) render qilish
  static Future<String?> renderToPng(String htmlContent, {int widthPx = 576}) async {
    return renderHtmlToPng(htmlContent, widthPx: widthPx);
  }

  static Future<String?> renderHtmlToPng(String htmlContent, {int widthPx = 576}) async {
    return renderToPng(htmlContent, widthPx: widthPx);
  }
}

