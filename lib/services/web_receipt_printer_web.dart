import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('zaveroPrintReceiptHtml')
external JSPromise<JSBoolean>? _jsZaveroPrintReceiptHtml(JSString htmlContent);

@JS('zaveroShowReceiptModal')
external void _jsZaveroShowReceiptModal(JSString htmlContent);

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

/// Web muhitida mavjud chek HTML'ini sahifa ichidagi modalda (iframe srcdoc)
/// "Chop etish" va "Yopish" tugmalari bilan ko'rsatish
void showReceiptModalInPage(String htmlContent) {
  try {
    try {
      _jsZaveroShowReceiptModal(htmlContent.toJS);
    } catch (_) {
      _ensureJsPrinterFunction();
      _jsZaveroShowReceiptModal(htmlContent.toJS);
    }
  } catch (e) {
    debugPrint('⚠️ [WebPrint] showReceiptModalInPage error: $e');
  }
}

void _ensureJsPrinterFunction() {
  try {
    _jsEval(r'''
      if (!window.zaveroPrintReceiptHtml) {
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
              iframe.style.left = '0';
              iframe.style.top = '0';
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
                      var rect = container.getBoundingClientRect();
                      var scrollH = Math.max(container.scrollHeight, container.offsetHeight, rect.height);
                      var heightMm = Math.ceil(scrollH / 3.779527559) + 4;
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
      }

      if (!window.zaveroShowReceiptModal) {
        window.zaveroShowReceiptModal = function(htmlContent) {
          var prev = document.getElementById('zavero-receipt-modal');
          if (prev && prev.parentNode) prev.parentNode.removeChild(prev);

          var backdrop = document.createElement('div');
          backdrop.id = 'zavero-receipt-modal';
          backdrop.style.position = 'fixed';
          backdrop.style.inset = '0';
          backdrop.style.zIndex = '999999';
          backdrop.style.backgroundColor = 'rgba(15, 23, 42, 0.75)';
          backdrop.style.backdropFilter = 'blur(4px)';
          backdrop.style.webkitBackdropFilter = 'blur(4px)';
          backdrop.style.display = 'flex';
          backdrop.style.alignItems = 'center';
          backdrop.style.justifyContent = 'center';
          backdrop.style.padding = '16px';
          backdrop.style.boxSizing = 'border-box';

          var card = document.createElement('div');
          card.style.backgroundColor = '#f8fafc';
          card.style.borderRadius = '16px';
          card.style.width = '100%';
          card.style.maxWidth = '420px';
          card.style.maxHeight = '92vh';
          card.style.display = 'flex';
          card.style.flexDirection = 'column';
          card.style.boxShadow = '0 25px 50px -12px rgba(0, 0, 0, 0.35)';
          card.style.overflow = 'hidden';

          var header = document.createElement('div');
          header.style.padding = '14px 18px';
          header.style.backgroundColor = '#0f172a';
          header.style.color = '#ffffff';
          header.style.display = 'flex';
          header.style.alignItems = 'center';
          header.style.justifyContent = 'space-between';
          header.innerHTML = '<div style="font-weight:700;font-size:16px;display:flex;align-items:center;gap:8px;"><span>🧾</span><span>Chekni ko‘rish</span></div>' +
            '<button id="zavero-modal-close-icon" style="background:transparent;border:0;color:#94a3b8;font-size:22px;cursor:pointer;padding:0 4px;line-height:1;">&times;</button>';
          card.appendChild(header);

          var body = document.createElement('div');
          body.style.flex = '1';
          body.style.overflowY = 'auto';
          body.style.padding = '16px';
          body.style.display = 'flex';
          body.style.justifyContent = 'center';
          body.style.backgroundColor = '#f1f5f9';

          var iframe = document.createElement('iframe');
          iframe.style.width = '340px';
          iframe.style.minHeight = '520px';
          iframe.style.border = '0';
          iframe.style.borderRadius = '8px';
          iframe.style.backgroundColor = '#ffffff';
          iframe.style.boxShadow = '0 4px 6px -1px rgba(0,0,0,0.1)';
          iframe.srcdoc = htmlContent;

          iframe.onload = function() {
            try {
              var h = iframe.contentWindow.document.body.scrollHeight;
              if (h > 100) iframe.style.height = (h + 20) + 'px';
            } catch(_) {}
          };

          body.appendChild(iframe);
          card.appendChild(body);

          var footer = document.createElement('div');
          footer.style.padding = '12px 18px';
          footer.style.backgroundColor = '#ffffff';
          footer.style.borderTop = '1px solid #e2e8f0';
          footer.style.display = 'flex';
          footer.style.gap = '10px';
          footer.style.justifyContent = 'flex-end';

          var closeBtn = document.createElement('button');
          closeBtn.textContent = 'Yopish';
          closeBtn.style.padding = '10px 18px';
          closeBtn.style.borderRadius = '10px';
          closeBtn.style.border = '1px solid #cbd5e1';
          closeBtn.style.backgroundColor = '#f1f5f9';
          closeBtn.style.color = '#334155';
          closeBtn.style.fontSize = '14px';
          closeBtn.style.fontWeight = '600';
          closeBtn.style.cursor = 'pointer';

          var printBtn = document.createElement('button');
          printBtn.innerHTML = '🖨️ Chop etish';
          printBtn.style.padding = '10px 20px';
          printBtn.style.borderRadius = '10px';
          printBtn.style.border = '0';
          printBtn.style.backgroundColor = '#315efb';
          printBtn.style.color = '#ffffff';
          printBtn.style.fontSize = '14px';
          printBtn.style.fontWeight = '700';
          printBtn.style.cursor = 'pointer';
          printBtn.style.display = 'flex';
          printBtn.style.alignItems = 'center';
          printBtn.style.gap = '6px';

          var closeModal = function() {
            if (backdrop && backdrop.parentNode) backdrop.parentNode.removeChild(backdrop);
          };

          closeBtn.onclick = closeModal;
          header.querySelector('#zavero-modal-close-icon').onclick = closeModal;
          backdrop.onclick = function(e) {
            if (e.target === backdrop) closeModal();
          };

          printBtn.onclick = function() {
            if (window.zaveroPrintReceiptHtml) {
              window.zaveroPrintReceiptHtml(htmlContent);
            }
          };

          footer.appendChild(closeBtn);
          footer.appendChild(printBtn);
          card.appendChild(footer);

          backdrop.appendChild(card);
          document.body.appendChild(backdrop);
        };
      }
    '''.toJS);
  } catch (e) {
    debugPrint('⚠️ [WebPrint] _ensureJsPrinterFunction error: $e');
  }
}
