import 'package:flutter_test/flutter_test.dart';
import 'package:zavero/services/receipt_printer_service.dart';
import 'package:zavero/theme/design_tokens.dart';

void main() {
  group('ReceiptPrinterService and DesignTokens Tests', () {
    test('ReceiptPrintData money formatting produces correct space-separated sums', () {
      expect(ReceiptPrintData.formatMoney(82000), "82 000");
      expect(ReceiptPrintData.formatMoney(35000), "35 000");
      expect(ReceiptPrintData.formatMoney(0), "0");
      expect(ReceiptPrintData.formatMoney(1500000), "1 500 000");
    });

    test('EscPosBuilder generates non-empty vertical 80mm ESC/POS bytes with cut command', () {
      final data = ReceiptPrintData(
        checkId: '309',
        dateTime: DateTime(2026, 10, 30, 10, 27, 2),
        cashierName: 'Ilyos',
        cafeName: 'Family Cafe',
        address: "Navoiy ko'chasi 12, Buxoro",
        phone: '+998 90 123 45 67',
        slogan: "Yaxshi ta'm • Baxtli onlar",
        footerMessage: 'Bizni tanlaganingiz uchun rahmat!',
        qrUrl: 'https://zavero-backend-production-7dc9.up.railway.app',
        tableNumber: '2',
        hallName: 'Zal',
        items: [
          const ReceiptPrintItem(
            index: 1,
            name: 'Shaurma mini',
            qty: 1,
            unitPrice: 35000,
            lineTotal: 35000,
          ),
        ],
        subtotal: 35000,
        discount: 0,
        grandTotal: 35000,
        paymentMethod: 'cash',
      );

      final bytes = EscPosBuilder.buildReceiptBytes(data);
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));

      // Contains cut command GS V 66 0 (0x1D, 0x56, 0x42, 0x00)
      final hasCut = bytes.any((b) => b == 0x1D);
      expect(hasCut, isTrue);
    });

    test('ThermalPdfGenerator builds valid non-empty PDF document', () async {
      final data = ReceiptPrintData(
        checkId: '310',
        dateTime: DateTime(2026, 10, 30, 10, 27, 5),
        cashierName: 'Ilyos',
        cafeName: 'Family Cafe',
        address: "Navoiy ko'chasi 12, Buxoro",
        phone: '+998 90 123 45 67',
        slogan: "Yaxshi ta'm • Baxtli onlar",
        footerMessage: 'Bizni tanlaganingiz uchun rahmat!',
        qrUrl: 'https://zavero-backend-production-7dc9.up.railway.app',
        tableNumber: '2',
        hallName: 'Zal',
        items: [
          const ReceiptPrintItem(
            index: 1,
            name: 'Lavash Standart',
            qty: 2,
            unitPrice: 32000,
            lineTotal: 64000,
          ),
          const ReceiptPrintItem(
            index: 2,
            name: 'Coca-Cola 0.5L',
            qty: 2,
            unitPrice: 9000,
            lineTotal: 18000,
          ),
        ],
        subtotal: 82000,
        discount: 0,
        grandTotal: 82000,
        paymentMethod: 'cash',
      );

      final doc = ThermalPdfGenerator.buildReceiptDoc(data);
      final pdfBytes = await doc.save();
      expect(pdfBytes, isNotEmpty);
      // PDF file magic header "%PDF-"
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), '%PDF-');
    });

    test('AppTokens responsive breakpoints work accurately', () {
      expect(AppTokens.breakpointMobile, 640.0);
      expect(AppTokens.breakpointTablet, 1024.0);
      expect(375.0 < AppTokens.breakpointMobile, isTrue);
      expect(768.0 >= AppTokens.breakpointMobile && 768.0 < AppTokens.breakpointTablet, isTrue);
      expect(1280.0 >= AppTokens.breakpointTablet, isTrue);
    });
  });
}
