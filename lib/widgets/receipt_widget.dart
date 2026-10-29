import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../main.dart';

/// Chekdagi bitta mahsulot qatorini ifodalaydi.
class ReceiptItem {
  final int? index;
  final String name;
  final String quantity;
  final String price;
  final String? subtitle;

  const ReceiptItem({
    this.index,
    required this.name,
    required this.quantity,
    required this.price,
    this.subtitle,
  });
}

/// 80mm Termal printer cheki — Rasm 4 ga aynan 1:1 mos klassik chek dizayni.
class ReceiptWidget extends StatelessWidget {
  final String checkId;
  final String waiter;
  final String hallName;
  final String table;
  final String customer;
  final String dateTime;
  final String? dateOnly;
  final String? timeOnly;
  final List<ReceiptItem> items;
  final double? customTotal;
  final double? subtotal;
  final double? discount;
  final double? servicePercentage;
  final double? serviceFee;
  final String? paymentMethod;
  final double? paidAmount;
  final double? changeAmount;
  final String? customCafeName;
  final String? customAddress;
  final String? customPhone;
  final String? customSlogan;
  final String? customFooter;
  final String? customLogoUrl;
  final bool? customShowQr;
  final bool showThreeDotsMenu;
  final VoidCallback? onOpenSettings;

  const ReceiptWidget({
    super.key,
    required this.checkId,
    required this.waiter,
    this.hallName = 'Zal',
    this.table = '',
    this.customer = '1',
    required this.dateTime,
    this.dateOnly,
    this.timeOnly,
    required this.items,
    this.customTotal,
    this.subtotal,
    this.discount,
    this.servicePercentage,
    this.serviceFee,
    this.paymentMethod,
    this.paidAmount,
    this.changeAmount,
    this.customCafeName,
    this.customAddress,
    this.customPhone,
    this.customSlogan,
    this.customFooter,
    this.customLogoUrl,
    this.customShowQr,
    this.showThreeDotsMenu = false,
    this.onOpenSettings,
  });

  static int parsePrice(String raw) {
    final cleaned = raw.replaceAll(',', '').replaceAll(' ', '').trim();
    final digitsOnly = RegExp(r'\d+').stringMatch(cleaned) ?? '0';
    return int.tryParse(digitsOnly) ?? 0;
  }

  static int parseQuantity(String raw) {
    final digits = RegExp(r'\d+').stringMatch(raw) ?? '1';
    final val = int.tryParse(digits) ?? 1;
    return val <= 0 ? 1 : val;
  }

  int get calculatedSubtotal {
    if (subtotal != null && subtotal! > 0) return subtotal!.round();
    var sum = 0;
    for (final item in items) {
      sum += parsePrice(item.price) * parseQuantity(item.quantity);
    }
    return sum;
  }

  int get total {
    if (customTotal != null && customTotal! > 0) return customTotal!.round();
    final sub = calculatedSubtotal;
    final disc = (discount ?? 0).round();
    final res = sub - disc;
    return res > 0 ? res : sub;
  }

