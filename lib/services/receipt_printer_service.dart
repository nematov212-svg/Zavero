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
      if (rune < 0x80) {
        res.add(rune);
      } else if (rune >= 0x0410 && rune <= 0x042F) {
        res.add(0x80 + (rune - 0x0410)); // А-Я
      } else if (rune >= 0x0430 && rune <= 0x043F) {
        res.add(0xA0 + (rune - 0x0430)); // а-п
      } else if (rune >= 0x0440 && rune <= 0x044F) {
        res.add(0xE0 + (rune - 0x0440)); // р-я
      } else if (rune == 0x0401) {
        res.add(0xF0); // Ё
      } else if (rune == 0x0451) {
        res.add(0xF1); // ё
      } else if (rune == 0x040E) {
        res.add(0x93); // Ў -> У
      } else if (rune == 0x045E) {
        res.add(0xE3); // ў -> у
      } else if (rune == 0x049A) {
        res.add(0x8A); // Қ -> К
      } else if (rune == 0x049B) {
        res.add(0xAA); // қ -> к
      } else if (rune == 0x0492) {
        res.add(0x83); // Ғ -> Г
      } else if (rune == 0x0493) {
        res.add(0xA3); // ғ -> г
      } else if (rune == 0x04B2) {
        res.add(0x95); // Ҳ -> Х
      } else if (rune == 0x04B3) {
        res.add(0xE5); // ҳ -> х
      } else if (rune == 0x02BB || rune == 0x02BC || rune == 0x2018 || rune == 0x2019) {
        res.add(0x27); // '
      } else if (rune == 0x2013 || rune == 0x2014) {
        res.add(0x2D); // -
      } else if (rune == 0x201C || rune == 0x201D) {
        res.add(0x22); // "
      } else {
        res.add(0x3F); // ?
      }
    }
    return res;
  }

  void alignLeft() => _bytes.addAll([0x1B, 0x61, 0x00]);
  void alignCenter() => _bytes.addAll([0x1B, 0x61, 0x01]);
  void alignRight() => _bytes.addAll([0x1B, 0x61, 0x02]);

  void boldOn() => _bytes.addAll([0x1B, 0x45, 0x01]);
  void boldOff() => _bytes.addAll([0x1B, 0x45, 0x00]);

  void doubleSizeOn() => _bytes.addAll([0x1D, 0x21, 0x11]);
  void normalSize() => _bytes.addAll([0x1D, 0x21, 0x00]);

  void printLine([String text = '']) {
    _bytes.addAll(encodeText(text));
    _bytes.add(0x0A);
  }

  void divider([String char = '-']) {
    _bytes.addAll(encodeText(char * width));
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

  /// Generates the complete 80mm/58mm ESC/POS receipt strictly matching Reference Image 2.
  static List<int> buildReceiptBytes(ReceiptPrintData data, {int width = 48}) {
    final builder = EscPosBuilder(width: width);

    // ── A. HEADER ────────────────────────────────────────────────
    builder.alignCenter();
    // Stylized chef toque emblem in text
    builder.printLine('   (  )   (  )   (  )   ');
    builder.printLine('  (                  )  ');
    builder.printLine('  |==================|  ');
    builder.printLine('       \\  /  ||  \\  /   ');

    builder.boldOn();
    builder.doubleSizeOn();
    builder.printLine(data.cafeName.toUpperCase());
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

    builder.alignLeft();
    builder.twoColumnRow(data.cafeName, 'Sana: $dateStr');
    builder.twoColumnRow(data.address, 'Vaqt: $timeStr');
    builder.twoColumnRow(data.phone, 'Chek No: ${data.checkId}');

    if (data.tableNumber != null && data.tableNumber!.isNotEmpty) {
      final tblStr = '${data.hallName ?? 'Zal'} - ${data.tableNumber}-stol';
      builder.twoColumnRow(tblStr, 'Kassir: ${data.cashierName}');
    } else {
      builder.twoColumnRow('Kassa', 'Kassir: ${data.cashierName}');
    }
    builder.divider();

    // ── C. PRODUCT TABLE ─────────────────────────────────────────
    builder.boldOn();
    if (width >= 48) {
      // 80mm: No (3), Nomi (18), Miqdori (7), Narx (9), Summa (11) = 48
      builder.printLine(
        '${'No'.padRight(3)}${'Nomi'.padRight(18)}${'Miqdori'.padRight(8)}${'Narx'.padLeft(8)} ${'Summa'.padLeft(10)}',
      );
    } else {
      // 58mm: Nomi / Miqdori / Summa
      builder.printLine(
        '${'Nomi'.padRight(14)}${'Miqdori'.padLeft(7)} ${'Summa'.padLeft(10)}',
      );
    }
    builder.boldOff();
    builder.divider();

    for (final item in data.items) {
      final name = item.name;
      final qtyStr = '${item.qty} ta';
      final priceStr = ReceiptPrintData.formatMoney(item.unitPrice);
      final totalStr = ReceiptPrintData.formatMoney(item.lineTotal);

      if (width >= 48) {
        if (name.length <= 17) {
          final noStr = '${item.index}.'.padRight(3);
          final nStr = name.padRight(18);
          final qStr = qtyStr.padRight(8);
          final pStr = priceStr.padLeft(8);
          final tStr = totalStr.padLeft(10);
          builder.printLine('$noStr$nStr$qStr$pStr $tStr');
        } else {
          // Wrapped 2-line layout: prevents any clipping or overlapping
          builder.boldOn();
          builder.printLine('${item.index}. $name');
          builder.boldOff();
          builder.twoColumnRow('    $qtyStr x $priceStr', '$totalStr UZS');
        }
      } else {
        if (name.length <= 13) {
          builder.printLine(
            '${name.padRight(14)}${qtyStr.padLeft(7)} ${totalStr.padLeft(10)}',
          );
        } else {
          builder.printLine('${item.index}. $name');
          builder.twoColumnRow('   $qtyStr x $priceStr', '$totalStr UZS');
        }
      }
    }
    builder.divider();

    // ── D. TOTALS ────────────────────────────────────────────────
    builder.twoColumnRow(
      'Jami:',
      '${ReceiptPrintData.formatMoney(data.subtotal)} so\'m',
    );
    if (data.discount > 0) {
      builder.twoColumnRow(
        'Chegirma:',
        '-${ReceiptPrintData.formatMoney(data.discount)} so\'m',
      );
    }

    builder.doubleDivider();
    builder.boldOn();
    builder.doubleSizeOn();
    builder.alignLeft();
    builder.printLine('TO\'LOV: ${ReceiptPrintData.formatMoney(data.grandTotal)} UZS');
    builder.normalSize();
    builder.boldOff();
    builder.doubleDivider();

    // ── E. QR CODE ───────────────────────────────────────────────
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
    builder.printLine('( <3 )');
    builder.boldOn();
    builder.printLine(data.cafeName.toUpperCase());
    builder.boldOff();

    // Clean cut without wasted paper
    builder.feedAndCut(feedLines: 3);

    return builder.toBytes();
  }
}

