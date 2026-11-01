import 'package:qr_flutter/qr_flutter.dart';
import 'receipt_printer_service.dart';

/// 80mm va 58mm termal printerlar uchun 100% mos toza HTML/CSS chek generatori.
///
/// Ushbu modul brauzerda (Chrome, Safari, Firefox) hech qanday blob: URL yoki
/// yangi oyna ochmasdan, yashirin <iframe> orqali to'g'ridan-to'g'ri chop etish
/// uchun @page { size: 80mm auto; margin: 0; } standartidagi HTML chek yaratadi.
class ThermalHtmlGenerator {
  ThermalHtmlGenerator._();

  static const String chefHatSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 80" fill="none" stroke="black" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" style="width: 52px; height: 42px; display: block; margin: 0 auto;">
  <line x1="22" y1="64" x2="78" y2="64" stroke-width="2.2"/>
  <line x1="24" y1="72" x2="76" y2="72" stroke-width="2.2"/>
  <line x1="22" y1="64" x2="24" y2="72" stroke-width="2.2"/>
  <line x1="78" y1="64" x2="76" y2="72" stroke-width="2.2"/>
  <path d="M 22 64 C 6 64 6 36 20 30 C 14 18 32 8 42 16 C 46 8 54 8 58 16 C 68 8 86 18 80 30 C 94 36 94 64 78 64" stroke-width="2.4" fill="none"/>
  <line x1="43" y1="32" x2="43" y2="56" stroke-width="1.8"/>
  <path d="M 37 32 L 37 42 C 37 46 49 46 49 42 L 49 32" stroke-width="1.8" fill="none"/>
  <line x1="43" y1="32" x2="43" y2="42" stroke-width="1.8"/>
  <line x1="57" y1="32" x2="57" y2="56" stroke-width="1.8"/>
  <path d="M 57 32 C 57 44 52 48 52 56" stroke-width="1.8" fill="none"/>
</svg>''';

  static const String heartOutlineSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="2.0" stroke-linecap="round" stroke-linejoin="round" style="width: 14px; height: 14px; display: block; margin: 0 auto;">
  <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
</svg>''';

  /// Pure offline SVG QR Code generator (zero external network, vector crisp)
  static String generateQrSvg(String data, {double size = 90}) {
    if (data.trim().isEmpty) return '';
    try {
      final qr = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.L,
      );
      final qrImage = QrImage(qr);
      final moduleCount = qrImage.moduleCount;
      final buf = StringBuffer();
      buf.write(
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $moduleCount $moduleCount" width="$size" height="$size" style="display:block; margin: 0 auto;">');
      buf.write('<rect width="$moduleCount" height="$moduleCount" fill="#ffffff"/>');
      for (int x = 0; x < moduleCount; x++) {
        for (int y = 0; y < moduleCount; y++) {
          if (qrImage.isDark(y, x)) {
            buf.write('<rect x="$x" y="$y" width="1" height="1" fill="#000000"/>');
          }
        }
      }
      buf.write('</svg>');
      return buf.toString();
    } catch (_) {
      return '';
    }
  }