  static String money(int value) {
    final isNeg = value < 0;
    final digits = value.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final posFromEnd = digits.length - i;
      buf.write(digits[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(' ');
    }
    return (isNeg ? '-' : '') + buf.toString();
  }

  static String formatCheckNumber(String rawId) {
    final digits = RegExp(r'\d+').allMatches(rawId).map((m) => m.group(0)).join();
    if (digits.isEmpty) return '000001';
    if (digits.length >= 6) return digits.substring(digits.length - 6);
    return digits.padLeft(6, '0');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final cafeName = (customCafeName != null && customCafeName!.trim().isNotEmpty)
            ? customCafeName!.trim()
            : (appState.effectiveReceiptName.isNotEmpty ? appState.effectiveReceiptName : 'Family Cafe');

        final address = (customAddress != null && customAddress!.trim().isNotEmpty)
            ? customAddress!.trim()
            : (appState.restaurantAddress.trim().isNotEmpty
                ? appState.restaurantAddress.trim()
                : "Navoiy ko'chasi 12, Buxoro");

        final phone = (customPhone != null && customPhone!.trim().isNotEmpty)
            ? customPhone!.trim()
            : (appState.restaurantPhone.trim().isNotEmpty
                ? appState.restaurantPhone.trim()
                : '+998 90 123 45 67');

        final slogan = (customSlogan != null && customSlogan!.trim().isNotEmpty)
            ? customSlogan!.trim()
            : (appState.receiptSlogan.trim().isNotEmpty
                ? appState.receiptSlogan.trim()
                : "Yaxshi ta'm  \u2022  Baxtli onlar");

        final footerText = (customFooter != null && customFooter!.trim().isNotEmpty)
            ? customFooter!.trim()
            : (appState.receiptFooterNote.trim().isNotEmpty
                ? appState.receiptFooterNote.trim()
                : 'Bizni tanlaganingiz uchun rahmat!');

        final logoUrl = customLogoUrl ?? appState.appLogoUrl;
        final showQr = customShowQr ?? appState.receiptQrEnabled;

        String dateStr = dateOnly ?? '';
        String timeStr = timeOnly ?? '';
        if (dateStr.isEmpty || timeStr.isEmpty) {
          try {
            final parsed = DateTime.tryParse(dateTime);
            if (parsed != null) {
              dateStr =
                  '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
              timeStr =
                  '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
            } else {
              final now = DateTime.now();
              dateStr =
                  '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
              timeStr =
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            }
          } catch (_) {
            final now = DateTime.now();
            dateStr =
                '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
            timeStr =
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          }
        }

        final formattedCheckId = formatCheckNumber(checkId);
        final cashier = waiter.trim().isNotEmpty ? waiter.trim() : 'Admin';

        const cardWidth = 370.0;
        final finalSubtotal = calculatedSubtotal > 0 ? calculatedSubtotal : total;
        final finalDiscount = (discount ?? 0).round();
        final finalTotal = total;

        return ClipPath(
          clipper: const ZigzagClipper(zigzagHeight: 6, zigzagWidth: 12),
          child: Container(
            width: cardWidth,
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Settings bar ─────────────────────────────────
                if (showThreeDotsMenu)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(Icons.receipt_long, size: 15, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text("80mm Chek ko'rinishi",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600)),
                        ]),
                        if (onOpenSettings != null)
                          IconButton(
                            icon: const Icon(Icons.settings_outlined,
                                size: 17, color: Colors.black54),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: onOpenSettings,
                          ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── 1. HEADER: Logo + Cafe nomi + Slogan ─────
                      _buildHeader(logoUrl, cafeName, slogan),
                      const SizedBox(height: 8),
                      Container(height: 0.9, color: Colors.black87),
                      const SizedBox(height: 6),

                      // ── 2. INFO BLOK (2 ustun) ─────────────────
                      _buildInfoBlock(
                        cafeName: cafeName,
                        address: address,
                        phone: phone,
                        dateStr: dateStr,
                        timeStr: timeStr,
                        checkId: formattedCheckId,
                        cashier: cashier,
                      ),
                      const SizedBox(height: 6),
                      _buildDashedLine(),
                      const SizedBox(height: 6),

                      // ── 3. MAHSULOTLAR JADVAL ──────────────────
                      _buildItemsTable(items),
                      const SizedBox(height: 6),
                      _buildDashedLine(),
                      const SizedBox(height: 6),

                      // ── 4. JAMI / CHEGIRMA / TO'LOV ───────────
                      _buildTotals(
                        subtotalVal: finalSubtotal,
                        discountVal: finalDiscount,
                        grandTotalVal: finalTotal,
                      ),
                      const SizedBox(height: 8),

                      // ── 5. QR KOD ─────────────────────────────
                      if (showQr) _buildQrSection(),

                      // ── 6. FOOTER ─────────────────────────────
                      _buildFooter(footerText: footerText, cafeName: cafeName),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────
  //  HEADER: Chef hat + kafe nomi (kursiv) + slogan
  // ─────────────────────────────────────────────────────────
  Widget _buildHeader(String? logoUrl, String cafeName, String slogan) {
    return Column(
      children: [
        if (logoUrl != null && logoUrl.trim().isNotEmpty)
          _buildLogoImage(logoUrl.trim())
        else
          SizedBox(width: 58, height: 58, child: CustomPaint(painter: ChefHatPainter())),
        const SizedBox(height: 4),
        Text(
          cafeName.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: 0.8,
            height: 1.1,
          ),
        ),
        if (slogan.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 24, height: 0.8, color: Colors.black),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  slogan,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: 0.3),
                ),
              ),
              const SizedBox(width: 6),
              Container(width: 24, height: 0.8, color: Colors.black),
            ],
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  INFO BLOK: 2 ustun — chap (kafe+manzil+tel) | o'ng (sana+vaqt+chek+kassir)
  // ─────────────────────────────────────────────────────────
  Widget _buildInfoBlock({
    required String cafeName,
    required String address,
    required String phone,
    required String dateStr,
    required String timeStr,
    required String checkId,
    required String cashier,
  }) {
    const labelStyle =
        TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Colors.black87);
    const boldStyle =
        TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.black);

