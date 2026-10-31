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
        // Cyrillic & Special characters mapping to CP866
        switch (rune) {
          case 0x0410: res.add(0x80); break; // А
          case 0x0411: res.add(0x81); break; // Б
          case 0x0412: res.add(0x82); break; // В
          case 0x0413: res.add(0x83); break; // Г
          case 0x0414: res.add(0x84); break; // Д
          case 0x0415: res.add(0x85); break; // Е
          case 0x0416: res.add(0x86); break; // Ж
          case 0x0417: res.add(0x87); break; // З
          case 0x0418: res.add(0x88); break; // И
          case 0x0419: res.add(0x89); break; // Й
          case 0x041A: res.add(0x8A); break; // К
          case 0x041B: res.add(0x8B); break; // Л
          case 0x041C: res.add(0x8C); break; // М
          case 0x041D: res.add(0x8D); break; // Н
          case 0x041E: res.add(0x8E); break; // О
          case 0x041F: res.add(0x8F); break; // П
          case 0x0420: res.add(0x90); break; // Р
          case 0x0421: res.add(0x91); break; // С
          case 0x0422: res.add(0x92); break; // Т
          case 0x0423: res.add(0x93); break; // У
          case 0x0424: res.add(0x94); break; // Ф
          case 0x0425: res.add(0x95); break; // Х
          case 0x0426: res.add(0x96); break; // Ц
          case 0x0427: res.add(0x97); break; // Ч
          case 0x0428: res.add(0x98); break; // Ш
          case 0x0429: res.add(0x99); break; // Щ
          case 0x042A: res.add(0x9A); break; // Ъ
          case 0x042B: res.add(0x9B); break; // Ы
          case 0x042C: res.add(0x9C); break; // Ь
          case 0x042D: res.add(0x9D); break; // Э
          case 0x042E: res.add(0x9E); break; // Ю
          case 0x042F: res.add(0x9F); break; // Я
          case 0x0430: res.add(0xA0); break; // а
          case 0x0431: res.add(0xA1); break; // б
          case 0x0432: res.add(0xA2); break; // в
          case 0x0433: res.add(0xA3); break; // г
          case 0x0434: res.add(0xA4); break; // д
          case 0x0435: res.add(0xA5); break; // е
          case 0x0436: res.add(0xA6); break; // ж
          case 0x0437: res.add(0xA7); break; // з
          case 0x0438: res.add(0xA8); break; // и
          case 0x0439: res.add(0xA9); break; // й
          case 0x043A: res.add(0xAA); break; // к
          case 0x043B: res.add(0xAB); break; // л
          case 0x043C: res.add(0xAC); break; // м
          case 0x043D: res.add(0xAD); break; // н
          case 0x043E: res.add(0xAE); break; // о
          case 0x043F: res.add(0xAF); break; // п
          case 0x0440: res.add(0xE0); break; // р
          case 0x0441: res.add(0xE1); break; // с
          case 0x0442: res.add(0xE2); break; // т
          case 0x0443: res.add(0xE3); break; // у
          case 0x0444: res.add(0xE4); break; // ф
          case 0x0445: res.add(0xE5); break; // х
          case 0x0446: res.add(0xE6); break; // ц
          case 0x0447: res.add(0xE7); break; // ч
          case 0x0448: res.add(0xE8); break; // ш
          case 0x0449: res.add(0xE9); break; // щ
          case 0x044A: res.add(0xEA); break; // ъ
          case 0x044B: res.add(0xEB); break; // ы
          case 0x044C: res.add(0xEC); break; // ь
          case 0x044D: res.add(0xED); break; // э
          case 0x044E: res.add(0xEE); break; // ю
          case 0x044F: res.add(0xEF); break; // я
          case 0x2022: res.add(0x2A); break; // • -> *
          case 0x2014: res.add(0x2D); break; // — -> -
          case 0x2116: res.add(0x23); break; // № -> #
          default: res.add(0x3F); // ? for unknown
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

  void doubleDivider() {
    _bytes.addAll(encodeText('=' * width));
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
    // 1. Model: Model 2
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
    // 2. Module size
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size]);
    // 3. Error correction level M
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);
    // 4. Store symbol data
    _bytes.addAll([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30, ...data]);
    // 5. Print symbol
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
  }

  void feedAndCut({int feedLines = 3}) {
    _bytes.addAll([0x1B, 0x32]); // Default line spacing
    _bytes.addAll([0x1B, 0x64, feedLines]);
    _bytes.addAll([0x1D, 0x56, 0x01]); // Partial cut
  }

  List<int> toBytes() => List<int>.unmodifiable(_bytes);

  /// Generates the complete 80mm/58mm ESC/POS receipt strictly matching Image 5 (FAMILY CAFE).
  static List<int> buildReceiptBytes(ReceiptPrintData data, {int width = 48}) {
    final builder = EscPosBuilder(width: width);

    // ── A. HEADER (Coffee cup & beans text emblem) ────────────────
    builder.alignCenter();
    builder.printLine('---- (o)  ( U )  (o) ----');

    builder.boldOn();
    builder.doubleSizeOn();
    builder.printLine(data.cafeName.toUpperCase());
    builder.normalSize();
    builder.boldOff();

    if (data.slogan.isNotEmpty) {
      builder.printLine('--- ${data.slogan} ---');
    }
    builder.divider();

    // ── B. BUSINESS INFORMATION (2 Columns - Image 5) ─────────────
    final dateStr =
        '${data.dateTime.day.toString().padLeft(2, '0')}.${data.dateTime.month.toString().padLeft(2, '0')}.${data.dateTime.year}';
    final timeStr =
        '${data.dateTime.hour.toString().padLeft(2, '0')}:${data.dateTime.minute.toString().padLeft(2, '0')}';

    builder.alignLeft();
    builder.twoColumnRow(data.cafeName, dateStr);
    builder.twoColumnRow(data.address, timeStr);
    builder.twoColumnRow(data.phone, 'Chek No: ${data.checkId}');
    builder.twoColumnRow('', 'Kassir: ${data.cashierName}');
    builder.divider();

    // ── C. PRODUCT TABLE (4 Columns: No, Nomi, Miqdori, Narx - Image 5) ─
    builder.boldOn();
    if (width >= 48) {
      // 80mm: No (3), Nomi (22), Miqdori (10), Narx (13) = 48
      builder.printLine(
        '${'No'.padRight(3)}${'Nomi'.padRight(22)}${'Miqdori'.padRight(10)}${'Narx'.padLeft(13)}',
      );
    } else {
      // 58mm: No (3), Nomi (12), Miqdori (7), Narx (10) = 32
      builder.printLine(
        '${'No'.padRight(3)}${'Nomi'.padRight(12)}${'Miqdori'.padRight(7)}${'Narx'.padLeft(10)}',
      );
    }
    builder.boldOff();
    builder.divider();

    for (final item in data.items) {
      final name = item.name;
      final qtyStr = '${item.qty} dona';
      final priceStr = '${ReceiptPrintData.formatMoney(item.unitPrice)} UZS';

      if (width >= 48) {
        if (name.length <= 21) {
          final noStr = '${item.index}'.padRight(3);
          final nStr = name.padRight(22);
          final qStr = qtyStr.padRight(10);
          final pStr = priceStr.padLeft(13);
          builder.printLine('$noStr$nStr$qStr$pStr');
        } else {
          builder.boldOn();
          builder.printLine('${item.index}. $name');
          builder.boldOff();
          builder.twoColumnRow('   $qtyStr', priceStr);
        }
      } else {
        if (name.length <= 11) {
          final noStr = '${item.index}'.padRight(3);
          final nStr = name.padRight(12);
          final qStr = qtyStr.padRight(7);
          final pStr = priceStr.padLeft(10);
          builder.printLine('$noStr$nStr$qStr$pStr');
        } else {
          builder.printLine('${item.index}. $name');
          builder.twoColumnRow('   $qtyStr', priceStr);
        }
      }
    }
    builder.divider();

    // ── D. PAYMENT BOX (TO'LOV: | <summa> UZS - Image 5) ─────────
    builder.doubleDivider();
    builder.boldOn();
    builder.doubleSizeOn();
    builder.twoColumnRow(
      "TO'LOV:",
      '${ReceiptPrintData.formatMoney(data.grandTotal)} UZS',
    );
    builder.normalSize();
    builder.boldOff();
    builder.doubleDivider();

    // ── E. QR CODE (Centered + phone prompt - Image 5) ───────────
    if (data.qrUrl.isNotEmpty) {
      builder.alignCenter();
      builder.printLine();
      builder.qrCode(data.qrUrl, size: width >= 48 ? 6 : 4);
      builder.printLine();
      builder.boldOn();
      builder.printLine('QR skaner qiling va');
      builder.printLine('Zavero web saytiga o\'ting!');
      builder.boldOff();
      builder.printLine('----------- (o) -----------');
    }

    // ── F. FOOTER (Image 5) ──────────────────────────────────────
    builder.alignCenter();
    builder.printLine(data.footerMessage);
    builder.boldOn();
    builder.printLine('--- ${data.cafeName.toUpperCase()} ---');
    builder.boldOff();

    // Clean cut
    builder.feedAndCut(feedLines: 3);

    return builder.toBytes();
  }
}

