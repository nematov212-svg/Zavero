import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Clean model representing a line item on the printed thermal receipt.
class ReceiptPrintItem {
  final int index;
  final String name;
  final int qty;
  final double unitPrice;
  final double lineTotal;
  final String? note;

  const ReceiptPrintItem({
    required this.index,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.note,
  });
}

/// Unified transaction data model for thermal printing.
class ReceiptPrintData {
  final String checkId;
  final DateTime dateTime;
  final String cashierName;
  final String cafeName;
  final String address;
  final String phone;
  final String slogan;
  final String footerMessage;
  final String qrUrl;
  final String? tableNumber;
  final String? hallName;
  final List<ReceiptPrintItem> items;
  final double subtotal;
  final double discount;
  final double grandTotal;
  final String paymentMethod; // 'cash', 'card', 'split'
  final bool is58mm;

  const ReceiptPrintData({
    required this.checkId,
    required this.dateTime,
    required this.cashierName,
    required this.cafeName,
    required this.address,
    required this.phone,
    required this.slogan,
    required this.footerMessage,
    required this.qrUrl,
    this.tableNumber,
    this.hallName,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.grandTotal,
    required this.paymentMethod,
    this.is58mm = false,
  });

  static String formatMoney(num amount) {
    final s = amount.round().toString();
    final buffer = StringBuffer();
    var count = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write(' ');
      }
    }
    return buffer.toString().split('').reversed.join();
  }

  static String formatCheckNumber(String rawId) {
    final digits = RegExp(r'\d+').allMatches(rawId).map((m) => m.group(0)).join();
    if (digits.isEmpty) return '000125';
    if (digits.length >= 6) return digits.substring(digits.length - 6);
    return digits.padLeft(6, '0');
  }
}

/// ESC/POS Command generator supporting 80mm and 58mm thermal printers.
class EscPosBuilder {
  final int width; // 48 for 80mm, 32 for 58mm
  final List<int> _bytes = [];

  EscPosBuilder({this.width = 48}) {
    _init();
  }

  void _init() {
    _bytes.addAll([0x1B, 0x40]); // ESC @: Initialize
    _bytes.addAll([0x1B, 0x74, 17]); // ESC t 17: CP866
    _bytes.addAll([0x1B, 0x33, 26]); // ESC 3 26: Compact line spacing
  }

