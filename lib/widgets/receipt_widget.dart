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

/// 80mm Termal printer cheki — Rasm 2 (print) ga 100% mos preview widget.
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
            : (appState.restaurantPhone.trim().isNotEmpty ? appState.restaurantPhone.trim() : '+998 90 123 45 67');

        final slogan = (customSlogan != null && customSlogan!.trim().isNotEmpty)
            ? customSlogan!.trim()
            : (appState.receiptSlogan.trim().isNotEmpty ? appState.receiptSlogan.trim() : "Yaxshi ta'm  \u2022  Baxtli onlar");

        final footerText = (customFooter != null && customFooter!.trim().isNotEmpty)
            ? customFooter!.trim()
            : (appState.receiptFooterNote.trim().isNotEmpty
                ? appState.receiptFooterNote.trim()
                : 'Xaridingiz uchun rahmat!');

        final logoUrl = customLogoUrl ?? appState.appLogoUrl;
        final showQr = customShowQr ?? appState.receiptQrEnabled;

        String dateStr = dateOnly ?? '';
        String timeStr = timeOnly ?? '';
        if (dateStr.isEmpty || timeStr.isEmpty) {
          try {
            final parsed = DateTime.tryParse(dateTime);
            if (parsed != null) {
              dateStr = '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
              timeStr = '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
            } else {
              final now = DateTime.now();
              dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
              timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            }
          } catch (_) {
            final now = DateTime.now();
            dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
            timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          }
        }

        final formattedCheckId = formatCheckNumber(checkId);
        final cashier = waiter.trim().isNotEmpty ? waiter.trim() : 'Admin';
        final tableDisplay = table.trim().isNotEmpty ? table.trim() : '-';
        final payMethod = paymentMethod?.trim().isNotEmpty == true ? paymentMethod!.trim() : 'Karta';
        final paid = paidAmount ?? total.toDouble();
        final change = changeAmount ?? 0.0;

        final finalSubtotal = calculatedSubtotal > 0 ? calculatedSubtotal : total;
        final finalDiscount = (discount ?? 0).round();
        final finalTotal = total;
        final serviceLabel = 'Xizmat haqi (${(servicePercentage ?? 0).toStringAsFixed(0)}%):';
        final serviceVal = (serviceFee ?? 0).round();

        const cardWidth = 370.0;
        const ts = TextStyle(fontSize: 11.0, color: Colors.black87);
        const tsB = TextStyle(fontSize: 11.0, fontWeight: FontWeight.w800, color: Colors.black);
        const tsSm = TextStyle(fontSize: 10.0, color: Colors.black54);

        return ClipPath(
          clipper: const ZigzagClipper(zigzagHeight: 6, zigzagWidth: 12),
          child: Container(
            width: cardWidth,
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Settings bar ──────────────────────────────────────────
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
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                        ]),
                        if (onOpenSettings != null)
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, size: 17, color: Colors.black54),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: onOpenSettings,
                          ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ── 1. BRAND HEADER ───────────────────────────────────
                      Center(
                        child: logoUrl != null && logoUrl.trim().isNotEmpty
                            ? _buildLogoImage(logoUrl.trim())
                            : SizedBox(
                                width: 44, height: 38,
                                child: CustomPaint(painter: _ZaveroLogoPainter()),
                              ),
                      ),
                      const SizedBox(height: 3),
                      const Center(
                        child: Text('ZAVERO',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                                letterSpacing: 2.5, color: Colors.black)),
                      ),
                      // "— POS —"
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 30, height: 0.8, color: Colors.black),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('POS',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0, color: Colors.black)),
                        ),
                        Container(width: 30, height: 0.8, color: Colors.black),
                      ]),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(cafeName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black)),
                      ),
                      if (slogan.isNotEmpty)
                        Center(
                          child: Text(slogan,
                              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black54)),
                        ),
                      const SizedBox(height: 8),

                      // ── 2. TELEFON VA MANZIL ──────────────────────────────
                      Row(children: [
                        const Icon(Icons.phone_outlined, size: 12, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text(phone, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.black)),
                      ]),
                      const SizedBox(height: 2),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Colors.black54),
                        const SizedBox(width: 4),
                        Expanded(child: Text(address, style: const TextStyle(fontSize: 10, color: Colors.black87))),
                      ]),
                      const SizedBox(height: 10),

                      // ── 3. CHEK # | STOL (bir qatorda) ───────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(text: TextSpan(children: [
                            const TextSpan(text: 'Chek ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
                            TextSpan(text: '\u2116 $formattedCheckId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black)),
                          ])),
                          RichText(text: TextSpan(children: [
                            const TextSpan(text: 'Stol: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
                            TextSpan(text: tableDisplay, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black)),
                          ])),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // ── 4. SANA / XODIM ───────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sana:  $dateStr    $timeStr', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                          Text('Xodim:  $cashier', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ── 5. JADVAL SARLAVHASI (kulrang fon) ────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        color: Colors.grey.shade200,
                        child: Row(children: const [
                          SizedBox(width: 20, child: Text('No', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black87))),
                          Expanded(child: Text('Nomi', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black87))),
                          SizedBox(width: 30, child: Text('Dona', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black87))),
                          SizedBox(width: 44, child: Text('Narxi', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black87))),
                          SizedBox(width: 46, child: Text('Jami', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black87))),
                        ]),
                      ),
                      const SizedBox(height: 4),

                      // ── 6. MAHSULOTLAR ────────────────────────────────────
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text("Buyurtmada taomlar yo'q",
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54)),
                        )
                      else
                        ...items.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final rowNum = item.index ?? (idx + 1);
                          final qty = parseQuantity(item.quantity);
                          final price = parsePrice(item.price);
                          final jami = price * qty;
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  SizedBox(width: 20, child: Text('$rowNum', style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                  Expanded(child: Text(item.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black))),
                                  SizedBox(width: 30, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                  SizedBox(width: 44, child: Text(money(price), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                  SizedBox(width: 46, child: Text(money(jami), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black))),
                                ]),
                              ),
                              if (idx < items.length - 1)
                                _dashedLine(),
                            ],
                          );
                        }),
                      const SizedBox(height: 8),

                      // ── 7. SUBTOTALS ──────────────────────────────────────
                      _summaryRow('Mahsulotlar jami:', money(finalSubtotal), tsNorm: ts, tsBold: tsB),
                      const SizedBox(height: 3),
                      _summaryRow('Chegirma:', money(finalDiscount), tsNorm: ts, tsBold: tsB),
                      const SizedBox(height: 3),
                      _summaryRow(serviceLabel, money(serviceVal), tsNorm: ts, tsBold: tsB),
                      const SizedBox(height: 10),

                      // ── 8. QORA JAMI BLOKI ────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('JAMI:',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                            Text(money(finalTotal),
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── 9. TO'LOV MA'LUMOTLARI ────────────────────────────
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.credit_card_outlined, size: 16, color: Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(child: Column(children: [
                          _summaryRow("To'lov turi:", payMethod, tsNorm: ts, tsBold: tsB),
                          const SizedBox(height: 3),
                          _summaryRow("To'langan summa:", money(paid.round()), tsNorm: ts, tsBold: tsB),
                          const SizedBox(height: 3),
                          _summaryRow('Qaytim:', money(change.round()), tsNorm: ts, tsBold: tsB),
                        ])),
                      ]),
                      const SizedBox(height: 10),

                      // ── 10. AJRATUVCHI CHIZIQ ─────────────────────────────
                      Container(height: 0.8, color: Colors.black26),
                      const SizedBox(height: 10),

                      // ── 11. QR KOD ────────────────────────────────────────
                      if (showQr) ...[
                        Center(
                          child: QrImageView(
                            data: 'https://zavero-backend-production-7dc9.up.railway.app',
                            version: QrVersions.auto,
                            size: 100.0,
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ── 12. FOOTER ────────────────────────────────────────
                      Center(
                        child: Text(footerText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w700, color: Colors.black)),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text('ZAVERO POS — Kafe boshqaruvi osonroq.',
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                      ),
                      const SizedBox(height: 8),

                      // ── 13. YURAKCHA ─────────────────────────────────────
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 28, height: 0.8, color: Colors.black45),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('\u2665', style: TextStyle(fontSize: 14, color: Colors.black54)),
                        ),
                        Container(width: 28, height: 0.8, color: Colors.black45),
                      ]),
                      const SizedBox(height: 8),
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

  static Widget _summaryRow(String label, String value, {required TextStyle tsNorm, required TextStyle tsBold}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: tsNorm),
      Text(value, style: tsBold),
    ]);
  }

  static Widget _dashedLine() {
    return LayoutBuilder(builder: (context, constraints) {
      const dw = 3.5, ds = 3.0;
      final count = (constraints.maxWidth / (dw + ds)).floor();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (_) => const SizedBox(
            width: dw, height: 0.6,
            child: DecoratedBox(decoration: BoxDecoration(color: Colors.black26)),
          )),
        ),
      );
    });
  }

  Widget _buildLogoImage(String pathOrUrl) {
    try {
      if (pathOrUrl.startsWith('data:image/')) {
        final commaIdx = pathOrUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? pathOrUrl.substring(commaIdx + 1) : pathOrUrl;
        return Image.memory(base64Decode(base64Str), height: 48, width: 120, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _defaultLogo());
      } else if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
        return Image.network(pathOrUrl, height: 48, width: 120, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _defaultLogo());
      } else if (pathOrUrl.startsWith('assets/')) {
        return Image.asset(pathOrUrl, height: 48, width: 120, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _defaultLogo());
      } else if (!kIsWeb) {
        final file = File(pathOrUrl);
        if (file.existsSync()) {
          return Image.file(file, height: 48, width: 120, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _defaultLogo());
        }
      }
    } catch (_) {}
    return _defaultLogo();
  }

  Widget _defaultLogo() => SizedBox(width: 44, height: 38, child: CustomPaint(painter: _ZaveroLogoPainter()));
}

