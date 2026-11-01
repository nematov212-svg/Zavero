import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('window.zaveroPrintReceiptHtml')
external JSPromise<JSBoolean>? _jsZaveroPrintReceiptHtml(JSString htmlContent);

@JS('eval')
external JSAny? _jsEval(JSString script);

/// Web muhitida chek HTML kodini yashirin <iframe> ga yozib,
/// window.open(blob:...) ishlatmasdan to'g'ridan-to'g'ri chop etadi.
Future<bool> printHtmlViaHiddenIframe(String htmlContent) async {
  try {
    try {
      final promise = _jsZaveroPrintReceiptHtml(htmlContent.toJS);
      if (promise != null) {
        final res = await promise.toDart;
        return res.toDart;
      }
    } catch (_) {
      // Agar window.zaveroPrintReceiptHtml hali mavjud bo'lmasa, uni yaratamiz
      _ensureJsPrinterFunction();
      final retryPromise = _jsZaveroPrintReceiptHtml(htmlContent.toJS);
      if (retryPromise != null) {
        final res = await retryPromise.toDart;
        return res.toDart;
      }
    }
  } catch (e) {
    debugPrint('⚠️ [WebPrint] printHtmlViaHiddenIframe error: $e');
  }
  return false;
}

void _ensureJsPrinterFunction() {
  try {
    _jsEval('''
      window.zaveroPrintReceiptHtml = function(htmlContent) {
        return new Promise(function(resolve) {
          try {
            var old = document.getElementById('zavero-receipt-iframe');
            if (old && old.parentNode) {
              old.parentNode.removeChild(old);
            }
            var iframe = document.createElement('iframe');
            iframe.id = 'zavero-receipt-iframe';
            iframe.style.position = 'fixed';
            iframe.style.right = '0';
            iframe.style.bottom = '0';
            iframe.style.width = '0';
            iframe.style.height = '0';
            iframe.style.border = '0';
            iframe.style.visibility = 'hidden';
            iframe.style.zIndex = '-9999';
            document.body.appendChild(iframe);

            var doc = iframe.contentWindow.document;
            doc.open();
            doc.write(htmlContent);
            doc.close();

            var cleaned = false;
            var cleanup = function() {
              if (cleaned) return;
              cleaned = true;
              setTimeout(function() {
                try {
                  if (iframe && iframe.parentNode) {
                    iframe.parentNode.removeChild(iframe);
                  }
                } catch(_) {}
              }, 1200);
            };

            try {
              iframe.contentWindow.addEventListener('afterprint', cleanup);
            } catch(_) {}

            var doPrint = function() {
              try {
                iframe.contentWindow.focus();
                iframe.contentWindow.print();
                resolve(true);
              } catch(e) {
                console.error('[Zavero] Iframe print error:', e);
                cleanup();
                resolve(false);
              }
            };

            if (iframe.contentDocument && iframe.contentDocument.readyState === 'complete') {
              setTimeout(doPrint, 100);
            } else {
              iframe.onload = function() {
                setTimeout(doPrint, 100);
              };
            }

            setTimeout(cleanup, 60000);
          } catch(err) {
            console.error('[Zavero] Setup error:', err);
            resolve(false);
          }
        });
      };
    '''.toJS);
  } catch (e) {
    debugPrint('⚠️ [WebPrint] _ensureJsPrinterFunction error: $e');
  }
}