  // CP866 text encoder with support for Uzbek Cyrillic and Latin
  static List<int> encodeText(String s) {
    final res = <int>[];
    for (final rune in s.runes) {
      if (rune < 128) {
        res.add(rune);
      } else {
        switch (rune) {
          case 0x0410: res.add(0x80); break;
          case 0x0411: res.add(0x81); break;
          case 0x0412: res.add(0x82); break;
          case 0x0413: res.add(0x83); break;
          case 0x0414: res.add(0x84); break;
          case 0x0415: res.add(0x85); break;
          case 0x0416: res.add(0x86); break;
          case 0x0417: res.add(0x87); break;
          case 0x0418: res.add(0x88); break;
          case 0x0419: res.add(0x89); break;
          case 0x041A: res.add(0x8A); break;
          case 0x041B: res.add(0x8B); break;
          case 0x041C: res.add(0x8C); break;
          case 0x041D: res.add(0x8D); break;
          case 0x041E: res.add(0x8E); break;
          case 0x041F: res.add(0x8F); break;
          case 0x0420: res.add(0x90); break;
          case 0x0421: res.add(0x91); break;
          case 0x0422: res.add(0x92); break;
          case 0x0423: res.add(0x93); break;
          case 0x0424: res.add(0x94); break;
          case 0x0425: res.add(0x95); break;
          case 0x0426: res.add(0x96); break;
          case 0x0427: res.add(0x97); break;
          case 0x0428: res.add(0x98); break;
          case 0x0429: res.add(0x99); break;
          case 0x042A: res.add(0x9A); break;
          case 0x042B: res.add(0x9B); break;
          case 0x042C: res.add(0x9C); break;
          case 0x042D: res.add(0x9D); break;
          case 0x042E: res.add(0x9E); break;
          case 0x042F: res.add(0x9F); break;
          case 0x0430: res.add(0xA0); break;
          case 0x0431: res.add(0xA1); break;
          case 0x0432: res.add(0xA2); break;
          case 0x0433: res.add(0xA3); break;
          case 0x0434: res.add(0xA4); break;
          case 0x0435: res.add(0xA5); break;
          case 0x0436: res.add(0xA6); break;
          case 0x0437: res.add(0xA7); break;
          case 0x0438: res.add(0xA8); break;
          case 0x0439: res.add(0xA9); break;
          case 0x043A: res.add(0xAA); break;
          case 0x043B: res.add(0xAB); break;
          case 0x043C: res.add(0xAC); break;
          case 0x043D: res.add(0xAD); break;
          case 0x043E: res.add(0xAE); break;
          case 0x043F: res.add(0xAF); break;
          case 0x0440: res.add(0xE0); break;
          case 0x0441: res.add(0xE1); break;
          case 0x0442: res.add(0xE2); break;
          case 0x0443: res.add(0xE3); break;
          case 0x0444: res.add(0xE4); break;
          case 0x0445: res.add(0xE5); break;
          case 0x0446: res.add(0xE6); break;
          case 0x0447: res.add(0xE7); break;
          case 0x0448: res.add(0xE8); break;
          case 0x0449: res.add(0xE9); break;
          case 0x044A: res.add(0xEA); break;
          case 0x044B: res.add(0xEB); break;
          case 0x044C: res.add(0xEC); break;
          case 0x044D: res.add(0xED); break;
          case 0x044E: res.add(0xEE); break;
          case 0x044F: res.add(0xEF); break;
          case 0x2022: res.add(0x2A); break; // • -> *
          case 0x2014: res.add(0x2D); break; // — -> -
          case 0x2116: res.add(0x23); break; // № -> #
          case 0x2661: res.add(0x3C); res.add(0x33); break; // ♡ -> <3
          default: res.add(0x3F);
        }
      }
    }
    return res;
  }

  void printLine([String text = '']) {
    if (text.isNotEmpty) {
      _bytes.addAll(encodeText(text));
    }
    _bytes.add(0x0A); // LF
  }

  void alignLeft() => _bytes.addAll([0x1B, 0x61, 0]);
  void alignCenter() => _bytes.addAll([0x1B, 0x61, 1]);
  void alignRight() => _bytes.addAll([0x1B, 0x61, 2]);

  void boldOn() => _bytes.addAll([0x1B, 0x45, 1]);
  void boldOff() => _bytes.addAll([0x1B, 0x45, 0]);

  void doubleSizeOn() => _bytes.addAll([0x1D, 0x21, 0x11]);
  void normalSize() => _bytes.addAll([0x1D, 0x21, 0x00]);

  void divider() {
    _bytes.addAll(encodeText('-' * width));
    _bytes.add(0x0A);
  }

  void dashedDivider() {
    final s = StringBuffer();
    while (s.length < width) {
      s.write('- ');
    }
    _bytes.addAll(encodeText(s.toString().substring(0, width)));
    _bytes.add(0x0A);
  }

  void twoColumnRow(String left, String right) {
    final maxLeft = width - right.length - 1;
    var l = left;
    if (l.length > maxLeft && maxLeft > 3) {
      l = '${l.substring(0, maxLeft - 1)}.';
    }
    final spaces = width - l.length - right.length;
    final gap = spaces > 1 ? ' ' * spaces : ' ';
    printLine('$l$gap$right');
  }