/// PDF Receipt Generator guaranteeing exact 80mm thermal roll format.
/// Eliminates the horizontal / compressed A4 bug permanently.
class ThermalPdfGenerator {
  ThermalPdfGenerator._();

  static pw.Document buildReceiptDoc(ReceiptPrintData data, {bool is58mm = false}) {
    final double widthPt = (is58mm ? 58.0 : 80.0) * PdfPageFormat.mm;
    const double marginVerticalPt = 1.5 * PdfPageFormat.mm;
    const double marginHorizontalPt = 2.0 * PdfPageFormat.mm;

    // 1-rasmdagi ko'rinishga 100% mos to'liq balandlik (hech qanday qism kesilib qolmasligi uchun)
    final double baseHeight = is58mm ? 480.0 : 510.0;
    final double dynamicItemsHeight = data.items.length * (is58mm ? 20.0 : 18.0);
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

    // 1-rasmdagi ChefHatPainter bilan 1:1 aynan bir xil oshpaz qalpog'i + vilka SVG emblemasi
    const chefHatForkSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 80" fill="none" stroke="black" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
  <rect x="12" y="58" width="76" height="15" rx="3.5" stroke-width="3"/>
  <line x1="20" y1="58" x2="20" y2="35" stroke-width="3"/>
  <line x1="80" y1="58" x2="80" y2="35" stroke-width="3"/>
  <path d="M 16 35 C 16 14, 84 14, 84 35 Z" stroke-width="3"/>
  <line x1="16" y1="35" x2="84" y2="35" stroke-width="3"/>
  <line x1="50" y1="23" x2="50" y2="52" stroke-width="2.6"/>
  <line x1="43" y1="10" x2="43" y2="24" stroke-width="2.4"/>
  <line x1="50" y1="10" x2="50" y2="24" stroke-width="2.4"/>
  <line x1="57" y1="10" x2="57" y2="24" stroke-width="2.4"/>
  <line x1="43" y1="24" x2="57" y2="24" stroke-width="2.4"/>
</svg>''';

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // ── 1. HEADER: Emblem + Cafe Name + Slogan ──────
              pw.Center(child: pw.SvgImage(svg: chefHatForkSvg, width: 36, height: 28)),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  data.cafeName.toUpperCase(),
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: is58mm ? 12.0 : 14.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                pw.Container(width: 14, height: 0.7, color: PdfColors.black),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                  child: pw.Text(
                    data.slogan.replaceAll('•', '-'),
                    style: pw.TextStyle(font: fontOblique, fontSize: 6.5, fontStyle: pw.FontStyle.italic),
                  ),
                ),
                pw.Container(width: 14, height: 0.7, color: PdfColors.black),
              ]),
              pw.SizedBox(height: 3),
              pw.Container(height: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 3),

              // ── 2. INFO BLOK (2 Columns) ───────────────────
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  // Left side
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(data.cafeName, style: pw.TextStyle(font: fontBold, fontSize: 7.2, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 1.8),
                      pw.Text(data.address, style: pw.TextStyle(font: font, fontSize: 6.8)),
                      pw.SizedBox(height: 1.8),
                      pw.Text(data.phone, style: pw.TextStyle(font: font, fontSize: 6.8)),
                    ]),
                  ),
                  pw.Container(width: 0.6, color: PdfColors.grey500, margin: const pw.EdgeInsets.symmetric(horizontal: 4)),
                  // Right side
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('Sana: $dateStr', style: pw.TextStyle(font: font, fontSize: 6.8)),
                      pw.SizedBox(height: 1.8),
                      pw.Text('Vaqt: $timeStr', style: pw.TextStyle(font: font, fontSize: 6.8)),
                      pw.SizedBox(height: 1.8),
                      pw.Text('Chek No: ${data.checkId}', style: pw.TextStyle(font: fontBold, fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 1.8),
                      pw.Text('Kassir: ${data.cashierName}', style: pw.TextStyle(font: fontBold, fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ),
                ]),
              ),
              pw.SizedBox(height: 3),
              pw.Container(height: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 2.5),

              // ── 3. PRODUCT TABLE HEADER ────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.black, width: 0.9),
                    bottom: pw.BorderSide(color: PdfColors.black, width: 0.9),
                  ),
                ),
                child: pw.Row(children: [
                  pw.SizedBox(width: is58mm ? 12 : 16, child: pw.Text('No', style: pw.TextStyle(font: fontBold, fontSize: 7.0, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(child: pw.Text('Nomi', style: pw.TextStyle(font: fontBold, fontSize: 7.0, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(width: is58mm ? 26 : 32, child: pw.Text('Miqdori', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold, fontSize: 7.0, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(width: is58mm ? 32 : 40, child: pw.Text('Narx', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.0, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(width: is58mm ? 36 : 44, child: pw.Text('Summa', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.0, fontWeight: pw.FontWeight.bold))),
                ]),
              ),
              pw.SizedBox(height: 2),

              // ── 4. PRODUCTS LIST ───────────────────────────
              ...List.generate(data.items.length, (index) {
                final item = data.items[index];
                return pw.Column(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
                    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.SizedBox(width: is58mm ? 12 : 16, child: pw.Text('${item.index}', style: pw.TextStyle(font: font, fontSize: 7.0))),
                      pw.Expanded(child: pw.Text(item.name, style: pw.TextStyle(font: fontBold, fontSize: 7.2, fontWeight: pw.FontWeight.bold))),
                      pw.SizedBox(width: is58mm ? 26 : 32, child: pw.Text('${item.qty} ta', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 7.0))),
                      pw.SizedBox(width: is58mm ? 32 : 40, child: pw.Text(ReceiptPrintData.formatMoney(item.unitPrice), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: font, fontSize: 7.0))),
                      pw.SizedBox(width: is58mm ? 36 : 44, child: pw.Text(ReceiptPrintData.formatMoney(item.lineTotal), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.2, fontWeight: pw.FontWeight.bold))),
                    ]),
                  ),
                  if (index < data.items.length - 1)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: List.generate(is58mm ? 20 : 28, (_) => pw.Container(width: 2.5, height: 0.4, color: PdfColors.grey400)),
                      ),
                    ),
                ]);
              }),
              pw.SizedBox(height: 2),
              pw.Container(height: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 3),

              // ── 5. TOTALS ──────────────────────────────────
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                child: pw.Column(children: [
                  if (data.discount > 0) ...[
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Jami:', style: pw.TextStyle(font: fontBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text("${ReceiptPrintData.formatMoney(data.subtotal)} so'm", style: pw.TextStyle(font: fontBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.SizedBox(height: 1.5),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Chegirma:', style: pw.TextStyle(font: font, fontSize: 7.5)),
                      pw.Text("-${ReceiptPrintData.formatMoney(data.discount)} so'm", style: pw.TextStyle(font: font, fontSize: 7.5)),
                    ]),
                    pw.SizedBox(height: 2),
                  ],
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.black, width: 1.2),
                        bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
                      ),
                    ),
                    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text("TO'LOV:", style: pw.TextStyle(font: fontBold, fontSize: is58mm ? 11.0 : 13.0, fontWeight: pw.FontWeight.bold)),
                      pw.Text("${ReceiptPrintData.formatMoney(data.grandTotal)} so'm", style: pw.TextStyle(font: fontBold, fontSize: is58mm ? 11.5 : 13.5, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ),
                ]),
              ),
              pw.SizedBox(height: 18),

              // ── 6. QR CODE ─────────────────────────────────
              if (data.qrUrl.isNotEmpty) ...[
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(2),
                    color: PdfColors.white,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: data.qrUrl,
                      width: is58mm ? 40 : 46,
                      height: is58mm ? 40 : 46,
                      color: PdfColors.black,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'QR skaner qiling va\nZavero web saytiga o\'ting!',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: fontBold, fontSize: 6.2, color: PdfColors.black),
                  ),
                ),
                pw.SizedBox(height: 8),
              ],

              // ── 7. FOOTER ──────────────────────────────────
              pw.Container(height: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  data.footerMessage,
                  style: pw.TextStyle(font: fontOblique, fontSize: 8.0, fontStyle: pw.FontStyle.italic),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  data.cafeName.toUpperCase(),
                  style: pw.TextStyle(font: fontBold, fontSize: 7.2, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 12),
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
        // Do not crash, throw descriptive error so UI can notify user
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
      format: rollFormat, // CRITICAL: Tells the OS / print driver this is 80mm roll, NOT A4!
      dynamicLayout: false,
    );
  }
}