/// ZAVERO geometrik Z logosi — Rasm 2 ga mos CustomPainter.
class _ZaveroLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = true;

    // Z shakli (ZAVERO logo)
    final path = Path()
      ..moveTo(w * 0.12, h * 0.10)
      ..lineTo(w * 0.88, h * 0.10)
      ..lineTo(w * 0.12, h * 0.90)
      ..lineTo(w * 0.88, h * 0.90);

    canvas.drawPath(path, paint);

    // Yuqori diagonal chiziq
    final midPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(Offset(w * 0.12, h * 0.10), Offset(w * 0.88, h * 0.10), midPaint);
    canvas.drawLine(Offset(w * 0.12, h * 0.90), Offset(w * 0.88, h * 0.90), midPaint);
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

/// Eski ChefHatPainter — boshqa joylar uchun saqlanadi
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
    final brimRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.73, w * 0.84, h * 0.20), const Radius.circular(4));
    canvas.drawRRect(brimRRect, strokePaint);
    final bodyPath = Path()
      ..moveTo(w * 0.18, h * 0.73)..lineTo(w * 0.18, h * 0.44)
      ..moveTo(w * 0.82, h * 0.73)..lineTo(w * 0.82, h * 0.44);
    canvas.drawPath(bodyPath, strokePaint);
    final domeRect = Rect.fromCenter(center: Offset(w * 0.50, h * 0.32), width: w * 0.74, height: h * 0.40);
    canvas.drawArc(domeRect, 3.14159, 3.14159, false, strokePaint);
    canvas.drawLine(Offset(w * 0.13, h * 0.44), Offset(w * 0.87, h * 0.44), strokePaint);
    final forkX = w * 0.50;
    canvas.drawLine(Offset(forkX, h * 0.28), Offset(forkX, h * 0.66),
        Paint()..color = Colors.black..strokeWidth = 2.0..strokeCap = StrokeCap.round);
    for (int i = -1; i <= 1; i++) {
      final tx = forkX + i * w * 0.09;
      canvas.drawLine(Offset(tx, h * 0.12), Offset(tx, h * 0.30),
          Paint()..color = Colors.black..strokeWidth = 1.8..strokeCap = StrokeCap.round);
    }
    canvas.drawLine(Offset(forkX - w * 0.09, h * 0.30), Offset(forkX + w * 0.09, h * 0.30),
        Paint()..color = Colors.black..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
