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
            iframe.style.left = '-9999px';
            iframe.style.top = '0';
            iframe.style.width = '80mm';
            iframe.style.height = '1200px';
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
              }, 1500);
            };

            try {
              iframe.contentWindow.addEventListener('afterprint', cleanup);
            } catch(_) {}

            var doPrint = function() {
              try {
                var container = doc.querySelector('.receipt-container') || doc.querySelector('.kitchen-container') || doc.body;
                var images = doc.images || [];
                var pending = images.length;

                var executePrint = function() {
                  try {
                    // 96 DPI: 1 inch = 25.4mm = 96px => 1mm = 96 / 25.4 ≈ 3.779527559px
                    var rect = container.getBoundingClientRect();
                    var scrollH = Math.max(container.scrollHeight, container.offsetHeight, rect.height);
                    var heightMm = Math.ceil(scrollH / 3.779527559) + 4; // 3-4mm cutter buffer
                    if (heightMm < 45) heightMm = 45;

                    var styleEl = doc.createElement('style');
                    styleEl.innerHTML =
                      '@page { size: 80mm ' + heightMm + 'mm !important; margin: 0 !important; }' +
                      'html, body { width: 80mm !important; height: ' + heightMm + 'mm !important; margin: 0 !important; padding: 0 !important; overflow: hidden !important; }' +
                      '.receipt-container, .kitchen-container { width: 72mm !important; margin: 0 auto !important; padding-left: 0 !important; padding-right: 0 !important; page-break-after: avoid !important; break-after: avoid !important; page-break-inside: avoid !important; break-inside: avoid !important; }';
                    doc.head.appendChild(styleEl);

                    setTimeout(function() {
                      try {
                        iframe.contentWindow.focus();
                        iframe.contentWindow.print();
                        resolve(true);
                      } catch(e) {
                        console.error('[Zavero] print execution error:', e);
                        cleanup();
                        resolve(false);
                      }
                    }, 120);
                  } catch(e) {
                    console.error('[Zavero] measurement error:', e);
                    iframe.contentWindow.focus();
                    iframe.contentWindow.print();
                    resolve(true);
                  }
                };

                if (pending === 0) {
                  executePrint();
                } else {
                  var loaded = 0;
                  var onImg = function() {
                    loaded++;
                    if (loaded >= pending) executePrint();
                  };
                  for (var i = 0; i < images.length; i++) {
                    if (images[i].complete) {
                      loaded++;
                    } else {
                      images[i].onload = onImg;
                      images[i].onerror = onImg;
                    }
                  }
                  if (loaded >= pending) {
                    executePrint();
                  } else {
                    setTimeout(executePrint, 1500);
                  }
                }
              } catch(e) {
                console.error('[Zavero] Iframe print setup error:', e);
                cleanup();
                resolve(false);
              }
            };

            if (iframe.contentDocument && iframe.contentDocument.readyState === 'complete') {
              setTimeout(doPrint, 80);
            } else {
              iframe.onload = function() {
                setTimeout(doPrint, 80);
              };
            }

            setTimeout(cleanup, 90000);
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