  void qrCode(String url, {int size = 5}) {
    final data = utf8.encode(url);
    final len = data.length + 3;
    final pL = len & 0xFF;
    final pH = (len >> 8) & 0xFF;

    alignCenter();
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size]);
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);
    _bytes.addAll([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30, ...data]);
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
  }

  void feedAndCut({int feedLines = 3}) {
    _bytes.addAll([0x1B, 0x32]);
    _bytes.addAll([0x1B, 0x64, feedLines]);
    _bytes.addAll([0x1D, 0x56, 0x01]); // Partial cut
  }

  List<int> toBytes() => List<int>.unmodifiable(_bytes);

  /// Generates the complete 80mm/58mm ESC/POS receipt strictly matching the reference receipt.
  static List<int> buildReceiptBytes(ReceiptPrintData data, {int width = 48}) {
    final builder = EscPosBuilder(width: width);

    // ── A. HEADER (Chef hat & Cafe Name) ──────────────────────────
    builder.alignCenter();
    builder.printLine('--- [ CHEF HAT ] ---');

    builder.boldOn();
    builder.doubleSizeOn();
    builder.printLine(data.cafeName);
    builder.normalSize();
    builder.boldOff();

    if (data.slogan.isNotEmpty) {
      builder.printLine('--- ${data.slogan} ---');
    }
    builder.divider();

    // ── B. BUSINESS INFORMATION (2 Columns) ──────────────────────
    final dateStr =
        '${data.dateTime.day.toString().padLeft(2, '0')}.${data.dateTime.month.toString().padLeft(2, '0')}.${data.dateTime.year}';
    final timeStr =
        '${data.dateTime.hour.toString().padLeft(2, '0')}:${data.dateTime.minute.toString().padLeft(2, '0')}';
    final formattedCheckId = ReceiptPrintData.formatCheckNumber(data.checkId);

    builder.alignLeft();
    builder.twoColumnRow(data.cafeName, dateStr);
    builder.twoColumnRow(data.address, timeStr);
    builder.twoColumnRow(data.phone, 'Chek #: $formattedCheckId');
    builder.twoColumnRow('', 'Kassir: ${data.cashierName}');
    builder.dashedDivider();

    // ── C. PRODUCT TABLE (4 Columns: No, Nomi, Miqdori, Narx) ─
    builder.boldOn();
    if (width >= 48) {
      // 80mm: No (3), Nomi (20), Miqdori (10), Narx (15) = 48
      builder.printLine(
        '${'No'.padRight(3)}${'Nomi'.padRight(20)}${'Miqdori'.padRight(10)}${'Narx'.padLeft(15)}',
      );
    } else {
      // 58mm: No (3), Nomi (11), Miq (6), Narx (12) = 32
      builder.printLine(
        '${'No'.padRight(3)}${'Nomi'.padRight(11)}${'Miq'.padRight(6)}${'Narx'.padLeft(12)}',
      );
    }
    builder.boldOff();
    builder.divider();

    for (final item in data.items) {
      final name = item.name;
      final qtyStr = '${item.qty} dona';
      final priceStr = '${ReceiptPrintData.formatMoney(item.unitPrice)} UZS';

      if (width >= 48) {
        if (name.length <= 19) {
          final noStr = '${item.index}'.padRight(3);
          final nStr = name.padRight(20);
          final qStr = qtyStr.padRight(10);
          final pStr = priceStr.padLeft(15);
          builder.printLine('$noStr$nStr$qStr$pStr');
        } else {
          builder.boldOn();
          builder.printLine('${item.index}. $name');
          builder.boldOff();
          final qStr = qtyStr.padRight(10);
          final pStr = priceStr.padLeft(15);
          builder.printLine('   ${qStr.padRight(30)}$pStr');
        }
      } else {
        if (name.length <= 10) {
          final noStr = '${item.index}'.padRight(3);
          final nStr = name.padRight(11);
          final qStr = '${item.qty}'.padRight(6);
          final pStr = priceStr.padLeft(12);
          builder.printLine('$noStr$nStr$qStr$pStr');
        } else {
          builder.printLine('${item.index}. $name');
          builder.twoColumnRow('   ${item.qty} dona', priceStr);
        }
      }
    }
    builder.divider();

    // ── D. TOTALS BLOCK (Jami, Chegirma, To'lov - ramkasiz) ───────
    builder.boldOn();
    builder.twoColumnRow(
      'Jami:',
      '${ReceiptPrintData.formatMoney(data.subtotal)} so\'m',
    );
    builder.boldOff();
    builder.twoColumnRow(
      'Chegirma:',
      '${ReceiptPrintData.formatMoney(data.discount)} so\'m',
    );
    builder.boldOn();
    builder.doubleSizeOn();
    builder.twoColumnRow(
      'To\'lov:',
      '${ReceiptPrintData.formatMoney(data.grandTotal)} so\'m',
    );
    builder.normalSize();
    builder.boldOff();
    builder.dashedDivider();

    // ── E. QR CODE (Centered + prompt) ───────────────────────────
    if (data.qrUrl.isNotEmpty) {
      builder.alignCenter();
      builder.printLine();
      builder.qrCode(data.qrUrl, size: width >= 48 ? 6 : 4);
      builder.printLine();
      builder.boldOn();
      builder.printLine('QR skaner qiling va');
      builder.printLine('Zavero web saytiga o\'ting!');
      builder.boldOff();
      builder.divider();
    }

    // ── F. FOOTER ────────────────────────────────────────────────
    builder.alignCenter();
    builder.printLine(data.footerMessage);
    builder.printLine('<3');
    builder.boldOn();
    builder.printLine('-- ${data.cafeName} --');
    builder.boldOff();

    // Clean cut
    builder.feedAndCut(feedLines: 3);

    return builder.toBytes();
  }
}