  /// 80mm / 58mm termo printer uchun to'liq HTML chek kodini shakllantiradi
  static String buildReceiptHtml(
    ReceiptPrintData data, {
    String? logoUrl,
  }) {
    final is58mm = data.is58mm;
    final widthMm = is58mm ? 58 : 80;
    final contentWidthMm = is58mm ? 50 : 72;

    final dateStr =
        '${data.dateTime.day.toString().padLeft(2, '0')}.${data.dateTime.month.toString().padLeft(2, '0')}.${data.dateTime.year}';
    final timeStr =
        '${data.dateTime.hour.toString().padLeft(2, '0')}:${data.dateTime.minute.toString().padLeft(2, '0')}';
    final formattedCheckId = ReceiptPrintData.formatCheckNumber(data.checkId);

    final cafeNameFirst =
        data.cafeName.contains(' ') ? data.cafeName.split(' ').first : 'Family';
    final cafeNameRest = data.cafeName.contains(' ')
        ? data.cafeName.split(' ').sublist(1).join(' ')
        : 'CAFE';

    final qrSvg = generateQrSvg(data.qrUrl, size: is58mm ? 75 : 90);

    final itemsRows = StringBuffer();
    for (int i = 0; i < data.items.length; i++) {
      final item = data.items[i];
      itemsRows.write('''
        <tr>
          <td class="col-no">${item.index}</td>
          <td class="col-name item-name">${_escapeHtml(item.name)}</td>
          <td class="col-qty">${item.qty} dona</td>
          <td class="col-price item-price">${ReceiptPrintData.formatMoney(item.unitPrice)} UZS</td>
        </tr>
      ''');
    }

    final hasCustomLogo = logoUrl != null &&
        logoUrl.trim().isNotEmpty &&
        !logoUrl.contains('default');

    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Chek #$formattedCheckId</title>
  <style>
    @page {
      size: ${widthMm}mm auto;
      margin: 0;
    }
    *, *:before, *:after {
      box-sizing: border-box;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    html, body {
      margin: 0 !important;
      padding: 0 !important;
      width: ${widthMm}mm;
      background: #ffffff;
      color: #000000;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      -webkit-font-smoothing: antialiased;
    }
    .receipt-container {
      width: ${contentWidthMm}mm;
      margin: 0 auto;
      padding: 2mm 0 3mm 0;
      background: #ffffff;
      page-break-after: avoid;
      break-after: avoid;
      page-break-inside: avoid;
      break-inside: avoid;
    }
    .header-logo {
      text-align: center;
      margin-bottom: 2px;
    }
    .header-title {
      display: flex;
      align-items: baseline;
      justify-content: center;
      gap: 6px;
      margin: 3px 0 2px 0;
      text-align: center;
    }
    .cafe-name-first {
      font-family: "Brush Script MT", cursive, Georgia, serif;
      font-size: ${is58mm ? '21px' : '26px'};
      font-weight: bold;
      font-style: italic;
      line-height: 1;
      color: #000;
    }
    .cafe-name-rest {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      font-size: ${is58mm ? '15px' : '19px'};
      font-weight: 900;
      letter-spacing: 2px;
      line-height: 1;
      color: #000;
    }
    .slogan-row {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      margin: 3px 0;
    }
    .slogan-line {
      width: 22px;
      height: 1px;
      background: #000;
    }
    .slogan-text {
      font-size: ${is58mm ? '8.5px' : '9.5px'};
      font-weight: 700;
      letter-spacing: 0.3px;
      text-align: center;
    }
    .solid-divider {
      height: 1px;
      background: #000000;
      margin: 4px 0;
    }
    .dashed-divider {
      border-bottom: 1px dashed #000000;
      margin: 5px 0;
    }
    .info-block {
      display: flex;
      justify-content: space-between;
      font-size: ${is58mm ? '8.5px' : '9.5px'};
      line-height: 1.4;
      padding: 2px 0;
    }
    .info-left {
      flex: 11;
      text-align: left;
      word-break: break-word;
    }
    .info-divider {
      width: 1px;
      background: #000;
      margin: 0 5px;
    }
    .info-right {
      flex: 9;
      text-align: left;
    }
    .info-bold {
      font-weight: bold;
    }
    .items-table {
      width: 100%;
      border-collapse: collapse;
      font-size: ${is58mm ? '9px' : '10px'};
      margin: 2px 0;
    }
    .items-table th {
      font-weight: 900;
      padding: 3px 0;
      border-bottom: 1px solid #000;
    }
    .items-table td {
      padding: 3px 0;
      vertical-align: middle;
    }
    .col-no {
      width: ${is58mm ? '18px' : '22px'};
      text-align: left;
    }
    .col-name {
      text-align: left;
    }
    .col-qty {
      width: ${is58mm ? '45px' : '55px'};
      text-align: center;
    }
    .col-price {
      width: ${is58mm ? '65px' : '80px'};
      text-align: right;
    }
    .item-name {
      font-weight: 700;
    }
    .item-price {
      font-weight: 800;
      white-space: nowrap;
    }
    .totals-block {
      margin: 4px 0;
      font-size: ${is58mm ? '9.5px' : '11px'};
    }
    .total-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 1.5px 0;
    }
    .total-subtotal {
      font-size: ${is58mm ? '12px' : '13.5px'};
      font-weight: 900;
    }
    .total-discount {
      font-size: ${is58mm ? '9px' : '10px'};
    }
    .total-grand {
      font-size: ${is58mm ? '13px' : '15px'};
      font-weight: 900;
      padding: 3px 0;
      border-top: 1px solid #000;
      border-bottom: 1px solid #000;
      margin-top: 3px;
    }
    .qr-section {
      text-align: center;
      margin: 6px 0;
    }
    .qr-box {
      display: inline-block;
      border: 1px solid #000;
      border-radius: 6px;
      padding: 4px;
      background: #fff;
    }
    .qr-text {
      font-size: ${is58mm ? '7.5px' : '8.5px'};
      font-weight: 700;
      margin-top: 4px;
      line-height: 1.3;
    }
    .footer-msg {
      text-align: center;
      font-style: italic;
      font-size: ${is58mm ? '9px' : '10px'};
      margin: 4px 0 2px 0;
    }
    .heart-icon {
      text-align: center;
      margin: 2px 0;
    }
    .footer-cafe-row {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      margin: 2px 0 4px 0;
    }
    .footer-cafe-name {
      font-size: ${is58mm ? '9px' : '10px'};
      font-weight: 800;
      letter-spacing: 0.8px;
    }
  </style>
</head>
<body>
  <div class="receipt-container">
    <!-- 1. LOGO & HEADER -->
    <div class="header-logo">
      ${hasCustomLogo ? '<img src="${_escapeHtml(logoUrl.trim())}" style="max-height: 48px; max-width: 140px; display: block; margin: 0 auto;" />' : chefHatSvg}
    </div>
    <div class="header-title">
      <span class="cafe-name-first">${_escapeHtml(cafeNameFirst)}</span>
      <span class="cafe-name-rest">${_escapeHtml(cafeNameRest)}</span>
    </div>
    <div class="slogan-row">
      <div class="slogan-line"></div>
      <div class="slogan-text">${_escapeHtml(data.slogan.isNotEmpty ? data.slogan : "Yaxshi ta'm • Baxtli onlar")}</div>
      <div class="slogan-line"></div>
    </div>
    <div class="solid-divider"></div>

    <!-- 2. INFO BLOK (2 ustun) -->
    <div class="info-block">
      <div class="info-left">
        <div class="info-bold">${_escapeHtml(data.cafeName)}</div>
        <div>${_escapeHtml(data.address)}</div>
        <div>${_escapeHtml(data.phone)}</div>
      </div>
      <div class="info-divider"></div>
      <div class="info-right">
        <div>$dateStr</div>
        <div>$timeStr</div>
        <div class="info-bold">Chek No: $formattedCheckId</div>
        <div class="info-bold">Kassir: ${_escapeHtml(data.cashierName)}</div>
      </div>
    </div>
    <div class="dashed-divider"></div>

    <!-- 3. MAHSULOTLAR JADVALI -->
    <table class="items-table">
      <thead>
        <tr>
          <th class="col-no">No</th>
          <th class="col-name">Nomi</th>
          <th class="col-qty">Miqdori</th>
          <th class="col-price">Narx</th>
        </tr>
      </thead>
      <tbody>
        $itemsRows
      </tbody>
    </table>
    <div class="solid-divider"></div>

    <!-- 4. TOTALS (Jami, Chegirma, To'lov) -->
    <div class="totals-block">
      <div class="total-row total-subtotal">
        <span>Jami:</span>
        <span>${ReceiptPrintData.formatMoney(data.subtotal)} so'm</span>
      </div>
      <div class="total-row total-discount">
        <span>Chegirma:</span>
        <span>${ReceiptPrintData.formatMoney(data.discount)} so'm</span>
      </div>
      <div class="total-row total-grand">
        <span>TO'LOV:</span>
        <span>${ReceiptPrintData.formatMoney(data.grandTotal)} so'm</span>
      </div>
    </div>
    <div class="dashed-divider"></div>

    <!-- 5. QR KOD -->
    ${qrSvg.isNotEmpty ? '''
    <div class="qr-section">
      <div class="qr-box">
        $qrSvg
      </div>
      <div class="qr-text">QR skaner qiling va<br/>Zavero web saytiga o'ting!</div>
    </div>
    ''' : ''}

    <!-- 6. FOOTER -->
    <div class="solid-divider"></div>
    <div class="footer-msg">${_escapeHtml(data.footerMessage)}</div>
    <div class="heart-icon">$heartOutlineSvg</div>
    <div class="footer-cafe-row">
      <div class="slogan-line"></div>
      <div class="footer-cafe-name">${_escapeHtml(data.cafeName)}</div>
      <div class="slogan-line"></div>
    </div>
  </div>
</body>
</html>
''';
  }

  /// Oshpaz / Oshxona cheki HTML formati
  static String buildKitchenTicketHtml({
    required List<ReceiptPrintItem> items,
    required String? tableNumber,
    required String? hallName,
    required String note,
    bool is58mm = false,
  }) {
    final widthMm = is58mm ? 58 : 80;
    final contentWidthMm = is58mm ? 50 : 72;
    final now = DateTime.now();
    final timeStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final itemsRows = StringBuffer();
    for (final item in items) {
      itemsRows.write('''
        <div style="display:flex; justify-content:space-between; align-items:center; padding: 4px 0; border-bottom: 0.5px solid #ddd;">
          <div style="font-size: 14px; font-weight: bold; flex: 1;">${_escapeHtml(item.name)}</div>
          <div style="font-size: 15px; font-weight: 900; width: 60px; text-align: right;">x${item.qty}</div>
        </div>
      ''');
    }

    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Oshpaz Cheki</title>
  <style>
    @page {
      size: ${widthMm}mm auto;
      margin: 0;
    }
    *, *:before, *:after {
      box-sizing: border-box;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    html, body {
      margin: 0 !important;
      padding: 0 !important;
      width: ${widthMm}mm;
      background: #ffffff;
      color: #000000;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    .kitchen-container {
      width: ${contentWidthMm}mm;
      margin: 0 auto;
      padding: 2mm 0 3mm 0;
      page-break-after: avoid;
      break-after: avoid;
      page-break-inside: avoid;
      break-inside: avoid;
    }
  </style>
</head>
<body>
  <div class="kitchen-container">
    <div style="text-align: center; font-size: 16px; font-weight: 900; letter-spacing: 1px;">OSHPAZ CHEKI</div>
    <div style="border-bottom: 1.5px solid #000; margin: 4px 0;"></div>
    ${tableNumber != null ? '<div style="font-size: 13px; font-weight: bold;">${_escapeHtml(hallName ?? '')} - Stol $tableNumber</div>' : ''}
    <div style="font-size: 11px; color: #444; margin-bottom: 4px;">$timeStr</div>
    <div style="border-bottom: 1px dashed #000; margin: 4px 0;"></div>
    $itemsRows
    ${note.trim().isNotEmpty ? '''
    <div style="border-top: 1px dashed #000; margin-top: 6px; padding-top: 4px; font-size: 12px; font-weight: bold;">
      Izoh: ${_escapeHtml(note)}
    </div>
    ''' : ''}
    <div style="border-bottom: 1.5px solid #000; margin-top: 6px;"></div>
  </div>
</body>
</html>''';
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }
}