    Widget leftRow(IconData icon, String text, {bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 13.5, color: Colors.black54),
          const SizedBox(width: 5),
          Expanded(
              child: Text(text, style: bold ? boldStyle : labelStyle, maxLines: 2)),
        ]),
      );
    }

    Widget rightRow(IconData icon, String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 13.5, color: Colors.black54),
          const SizedBox(width: 5),
          Expanded(child: Text(text, style: labelStyle, maxLines: 1)),
        ]),
      );
    }

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              leftRow(Icons.storefront_outlined, cafeName, bold: true),
              leftRow(Icons.location_on_outlined, address),
              leftRow(Icons.phone_outlined, phone),
            ])),
        Container(
            width: 0.8,
            color: Colors.black12,
            margin: const EdgeInsets.symmetric(horizontal: 8)),
        Expanded(
            flex: 4,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              rightRow(Icons.calendar_today_outlined, dateStr),
              rightRow(Icons.access_time_outlined, timeStr),
              rightRow(Icons.receipt_outlined, 'Chek No: $checkId'),
              rightRow(Icons.person_outline, 'Kassir: $cashier'),
            ])),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  JADVAL: No | Nomi | Miqdori | Narx | Summa
  // ─────────────────────────────────────────────────────────
  Widget _buildItemsTable(List<ReceiptItem> itemsList) {
    const headerStyle =
        TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.black26, width: 0.8),
              bottom: BorderSide(color: Colors.black26, width: 0.8),
            ),
          ),
          child: const Row(children: [
            SizedBox(width: 22, child: Text('No', style: headerStyle)),
            Expanded(child: Text('Nomi', style: headerStyle)),
            SizedBox(
                width: 54,
                child: Text('Miqdori', textAlign: TextAlign.center, style: headerStyle)),
            SizedBox(
                width: 46,
                child: Text('Narx', textAlign: TextAlign.right, style: headerStyle)),
            SizedBox(
                width: 50,
                child: Text('Summa', textAlign: TextAlign.right, style: headerStyle)),
          ]),
        ),
        if (itemsList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text("Buyurtmada taomlar yo'q",
                style: TextStyle(
                    fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54)),
          )
        else
          ...itemsList.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final rowNum = item.index ?? (idx + 1);
            final qty = parseQuantity(item.quantity);
            final price = parsePrice(item.price);
            final summa = price * qty;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200, width: 0.5))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 22,
                    child: Text('$rowNum',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87))),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black)),
                  if (item.subtitle != null && item.subtitle!.trim().isNotEmpty)
                    Text(item.subtitle!.trim(),
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                            fontStyle: FontStyle.italic)),
                ])),
                SizedBox(
                    width: 54,
                    child: Text('$qty dona',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87))),
                SizedBox(
                    width: 46,
                    child: Text(money(price),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87))),
                SizedBox(
                    width: 50,
                    child: Text(money(summa),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.black))),
              ]),
            );
          }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  JAMI / CHEGIRMA / TO'LOV
  // ─────────────────────────────────────────────────────────
  Widget _buildTotals(
      {required int subtotalVal,
      required int discountVal,
      required int grandTotalVal}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(children: [
        if (discountVal > 0) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Jami:',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
            Text("${money(subtotalVal)} so'm",
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
          ]),
          const SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Chegirma:',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
            Text("-${money(discountVal)} so'm",
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
          ]),
          const SizedBox(height: 4),
        ],
        Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.black, width: 1.2),
              bottom: BorderSide(color: Colors.black, width: 1.2),
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("TO'LOV:",
                style: TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.w900, color: Colors.black)),
            Text("${money(grandTotalVal)} so'm",
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black)),
          ]),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  QR KOD
  // ─────────────────────────────────────────────────────────
  Widget _buildQrSection() {
    return Column(children: [
      Center(
        child: Container(
          padding: const EdgeInsets.all(4),
          color: Colors.white,
          child: QrImageView(
            data: 'https://zavero-backend-production-7dc9.up.railway.app',
            version: QrVersions.auto,
            size: 72.0,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
            dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square, color: Colors.black),
          ),
        ),
      ),
      const SizedBox(height: 3),
      const Text(
        'QR kodni skaner qiling',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.black87),
      ),
      const SizedBox(height: 6),
    ]);
  }

  // ─────────────────────────────────────────────────────────
  //  FOOTER
  // ─────────────────────────────────────────────────────────
  Widget _buildFooter({required String footerText, required String cafeName}) {
    return Column(children: [
      Container(height: 0.9, color: Colors.black),
      const SizedBox(height: 6),
      Text(
        footerText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          color: Colors.black,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        cafeName.toUpperCase(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.black,
          letterSpacing: 0.5,
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────
  //  DASHED LINE
  // ─────────────────────────────────────────────────────────
  Widget _buildDashedLine() {
    return LayoutBuilder(builder: (context, constraints) {
      const dashWidth = 4.0;
      const dashSpace = 3.0;
      final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
            count,
            (_) => const SizedBox(
                  width: dashWidth,
                  height: 0.8,
                  child: DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
                )),
      );
    });
  }

  // ─────────────────────────────────────────────────────────
  //  LOGO IMAGE
  // ─────────────────────────────────────────────────────────
  Widget _buildLogoImage(String pathOrUrl) {
    try {
      if (pathOrUrl.startsWith('data:image/')) {
        final commaIdx = pathOrUrl.indexOf(',');
        final base64Str =
            commaIdx != -1 ? pathOrUrl.substring(commaIdx + 1) : pathOrUrl;
        return Image.memory(base64Decode(base64Str),
            height: 72,
            width: 160,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _defaultLogo());
      } else if (pathOrUrl.startsWith('http://') ||
          pathOrUrl.startsWith('https://')) {
        return Image.network(pathOrUrl,
            height: 72,
            width: 160,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _defaultLogo());
      } else if (pathOrUrl.startsWith('assets/')) {
        return Image.asset(pathOrUrl,
            height: 72,
            width: 160,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _defaultLogo());
      } else if (!kIsWeb) {
        final file = File(pathOrUrl);
        if (file.existsSync()) {
          return Image.file(file,
              height: 72,
              width: 160,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _defaultLogo());
        }
      }
    } catch (_) {}
    return _defaultLogo();
  }

  Widget _defaultLogo() =>
      SizedBox(width: 68, height: 68, child: CustomPaint(painter: ChefHatPainter()));
}

/// Oshpazlik shapkasi + vilka ikonkasi — Rasm 4 ga mos.
class ChefHatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Shapka poyasi (brim)
    final brimRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.73, w * 0.84, h * 0.20),
      const Radius.circular(4),
    );
    canvas.drawRRect(brimRRect, strokePaint);

    // Shapka yon tomonlari
    final bodyPath = Path()
      ..moveTo(w * 0.18, h * 0.73)
      ..lineTo(w * 0.18, h * 0.44)
      ..moveTo(w * 0.82, h * 0.73)
      ..lineTo(w * 0.82, h * 0.44);
    canvas.drawPath(bodyPath, strokePaint);

    // Aylana dome
    final domeRect = Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.32), width: w * 0.74, height: h * 0.40);
    canvas.drawArc(domeRect, 3.14159, 3.14159, false, strokePaint);
    canvas.drawLine(
        Offset(w * 0.13, h * 0.44), Offset(w * 0.87, h * 0.44), strokePaint);

    // Vilka
    final forkX = w * 0.50;
    canvas.drawLine(
        Offset(forkX, h * 0.28),
        Offset(forkX, h * 0.66),
        Paint()
          ..color = Colors.black
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round);
    for (int i = -1; i <= 1; i++) {
      final tx = forkX + i * w * 0.09;
      canvas.drawLine(
          Offset(tx, h * 0.12),
          Offset(tx, h * 0.30),
          Paint()
            ..color = Colors.black
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round);
    }
    canvas.drawLine(
        Offset(forkX - w * 0.09, h * 0.30),
        Offset(forkX + w * 0.09, h * 0.30),
        Paint()
          ..color = Colors.black
          ..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Chekning yuqori va pastki qirralarini zigzag qilib qirquvchi clipper.
class ZigzagClipper extends CustomClipper<Path> {
  final double zigzagHeight;
  final double zigzagWidth;

  const ZigzagClipper({this.zigzagHeight = 6.0, this.zigzagWidth = 12.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, zigzagHeight);
    final countTop = (size.width / zigzagWidth).ceil();
    final topW = size.width / countTop;
    for (var i = 0; i < countTop; i++) {
      path.lineTo(i * topW + topW / 2, 0);
      path.lineTo((i + 1) * topW, zigzagHeight);
    }
    path.lineTo(size.width, size.height - zigzagHeight);
    final countBottom = (size.width / zigzagWidth).ceil();
    final bottomW = size.width / countBottom;
    for (var i = countBottom; i > 0; i--) {
      path.lineTo((i - 1) * bottomW + bottomW / 2, size.height);
      path.lineTo((i - 1) * bottomW, size.height - zigzagHeight);
    }
    path.lineTo(0, zigzagHeight);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