/// PDF Receipt Generator guaranteeing exact 80mm thermal roll format.
/// Matches the reference thermal receipt 100% with tight roll height.
class ThermalPdfGenerator {
  ThermalPdfGenerator._();

  static PdfPageFormat getFormat(ReceiptPrintData data, {bool is58mm = false}) {
    final double widthPt = (is58mm ? 58.0 : 80.0) * PdfPageFormat.mm;
    const double marginVerticalPt = 1.0 * PdfPageFormat.mm;
    const double marginHorizontalPt = 2.0 * PdfPageFormat.mm;

    // Aniq ixcham balandlik: pastda ortiqcha bo'sh joy qoldirmasdan, chiroyli va qulay chiqishini ta'minlaydi
    final double qrHeight = data.qrUrl.isNotEmpty ? (is58mm ? 70.0 : 80.0) : 0.0;
    final double baseHeight = (is58mm ? 208.0 : 220.0) + qrHeight;
    final double dynamicItemsHeight = data.items.length * (is58mm ? 14.0 : 13.0);
    final double totalHeight = baseHeight + dynamicItemsHeight;

    return PdfPageFormat(
      widthPt,
      totalHeight,
      marginTop: marginVerticalPt,
      marginBottom: marginVerticalPt,
      marginLeft: marginHorizontalPt,
      marginRight: marginHorizontalPt,
    );
  }

