import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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

/// 80mm Termal printer cheki — Image 5 (FAMILY CAFE) ga 100% mos dizayn.
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
    final cleaned = raw.replaceAll(',', '').replaceAll(' ', '').replaceAll('UZS', '').replaceAll("so'm", '').trim();
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
    if (digits.isEmpty) return '553532';
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
            : (appState.effectiveReceiptName.isNotEmpty ? appState.effectiveReceiptName : 'FAMILY CAFE');

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
                : "Yaxshi ta'm  •  Baxtli onlar");

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
        final cashier = waiter.trim().isNotEmpty ? waiter.trim() : 'Ali';

        const cardWidth = 370.0;
        final finalTotal = total;

        return ClipPath(
          clipper: const ZigzagClipper(zigzagHeight: 5, zigzagWidth: 10),
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
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── 1. HEADER: Coffee Cup with Steam & Beans + FAMILY CAFE + Slogan (Image 5) ─────
                      _buildHeader(logoUrl, cafeName, slogan),
                      const SizedBox(height: 10),
                      Container(height: 1.2, color: Colors.black),
                      const SizedBox(height: 8),

                      // ── 2. INFO BLOK (2 ustun, markaziy ajratgich bilan - Image 5) ─────────────────
                      _buildInfoBlock(
                        cafeName: cafeName,
                        address: address,
                        phone: phone,
                        dateStr: dateStr,
                        timeStr: timeStr,
                        checkId: formattedCheckId,
                        cashier: cashier,
                      ),
                      const SizedBox(height: 8),
                      Container(height: 1.2, color: Colors.black),
                      const SizedBox(height: 6),

                      // ── 3. MAHSULOTLAR JADVALI (4 ustun: № | Nomi | Miqdori | Narx - Image 5) ──────────────────
                      _buildItemsTable(items),
                      const SizedBox(height: 6),
                      Container(height: 1.2, color: Colors.black),
                      const SizedBox(height: 8),

                      // ── 4. TO'LOV: | <summa> UZS (Aylanma ramka - Image 5) ───────────
                      _buildPaymentBox(grandTotalVal: finalTotal),
                      const SizedBox(height: 16),

                      // ── 5. QR KOD (4 ta burchak qavslari va telefon ikonasi bilan - Image 5) ──
                      if (showQr) _buildQrSection(),
                      const SizedBox(height: 14),

                      // ── 6. COFFEE BEAN CHIZIG'I VA FOOTER (Image 5) ─────────────────────────────
                      _buildFooterWithBean(footerText: footerText, cafeName: cafeName),
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
  //  HEADER: Coffee Cup with Steam, Saucer & Coffee Beans (Image 5)
  // ─────────────────────────────────────────────────────────
  Widget _buildHeader(String? logoUrl, String cafeName, String slogan) {
    return Column(
      children: [
        if (logoUrl != null && logoUrl.trim().isNotEmpty && !logoUrl.contains('default'))
          _buildLogoImage(logoUrl.trim())
        else
          SizedBox(
            width: 320,
            height: 62,
            child: CustomPaint(painter: FamilyCafeCoffeeLogoPainter()),
          ),
        const SizedBox(height: 6),
        Text(
          cafeName.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: 1.8,
            height: 1.1,
          ),
        ),
        if (slogan.trim().isNotEmpty) ...[
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 36, height: 1.0, color: Colors.black),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  slogan,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 36, height: 1.0, color: Colors.black),
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
    const textStyle = TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.w600,
      color: Colors.black,
      height: 1.25,
    );
    const cafeTitleStyle = TextStyle(
      fontSize: 13.0,
      fontWeight: FontWeight.w800,
      color: Colors.black,
      height: 1.25,
    );

    Widget infoRow(IconData icon, String text, {bool isCafeTitle = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(icon, size: 16.0, color: Colors.black),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: isCafeTitle ? cafeTitleStyle : textStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      );
    }

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Chap ustun: Kafe, Manzil, Telefon
        Expanded(
          flex: 11,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            infoRow(Icons.home_outlined, cafeName, isCafeTitle: true),
            infoRow(Icons.location_on_outlined, address),
            infoRow(Icons.phone_outlined, phone),
          ]),
        ),
        // Markaziy vertikal ajratgich chizig'i
        Container(
          width: 1.0,
          color: Colors.black,
          margin: const EdgeInsets.symmetric(horizontal: 10),
        ),
        // O'ng ustun: Sana, Vaqt, Chek No, Kassir
        Expanded(
          flex: 9,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            infoRow(Icons.calendar_month_outlined, dateStr),
            infoRow(Icons.access_time_rounded, timeStr),
            infoRow(Icons.check_box_outlined, 'Chek No: $checkId'),
            infoRow(Icons.person_outline, 'Kassir: $cashier'),
          ]),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  JADVAL: 4 USTUN (№ | Nomi | Miqdori | Narx) — Summa ustuni YO'Q (Image 5)
  // ─────────────────────────────────────────────────────────
  Widget _buildItemsTable(List<ReceiptItem> itemsList) {
    const headerStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w900,
      color: Colors.black,
      letterSpacing: 0.2,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: const [
            SizedBox(width: 28, child: Text('№', style: headerStyle)),
            Expanded(child: Text('Nomi', style: headerStyle)),
            SizedBox(
              width: 70,
              child: Text('Miqdori', textAlign: TextAlign.center, style: headerStyle),
            ),
            SizedBox(
              width: 80,
              child: Text('Narx', textAlign: TextAlign.right, style: headerStyle),
            ),
          ]),
        ),
        Container(height: 0.8, color: Colors.black),
        const SizedBox(height: 4),
        if (itemsList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              "Buyurtmada taomlar yo'q",
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54),
            ),
          )
        else
          ...itemsList.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final rowNum = item.index ?? (idx + 1);
            final qty = parseQuantity(item.quantity);
            final price = parsePrice(item.price);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '$rowNum',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    if (item.subtitle != null && item.subtitle!.trim().isNotEmpty)
                      Text(
                        item.subtitle!.trim(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ]),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    '$qty dona',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    "${money(price)} UZS",
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ]),
            );
          }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  TO'LOV: | <summa> UZS (Aylanma to'rtburchak quti - Image 5)
  // ─────────────────────────────────────────────────────────
  Widget _buildPaymentBox({required int grandTotalVal}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1.8),
      ),
      child: Row(
        children: [
          const Text(
            "TO'LOV:",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Container(
            width: 1.4,
            height: 26,
            color: Colors.black,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const Spacer(),
          Text(
            "${money(grandTotalVal)} UZS",
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  QR KOD: 4 ta burchak qavsi (⌜ ⌝ ⌞ ⌟) va telefon ikonasi (Image 5)
  // ─────────────────────────────────────────────────────────
  Widget _buildQrSection() {
    final qrData = appState.receiptQrUrl.isNotEmpty
        ? appState.receiptQrUrl
        : 'https://zavero-backend-production-7dc9.up.railway.app';

    return Column(children: [
      Center(
        child: SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Corner brackets
              CustomPaint(
                size: const Size(130, 130),
                painter: QrCornerBracketsPainter(),
              ),
              // QR Code
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 98.0,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.smartphone_rounded, size: 22, color: Colors.black),
          const SizedBox(width: 8),
          const Text(
            "QR skaner qiling va\nZavero web saytiga o'ting!",
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.25,
            ),
          ),
        ],
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────
  //  FOOTER: Qahva donasi chizig'i + Rahmat matni + FAMILY CAFE (Image 5)
  // ─────────────────────────────────────────────────────────
  Widget _buildFooterWithBean({required String footerText, required String cafeName}) {
    return Column(children: [
      // Chiziq va markazida qahva donasi
      SizedBox(
        width: double.infinity,
        height: 18,
        child: CustomPaint(painter: CenterCoffeeBeanDividerPainter()),
      ),
      const SizedBox(height: 4),
      Text(
        footerText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          color: Colors.black,
        ),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 32, height: 1.2, color: Colors.black),
          const SizedBox(width: 8),
          Text(
            cafeName.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 32, height: 1.2, color: Colors.black),
        ],
      ),
    ]);
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

  Widget _defaultLogo() => const SizedBox(
        width: 320,
        height: 62,
        child: CustomPaint(painter: FamilyCafeCoffeeLogoPainter()),
      );
}

/// Coffee cup with steam, saucer, arch and 2 tilted coffee beans on sides (Image 5 Header)
class FamilyCafeCoffeeLogoPainter extends CustomPainter {
  const FamilyCafeCoffeeLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cx = w * 0.5;
    final cy = h * 0.62;

    // 1. Arch above coffee cup
    final archRect = Rect.fromCenter(
      center: Offset(cx, cy + h * 0.08),
      width: w * 0.28,
      height: h * 0.95,
    );
    canvas.drawArc(archRect, math.pi * 1.05, math.pi * 0.90, false, strokePaint);

    // 2. Coffee Cup (Filled body + handle + saucer)
    // Saucer:
    final saucerRect = Rect.fromCenter(
      center: Offset(cx, cy + 12),
      width: 44,
      height: 8,
    );
    canvas.drawOval(saucerRect, strokePaint);

    // Cup body:
    final cupPath = Path()
      ..moveTo(cx - 15, cy - 6)
      ..lineTo(cx + 15, cy - 6)
      ..cubicTo(cx + 15, cy + 10, cx - 15, cy + 10, cx - 15, cy - 6);
    canvas.drawPath(cupPath, fillPaint);

    // Cup handle on right:
    final handlePath = Path()
      ..moveTo(cx + 13, cy - 4)
      ..cubicTo(cx + 22, cy - 4, cx + 22, cy + 6, cx + 11, cy + 6);
    canvas.drawPath(handlePath, strokePaint..strokeWidth = 2.0);

    // 3. Steam rising (3 curls)
    // Center steam:
    final steam1 = Path()
      ..moveTo(cx, cy - 9)
      ..cubicTo(cx - 3, cy - 17, cx + 4, cy - 23, cx, cy - 30);
    canvas.drawPath(steam1, strokePaint..strokeWidth = 1.6);

    // Left steam:
    final steam2 = Path()
      ..moveTo(cx - 7, cy - 8)
      ..cubicTo(cx - 10, cy - 15, cx - 4, cy - 20, cx - 7, cy - 26);
    canvas.drawPath(steam2, strokePaint..strokeWidth = 1.4);

    // Right steam:
    final steam3 = Path()
      ..moveTo(cx + 7, cy - 8)
      ..cubicTo(cx + 10, cy - 15, cx + 4, cy - 20, cx + 7, cy - 26);
    canvas.drawPath(steam3, strokePaint..strokeWidth = 1.4);

    // 4. Side horizontal lines
    final lineY = cy + 2;
    // Left line:
    canvas.drawLine(Offset(4, lineY), Offset(cx - w * 0.28, lineY), strokePaint..strokeWidth = 1.5);
    // Right line:
    canvas.drawLine(Offset(cx + w * 0.28, lineY), Offset(w - 4, lineY), strokePaint..strokeWidth = 1.5);

    // 5. Left Coffee Bean (Tilted -35 deg)
    _drawCoffeeBean(canvas, Offset(cx - w * 0.21, lineY - 3), 7.5, -0.6);

    // 6. Right Coffee Bean (Tilted +35 deg)
    _drawCoffeeBean(canvas, Offset(cx + w * 0.21, lineY - 3), 7.5, 0.6);
  }

  static void _drawCoffeeBean(Canvas canvas, Offset center, double radius, double angleRad) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angleRad);

    final beanPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final beanRect = Rect.fromCenter(
      center: Offset.zero,
      width: radius * 2.2,
      height: radius * 1.4,
    );
    canvas.drawOval(beanRect, beanPaint);

    final creasePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final crease = Path()
      ..moveTo(-radius * 0.85, 0)
      ..cubicTo(-radius * 0.3, -radius * 0.45, radius * 0.3, radius * 0.45, radius * 0.85, 0);
    canvas.drawPath(crease, creasePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Divider line with coffee bean in the exact center (Image 5)
class CenterCoffeeBeanDividerPainter extends CustomPainter {
  const CenterCoffeeBeanDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;

    final strokePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Left line
    canvas.drawLine(Offset(2, cy), Offset(cx - 16, cy), strokePaint);
    // Right line
    canvas.drawLine(Offset(cx + 16, cy), Offset(w - 2, cy), strokePaint);

    // Center Coffee Bean
    FamilyCafeCoffeeLogoPainter._drawCoffeeBean(canvas, Offset(cx, cy), 7.5, 0.45);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 4 Corner brackets around the QR Code: ⌜ ⌝ ⌞ ⌟ (Image 5)
class QrCornerBracketsPainter extends CustomPainter {
  const QrCornerBracketsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const bracketLen = 14.0;
    const inset = 6.0;

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Top-left: ┌
    canvas.drawLine(const Offset(inset, inset), const Offset(inset + bracketLen, inset), paint);
    canvas.drawLine(const Offset(inset, inset), const Offset(inset, inset + bracketLen), paint);

    // Top-right: ┐
    canvas.drawLine(Offset(w - inset, inset), Offset(w - inset - bracketLen, inset), paint);
    canvas.drawLine(Offset(w - inset, inset), Offset(w - inset, inset + bracketLen), paint);

    // Bottom-left: └
    canvas.drawLine(Offset(inset, h - inset), Offset(inset + bracketLen, h - inset), paint);
    canvas.drawLine(Offset(inset, h - inset), Offset(inset, h - inset - bracketLen), paint);

    // Bottom-right: ┘
    canvas.drawLine(Offset(w - inset, h - inset), Offset(w - inset - bracketLen, h - inset), paint);
    canvas.drawLine(Offset(w - inset, h - inset), Offset(w - inset, h - inset - bracketLen), paint);
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
    for (var i = 0; i < countTop; i++) {
      final x1 = (i + 0.5) * zigzagWidth;
      final x2 = (i + 1) * zigzagWidth;
      path.lineTo(x1, 0);
      path.lineTo(x2, zigzagHeight);
    }
    path.lineTo(size.width, size.height - zigzagHeight);
    final countBottom = (size.width / zigzagWidth).ceil();
    for (var i = countBottom; i > 0; i--) {
      final x1 = (i - 0.5) * zigzagWidth;
      final x2 = (i - 1) * zigzagWidth;
      path.lineTo(x1, size.height);
      path.lineTo(x2, size.height - zigzagHeight);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