/// PDF Receipt Generator guaranteeing exact 80mm thermal roll format.
/// Matches Image 5 (FAMILY CAFE) with 100% precision.
class ThermalPdfGenerator {
  ThermalPdfGenerator._();

  static pw.Document buildReceiptDoc(ReceiptPrintData data, {bool is58mm = false}) {
    final double widthPt = (is58mm ? 58.0 : 80.0) * PdfPageFormat.mm;
    const double marginVerticalPt = 1.5 * PdfPageFormat.mm;
    const double marginHorizontalPt = 2.5 * PdfPageFormat.mm;

    final double baseHeight = is58mm ? 470.0 : 490.0;
    final double dynamicItemsHeight = data.items.length * (is58mm ? 16.0 : 15.0);
    final double totalHeight = baseHeight + dynamicItemsHeight;

    final format = PdfPageFormat(
      widthPt,
      totalHeight,
      marginTop: marginVerticalPt,
      marginBottom: marginVerticalPt,
      marginLeft: marginHorizontalPt,
      marginRight: marginHorizontalPt,
    );

    final doc = pw.Document();
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontOblique = pw.Font.helveticaOblique();

    final dateStr =
        '${data.dateTime.day.toString().padLeft(2, '0')}.${data.dateTime.month.toString().padLeft(2, '0')}.${data.dateTime.year}';
    final timeStr =
        '${data.dateTime.hour.toString().padLeft(2, '0')}:${data.dateTime.minute.toString().padLeft(2, '0')}';

    // Image 5: Coffee Cup with Steam, Saucer, Arch & 2 Coffee Beans SVG
    const coffeeCupEmblemSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 52" fill="none" stroke="black" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <line x1="4" y1="28" x2="46" y2="28" stroke-width="1.8"/>
  <g transform="translate(56, 26) rotate(-25)">
    <ellipse cx="0" cy="0" rx="7" ry="4.5" fill="black"/>
    <path d="M -5 0 C -2 -2.5, 2 2.5, 5 0" stroke="white" stroke-width="1.2" fill="none"/>
  </g>
  <path d="M 66 38 C 68 8, 92 8, 94 38" stroke-width="1.8" fill="none"/>
  <ellipse cx="80" cy="38" rx="14" ry="2.5" stroke="black" stroke-width="1.6" fill="none"/>
  <path d="M 72 25 L 88 25 C 88 35, 72 35, 72 25 Z" fill="black"/>
  <path d="M 87 26 C 92 26, 92 33, 86 33" stroke="black" stroke-width="1.6" fill="none"/>
  <path d="M 80 23 C 78 18, 82 14, 80 9" stroke="black" stroke-width="1.4" fill="none"/>
  <path d="M 76 23 C 74 19, 78 16, 76 11" stroke="black" stroke-width="1.2" fill="none"/>
  <path d="M 84 23 C 86 19, 82 16, 84 11" stroke="black" stroke-width="1.2" fill="none"/>
  <g transform="translate(104, 26) rotate(25)">
    <ellipse cx="0" cy="0" rx="7" ry="4.5" fill="black"/>
    <path d="M -5 0 C -2 -2.5, 2 2.5, 5 0" stroke="white" stroke-width="1.2" fill="none"/>
  </g>
  <line x1="114" y1="28" x2="156" y2="28" stroke-width="1.8"/>
</svg>''';

    // Image 5: Coffee bean divider SVG
    const coffeeBeanDividerSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 16" fill="none" stroke="black" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round">
  <line x1="4" y1="8" x2="70" y2="8"/>
  <g transform="translate(80, 8) rotate(25)">
    <ellipse cx="0" cy="0" rx="6.5" ry="4" fill="black"/>
    <path d="M -4.5 0 C -2 -2, 2 2, 4.5 0" stroke="white" stroke-width="1.0" fill="none"/>
  </g>
  <line x1="90" y1="8" x2="156" y2="8"/>
</svg>''';

    // Corner brackets SVG around QR code
    const cornerBracketsSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 60" fill="none" stroke="black" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
  <path d="M 4 12 L 4 4 L 12 4"/>
  <path d="M 48 4 L 56 4 L 56 12"/>
  <path d="M 4 48 L 4 56 L 12 56"/>
  <path d="M 48 56 L 56 56 L 56 48"/>
</svg>''';

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // ── 1. HEADER: Coffee Cup Emblem + FAMILY CAFE + Slogan (Image 5) ──
              pw.Center(child: pw.SvgImage(svg: coffeeCupEmblemSvg, width: is58mm ? 100 : 130, height: is58mm ? 32 : 40)),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  data.cafeName.toUpperCase(),
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: is58mm ? 13.0 : 16.0,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                pw.Container(width: 16, height: 0.8, color: PdfColors.black),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text("Yaxshi ta'm ", style: pw.TextStyle(font: font, fontSize: 7.2, fontWeight: pw.FontWeight.bold)),
                      pw.Container(width: 2.5, height: 2.5, decoration: const pw.BoxDecoration(color: PdfColors.black, shape: pw.BoxShape.circle)),
                      pw.Text(" Baxtli onlar", style: pw.TextStyle(font: font, fontSize: 7.2, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Container(width: 16, height: 0.8, color: PdfColors.black),
              ]),
              pw.SizedBox(height: 4),
              pw.Container(height: 1.0, color: PdfColors.black),
              pw.SizedBox(height: 3),

              // ── 2. INFO BLOK (2 Columns divided by vertical line - Image 5) ──
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  // Left side
                  pw.Expanded(
                    flex: 11,
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(data.cafeName, style: pw.TextStyle(font: fontBold, fontSize: 7.6, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2.0),
                      pw.Text(data.address, style: pw.TextStyle(font: font, fontSize: 6.8)),
                      pw.SizedBox(height: 2.0),
                      pw.Text(data.phone, style: pw.TextStyle(font: font, fontSize: 6.8)),
                    ]),
                  ),
                  pw.Container(width: 0.8, height: 32, color: PdfColors.black, margin: const pw.EdgeInsets.symmetric(horizontal: 4)),
                  // Right side
                  pw.Expanded(
                    flex: 9,
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(dateStr, style: pw.TextStyle(font: font, fontSize: 6.8)),
                      pw.SizedBox(height: 2.0),
                      pw.Text(timeStr, style: pw.TextStyle(font: font, fontSize: 6.8)),
                      pw.SizedBox(height: 2.0),
                      pw.Text('Chek No: ${data.checkId}', style: pw.TextStyle(font: fontBold, fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2.0),
                      pw.Text('Kassir: ${data.cashierName}', style: pw.TextStyle(font: fontBold, fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ),
                ]),
              ),
              pw.SizedBox(height: 3),
              pw.Container(height: 1.0, color: PdfColors.black),
              pw.SizedBox(height: 2.5),

              // ── 3. PRODUCT TABLE HEADER (№ | Nomi | Miqdori | Narx - NO Summa - Image 5) ──
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
                child: pw.Row(children: [
                  pw.SizedBox(width: is58mm ? 14 : 18, child: pw.Text('No', style: pw.TextStyle(font: fontBold, fontSize: 7.2, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(child: pw.Text('Nomi', style: pw.TextStyle(font: fontBold, fontSize: 7.2, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(width: is58mm ? 36 : 46, child: pw.Text('Miqdori', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold, fontSize: 7.2, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(width: is58mm ? 46 : 56, child: pw.Text('Narx', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.2, fontWeight: pw.FontWeight.bold))),
                ]),
              ),
              pw.Container(height: 0.6, color: PdfColors.black),
              pw.SizedBox(height: 2),

              // ── 4. PRODUCTS LIST (Image 5) ─────────────────
              ...List.generate(data.items.length, (index) {
                final item = data.items[index];
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.8),
                  child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                    pw.SizedBox(width: is58mm ? 14 : 18, child: pw.Text('${item.index}', style: pw.TextStyle(font: font, fontSize: 7.2))),
                    pw.Expanded(child: pw.Text(item.name, style: pw.TextStyle(font: fontBold, fontSize: 7.4, fontWeight: pw.FontWeight.bold))),
                    pw.SizedBox(width: is58mm ? 36 : 46, child: pw.Text('${item.qty} dona', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 7.2))),
                    pw.SizedBox(width: is58mm ? 46 : 56, child: pw.Text("${ReceiptPrintData.formatMoney(item.unitPrice)} UZS", textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.4, fontWeight: pw.FontWeight.bold))),
                  ]),
                );
              }),
              pw.SizedBox(height: 2),
              pw.Container(height: 1.0, color: PdfColors.black),
              pw.SizedBox(height: 4),

              // ── 5. PAYMENT BOX (Rounded border box: TO'LOV: | <summa> UZS - Image 5) ──
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.black, width: 1.4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("TO'LOV:", style: pw.TextStyle(font: fontBold, fontSize: is58mm ? 10.5 : 12.5, fontWeight: pw.FontWeight.bold)),
                    pw.Container(width: 1.0, height: 16, color: PdfColors.black),
                    pw.Text("${ReceiptPrintData.formatMoney(data.grandTotal)} UZS", style: pw.TextStyle(font: fontBold, fontSize: is58mm ? 11.5 : 13.5, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // ── 6. QR CODE WITH CORNER BRACKETS & PHONE (Image 5) ──
              if (data.qrUrl.isNotEmpty) ...[
                pw.Center(
                  child: pw.Stack(
                    alignment: pw.Alignment.center,
                    children: [
                      pw.SvgImage(svg: cornerBracketsSvg, width: is58mm ? 52 : 62, height: is58mm ? 52 : 62),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: data.qrUrl,
                        width: is58mm ? 40 : 48,
                        height: is58mm ? 40 : 48,
                        color: PdfColors.black,
                      ),
                    ],
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
                pw.SizedBox(height: 10),
              ],

              // ── 7. FOOTER: COFFEE BEAN DIVIDER + THANKS NOTE + FAMILY CAFE (Image 5) ──
              pw.Center(child: pw.SvgImage(svg: coffeeBeanDividerSvg, width: is58mm ? 100 : 130, height: 12)),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  data.footerMessage,
                  style: pw.TextStyle(font: fontOblique, fontSize: 8.2, fontStyle: pw.FontStyle.italic),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                pw.Container(width: 18, height: 0.8, color: PdfColors.black),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                  child: pw.Text(
                    data.cafeName.toUpperCase(),
                    style: pw.TextStyle(font: fontBold, fontSize: 8.2, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8),
                  ),
                ),
                pw.Container(width: 18, height: 0.8, color: PdfColors.black),
              ]),
              pw.SizedBox(height: 10),
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
    const roll58 = PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm);
    final rollFormat = is58mm ? roll58 : PdfPageFormat.roll80;

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'chek_${data.checkId}',
      format: rollFormat,
      dynamicLayout: false,
    );
  }
}