  static pw.Document buildReceiptDoc(ReceiptPrintData data, {bool is58mm = false}) {
    final format = getFormat(data, is58mm: is58mm);
    final doc = pw.Document();
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontOblique = pw.Font.helveticaOblique();

    final dateStr =
        '${data.dateTime.day.toString().padLeft(2, '0')}.${data.dateTime.month.toString().padLeft(2, '0')}.${data.dateTime.year}';
    final timeStr =
        '${data.dateTime.hour.toString().padLeft(2, '0')}:${data.dateTime.minute.toString().padLeft(2, '0')}';
    final formattedCheckId = ReceiptPrintData.formatCheckNumber(data.checkId);

    // Chef Hat Outline SVG with Fork & Knife inside
    const chefHatSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 80" fill="none" stroke="black" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
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

    const heartOutlineSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="2.0" stroke-linecap="round" stroke-linejoin="round">
  <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
</svg>''';

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) {
          final cafeNameFirst = data.cafeName.contains(' ') ? data.cafeName.split(' ').first : 'Family';
          final cafeNameRest = data.cafeName.contains(' ') ? data.cafeName.split(' ').sublist(1).join(' ') : 'CAFE';

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // ── 1. HEADER: Chef Hat Logo + Family Cafe + Slogan ───────────
              pw.Center(
                child: pw.SvgImage(
                  svg: chefHatSvg,
                  width: is58mm ? 44 : 52,
                  height: is58mm ? 35 : 42,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    cafeNameFirst,
                    style: pw.TextStyle(
                      font: fontOblique,
                      fontSize: is58mm ? 14.5 : 17.0,
                      fontWeight: pw.FontWeight.bold,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Text(
                    cafeNameRest,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: is58mm ? 11.0 : 13.0,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                pw.Container(width: 18, height: 0.8, color: PdfColors.black),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text("Yaxshi ta'm ", style: pw.TextStyle(font: font, fontSize: 7.0, fontWeight: pw.FontWeight.bold)),
                      pw.Container(width: 2.2, height: 2.2, decoration: const pw.BoxDecoration(color: PdfColors.black, shape: pw.BoxShape.circle)),
                      pw.Text(" Baxtli onlar", style: pw.TextStyle(font: font, fontSize: 7.0, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Container(width: 18, height: 0.8, color: PdfColors.black),
              ]),
              pw.SizedBox(height: 3),
              pw.Container(height: 1.0, color: PdfColors.black),
              pw.SizedBox(height: 3),

              // ── 2. INFO BLOK (2 Columns divided by vertical line) ─────────
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  // Chap ustun: Kafe, Manzil, Telefon
                  pw.Expanded(
                    flex: 11,
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(data.cafeName, style: pw.TextStyle(font: fontBold, fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2.0),
                      pw.Text(data.address, style: pw.TextStyle(font: font, fontSize: 6.8)),
                      pw.SizedBox(height: 2.0),
                      pw.Text(data.phone, style: pw.TextStyle(font: font, fontSize: 6.8)),
                    ]),
                  ),
                  pw.Container(width: 0.8, height: 32, color: PdfColors.black, margin: const pw.EdgeInsets.symmetric(horizontal: 4)),
                  // O'ng ustun: Sana, Vaqt, Chek No, Kassir
                  pw.Expanded(
                    flex: 9,
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(dateStr, style: pw.TextStyle(font: font, fontSize: 6.8)),
                      pw.SizedBox(height: 2.0),
                      pw.Text(timeStr, style: pw.TextStyle(font: font, fontSize: 6.8)),
                      pw.SizedBox(height: 2.0),
                      pw.Text('Chek No: $formattedCheckId', style: pw.TextStyle(font: fontBold, fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2.0),
                      pw.Text('Kassir: ${data.cashierName}', style: pw.TextStyle(font: fontBold, fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ),
                ]),
              ),
              pw.SizedBox(height: 3),
              // Dashed divider line
              pw.Text(
                '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(font: font, fontSize: 6.0, color: PdfColors.black),
              ),
              pw.SizedBox(height: 2),

              // ── 3. PRODUCT TABLE HEADER (4 Columns: No | Nomi | Miqdori | Narx) ──
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.0),
                child: pw.Row(children: [
                  pw.SizedBox(width: is58mm ? 14 : 18, child: pw.Text('No', style: pw.TextStyle(font: fontBold, fontSize: 7.2, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(child: pw.Text('Nomi', style: pw.TextStyle(font: fontBold, fontSize: 7.2, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(width: is58mm ? 36 : 46, child: pw.Text('Miqdori', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold, fontSize: 7.2, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(width: is58mm ? 52 : 72, child: pw.Text('Narx', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.2, fontWeight: pw.FontWeight.bold))),
                ]),
              ),
              pw.Container(height: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 2),

              // ── 4. PRODUCTS LIST ─────────────────────────────────────────
              ...List.generate(data.items.length, (index) {
                final item = data.items[index];
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.6),
                  child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                    pw.SizedBox(width: is58mm ? 14 : 18, child: pw.Text('${item.index}', style: pw.TextStyle(font: font, fontSize: 7.2))),
                    pw.Expanded(child: pw.Text(item.name, style: pw.TextStyle(font: fontBold, fontSize: 7.3, fontWeight: pw.FontWeight.bold))),
                    pw.SizedBox(width: is58mm ? 36 : 46, child: pw.Text('${item.qty} dona', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 7.2))),
                    pw.SizedBox(width: is58mm ? 52 : 72, child: pw.Text('${ReceiptPrintData.formatMoney(item.unitPrice)} UZS', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.3, fontWeight: pw.FontWeight.bold))),
                  ]),
                );
              }),
              pw.SizedBox(height: 2),
              pw.Container(height: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 4),

              // ── 5. TOTALS BLOCK (Jami, Chegirma, To'lov - ramkasiz) ───────
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Jami:', style: pw.TextStyle(font: fontBold, fontSize: is58mm ? 8.5 : 9.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text("${ReceiptPrintData.formatMoney(data.subtotal)} so'm", style: pw.TextStyle(font: fontBold, fontSize: is58mm ? 8.5 : 9.5, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.0),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Chegirma:', style: pw.TextStyle(font: font, fontSize: 7.2)),
                    pw.Text("${ReceiptPrintData.formatMoney(data.discount)} so'm", style: pw.TextStyle(font: font, fontSize: 7.2)),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("To'lov:", style: pw.TextStyle(font: fontBold, fontSize: is58mm ? 9.5 : 10.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text("${ReceiptPrintData.formatMoney(data.grandTotal)} so'm", style: pw.TextStyle(font: fontBold, fontSize: is58mm ? 9.5 : 10.5, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(font: font, fontSize: 6.0, color: PdfColors.black),
              ),
              pw.SizedBox(height: 8),

              // ── 6. QR CODE IN THIN ROUNDED BOX ───────────────────────────
              if (data.qrUrl.isNotEmpty) ...[
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(3.5),
                    decoration: pw.BoxDecoration(
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.black, width: 1.0),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: data.qrUrl,
                      width: is58mm ? 40 : 48,
                      height: is58mm ? 40 : 48,
                      color: PdfColors.black,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'QR skaner qiling va\nZavero web saytiga o\'ting!',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: fontBold, fontSize: 6.6, color: PdfColors.black),
                  ),
                ),
                pw.SizedBox(height: 8),
              ],

              // ── 7. FOOTER: Chiziq + Rahmat matni + Yurakcha + Kafe nomi ──
              pw.Container(height: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  data.footerMessage,
                  style: pw.TextStyle(font: fontOblique, fontSize: 8.2, fontStyle: pw.FontStyle.italic),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.SvgImage(svg: heartOutlineSvg, width: 10, height: 10),
              ),
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                pw.Container(width: 18, height: 0.8, color: PdfColors.black),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                  child: pw.Text(
                    data.cafeName,
                    style: pw.TextStyle(font: fontBold, fontSize: 8.2, fontWeight: pw.FontWeight.bold, letterSpacing: 0.6),
                  ),
                ),
                pw.Container(width: 18, height: 0.8, color: PdfColors.black),
              ]),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    return doc;
  }
}

/// Primary Printer Service coordinating network (ESC/POS over TCP) and system printing.
class ReceiptPrinterService {
  ReceiptPrinterService._();

  /// Prints receipt via configured network Wi-Fi/LAN printer (TCP port 9100)
  /// or falls back cleanly to the system thermal print dialog.
  static Future<void> printReceipt({
    required ReceiptPrintData data,
    required String? printerIp,
    required int printerPort,
    required int paperWidthMm,
    required bool isPrinterConfigured,
    bool isAutoCheckout = false,
  }) async {
    final is58mm = paperWidthMm == 58;

    // 1. Direct Wi-Fi / LAN ESC/POS socket connection
    if (isPrinterConfigured && printerIp != null && printerIp.trim().isNotEmpty) {
      final ip = printerIp.trim();
      final port = printerPort > 0 ? printerPort : 9100;
      final bytes = EscPosBuilder.buildReceiptBytes(
        data,
        width: is58mm ? 32 : 48,
      );

      Socket? socket;
      try {
        socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
        socket.add(bytes);
        await socket.flush();
        await Future.delayed(const Duration(milliseconds: 150));
        return;
      } on SocketException catch (e) {
        debugPrint('⚠️ [Printer] Wi-Fi/LAN printerga ulanib bo\'lmadi: $e');
        throw Exception(
          'Printerga ulanib bo\'lmadi ($ip:$port). Wi-Fi tarmog\'ini tekshiring.',
        );
      } finally {
        try {
          await socket?.close();
        } catch (_) {}
      }
    }

    // 2. Fallback to System / Browser Thermal Print Dialog
    if (kIsWeb && isAutoCheckout) {
      debugPrint('ℹ️ [Web] Avtomatik to\'lovda printer sozlanmagan, dialog ochilmadi.');
      return;
    }

    final doc = ThermalPdfGenerator.buildReceiptDoc(data, is58mm: is58mm);
    final pageFormat = ThermalPdfGenerator.getFormat(data, is58mm: is58mm);

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'chek_${data.checkId}',
      format: pageFormat,
      dynamicLayout: false,
    );
  }
}
