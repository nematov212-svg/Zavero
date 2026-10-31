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
  final String? total;
  final String? subtitle;

  const ReceiptItem({
    this.index,
    required this.name,
    required this.quantity,
    required this.price,
    this.total,
    this.subtitle,
  });
}

/// 80mm Termal printer cheki — Reference chek (Chef hat, 2-ustun info, 5-ustun jadval) ga 100% mos dizayn.
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
      if (item.total != null && item.total!.trim().isNotEmpty) {
        sum += parsePrice(item.total!);
      } else {
        sum += parsePrice(item.price) * parseQuantity(item.quantity);
      }
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
    if (digits.isEmpty) return '000125';
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
                : "Navoi ko'chasi 12, Buxoro");

        final phone = (customPhone != null && customPhone!.trim().isNotEmpty)
            ? customPhone!.trim()
            : (appState.restaurantPhone.trim().isNotEmpty
                ? appState.restaurantPhone.trim()
                : '+998 90 123 45 67');

        final slogan = (customSlogan != null && customSlogan!.trim().isNotEmpty)
            ? customSlogan!.trim()
            : (appState.receiptSlogan.trim().isNotEmpty
                ? appState.receiptSlogan.trim()
                : "Yaxshi ta'm • Baxtli onlar");

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
        final finalTotal = total;
        final subtotalVal = calculatedSubtotal;
        final discountVal = (discount ?? 0).round();

        return ClipPath(
          clipper: const ZigzagClipper(zigzagHeight: 5, zigzagWidth: 10),
          child: Container(
            width: cardWidth,
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Settings bar (ixtiyoriy) ─────────────────────────────────
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── 1. HEADER: Chef Hat Logo + Family Cafe + Slogan ───────
                      _buildHeader(logoUrl, cafeName, slogan),
                      const SizedBox(height: 10),
                      Container(height: 1.0, color: Colors.black),
                      const SizedBox(height: 8),

                      // ── 2. INFO BLOK (2 ustun, markaziy vertikal ajratgich bilan) ─
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
                      const CustomPaint(
                        size: Size(double.infinity, 4),
                        painter: DashedLinePainter(),
                      ),
                      const SizedBox(height: 6),

                      // ── 3. MAHSULOTLAR JADVALI (5 ustun: № | Nomi | Miqdori | Narx | Summa) ──
                      _buildItemsTable(items),
                      const SizedBox(height: 6),
                      Container(height: 1.0, color: Colors.black),
                      const SizedBox(height: 8),

                      // ── 4. TOTALS (Jami, Chegirma, To'lov - ramkasiz) ─────────
                      _buildTotalsBlock(
                        subtotalVal: subtotalVal,
                        discountVal: discountVal,
                        grandTotalVal: finalTotal,
                      ),
                      const SizedBox(height: 6),
                      const CustomPaint(
                        size: Size(double.infinity, 4),
                        painter: DashedLinePainter(),
                      ),
                      const SizedBox(height: 12),

                      // ── 5. QR KOD (Yupqa yumaloq burchakli ramkali) ──────────
                      if (showQr) _buildQrSection(),
                      const SizedBox(height: 10),

                      // ── 6. FOOTER: Chiziq + Rahmat matni + Yurakcha + Kafe nomi ──
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
  //  HEADER: Chef Hat Logo + Family Cafe + Slogan
  // ─────────────────────────────────────────────────────────
  Widget _buildHeader(String? logoUrl, String cafeName, String slogan) {
    return Column(
      children: [
        if (logoUrl != null && logoUrl.trim().isNotEmpty && !logoUrl.contains('default'))
          _buildLogoImage(logoUrl.trim())
        else
          const SizedBox(
            width: 80,
            height: 56,
            child: CustomPaint(painter: ChefHatLogoPainter()),
          ),
        const SizedBox(height: 4),
        // "Family Cafe" on a SINGLE line, side-by-side
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              cafeName.contains(' ') ? cafeName.split(' ').first : 'Family',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                fontFamily: 'serif',
                fontFamilyFallback: ['Brush Script MT', 'cursive', 'Georgia', 'serif'],
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              cafeName.contains(' ') ? cafeName.split(' ').sublist(1).join(' ') : 'CAFE',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
        if (slogan.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 32, height: 1.0, color: Colors.black),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  slogan,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 32, height: 1.0, color: Colors.black),
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
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: Colors.black,
      height: 1.25,
    );
    const cafeTitleStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w800,
      color: Colors.black,
      height: 1.25,
    );

    Widget infoRow(IconData icon, String text, {bool isCafeTitle = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(icon, size: 15.0, color: Colors.black),
          const SizedBox(width: 6),
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
            infoRow(Icons.storefront_outlined, cafeName, isCafeTitle: true),
            infoRow(Icons.location_on_outlined, address),
            infoRow(Icons.phone_outlined, phone),
          ]),
        ),
        // Markaziy vertikal ajratgich chizig'i
        Container(
          width: 1.0,
          color: Colors.black,
          margin: const EdgeInsets.symmetric(horizontal: 8),
        ),
        // O'ng ustun: Sana, Vaqt, Chek No, Kassir
        Expanded(
          flex: 9,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            infoRow(Icons.calendar_today_outlined, dateStr),
            infoRow(Icons.access_time_outlined, timeStr),
            infoRow(Icons.receipt_outlined, 'Chek №: $checkId'),
            infoRow(Icons.person_outline, 'Kassir: $cashier'),
          ]),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  JADVAL: 5 USTUN (№ | Nomi | Miqdori | Narx | Summa)
  // ─────────────────────────────────────────────────────────
  Widget _buildItemsTable(List<ReceiptItem> itemsList) {
    const headerStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w900,
      color: Colors.black,
      letterSpacing: 0.2,
    );

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 26, child: Text('No', style: headerStyle)),
            Expanded(child: Text('Nomi', style: headerStyle)),
            SizedBox(
              width: 70,
              child: Text('Miqdori', textAlign: TextAlign.center, style: headerStyle),
            ),
            SizedBox(
              width: 105,
              child: Text('Narx', textAlign: TextAlign.right, style: headerStyle),
            ),
          ]),
        ),
        Container(height: 1.0, color: Colors.black),
        const SizedBox(height: 4),
        if (itemsList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
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
                  width: 26,
                  child: Text(
                    '$rowNum',
                    style: const TextStyle(
                      fontSize: 12.5,
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
                        fontSize: 13.0,
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
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                SizedBox(
                  width: 105,
                  child: Text(
                    '${money(price)} UZS',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
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
  //  TOTALS: Jami, Chegirma, To'lov (Ramkasiz, toza matnlar)
  // ─────────────────────────────────────────────────────────
  Widget _buildTotalsBlock({
    required int subtotalVal,
    required int discountVal,
    required int grandTotalVal,
  }) {
    return Column(
      children: [
        // Jami:
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Jami:',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              Text(
                "${money(subtotalVal)} so'm",
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        // Chegirma:
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Chegirma:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              Text(
                "${money(discountVal)} so'm",
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        // To'lov:
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "To'lov:",
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              Text(
                "${money(grandTotalVal)} so'm",
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  QR KOD: Yupqa yumaloq burchakli to'rtburchak ramkada
  // ─────────────────────────────────────────────────────────
  Widget _buildQrSection() {
    final qrData = appState.receiptQrUrl.isNotEmpty
        ? appState.receiptQrUrl
        : 'https://zavero-backend-production-7dc9.up.railway.app';

    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black, width: 1.2),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 100.0,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "QR skaner qiling va\nZavero web saytiga o'ting!",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  FOOTER: Chiziq + Rahmat matni + Yurakcha + Kafe nomi
  // ─────────────────────────────────────────────────────────
  Widget _buildFooter({required String footerText, required String cafeName}) {
    return Column(
      children: [
        Container(height: 1.0, color: Colors.black),
        const SizedBox(height: 6),
        Text(
          footerText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            fontFamily: 'serif',
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          '♡',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 24, height: 1.0, color: Colors.black),
            const SizedBox(width: 8),
            Text(
              cafeName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 24, height: 1.0, color: Colors.black),
          ],
        ),
      ],
    );
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
            height: 64,
            width: 140,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _defaultLogo());
      } else if (pathOrUrl.startsWith('http://') ||
          pathOrUrl.startsWith('https://')) {
        return Image.network(pathOrUrl,
            height: 64,
            width: 140,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _defaultLogo());
      } else if (pathOrUrl.startsWith('assets/')) {
        return Image.asset(pathOrUrl,
            height: 64,
            width: 140,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _defaultLogo());
      } else if (!kIsWeb) {
        final file = File(pathOrUrl);
        if (file.existsSync()) {
          return Image.file(file,
              height: 64,
              width: 140,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _defaultLogo());
        }
      }
    } catch (_) {}
    return _defaultLogo();
  }

  Widget _defaultLogo() => const SizedBox(
        width: 80,
        height: 56,
        child: CustomPaint(painter: ChefHatLogoPainter()),
      );
}

/// Chef qalpoqchasi emblemasi (ichida vilkalar va pichoq)
class ChefHatLogoPainter extends CustomPainter {
  const ChefHatLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final cx = w * 0.5;
    final cy = h * 0.5;

    // 1. Qalpoqcha pastki lentalari (2 ta gorizontal chiziq)
    canvas.drawLine(Offset(cx - 22, cy + 18), Offset(cx + 22, cy + 18), strokePaint);
    canvas.drawLine(Offset(cx - 20, cy + 24), Offset(cx + 20, cy + 24), strokePaint);
    canvas.drawLine(Offset(cx - 22, cy + 18), Offset(cx - 20, cy + 24), strokePaint);
    canvas.drawLine(Offset(cx + 22, cy + 18), Offset(cx + 20, cy + 24), strokePaint);

    // 2. Qalpoqcha tepasi (Puffy toque lobes)
    final hatPath = Path()
      ..moveTo(cx - 22, cy + 18)
      ..cubicTo(cx - 36, cy + 18, cx - 36, cy - 6, cx - 22, cy - 12)
      ..cubicTo(cx - 28, cy - 24, cx - 10, cy - 32, cx, cy - 24)
      ..cubicTo(cx + 10, cy - 32, cx + 28, cy - 24, cx + 22, cy - 12)
      ..cubicTo(cx + 36, cy - 6, cx + 36, cy + 18, cx + 22, cy + 18);
    canvas.drawPath(hatPath, strokePaint);

    // 3. Vilkalar (Chapda)
    final forkPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final forkPath = Path()
      ..moveTo(cx - 8, cy - 8)
      ..lineTo(cx - 8, cy + 10)
      ..moveTo(cx - 12, cy - 8)
      ..lineTo(cx - 12, cy)
      ..cubicTo(cx - 12, cy + 4, cx - 4, cy + 4, cx - 4, cy)
      ..lineTo(cx - 4, cy - 8);
    canvas.drawPath(forkPath, forkPaint);

    // 4. Pichoq (O'ngda)
    final knifePath = Path()
      ..moveTo(cx + 6, cy - 8)
      ..lineTo(cx + 6, cy + 10)
      ..moveTo(cx + 6, cy - 8)
      ..cubicTo(cx + 6, cy + 2, cx + 11, cy + 5, cx + 11, cy + 10);
    canvas.drawPath(knifePath, forkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shtrixli (dashed) gorizontal chiziq chizuvchi painter
class DashedLinePainter extends CustomPainter {
  final double dashWidth;
  final double dashSpace;
  final Color color;
  final double strokeWidth;

  const DashedLinePainter({
    this.dashWidth = 4.0,
    this.dashSpace = 3.0,
    this.color = Colors.black,
    this.strokeWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;

    double startX = 0;
    final y = size.height / 2;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Chekning yuqori va pastki qirralarini zigzag qilib qirquvchi clipper.
class ZigzagClipper extends CustomClipper<Path> {
  final double zigzagHeight;
  final double zigzagWidth;

  const ZigzagClipper({this.zigzagHeight = 5.0, this.zigzagWidth = 10.0});

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
