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

  const ReceiptItem({
    this.index,
    required this.name,
    required this.quantity,
    required this.price,
  });
}

/// 80mm Thermal Printer cheki — Reference dizaynga 1:1 mos keladigan professional chek widgeti.
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

  /// Narx matnidan (masalan "25 000 so'm" yoki "25000") raqamlarni oladi.
  static int parsePrice(String raw) {
    final cleaned = raw.replaceAll(',', '').replaceAll(' ', '').trim();
    final digitsOnly = RegExp(r'\d+').stringMatch(cleaned) ?? '0';
    return int.tryParse(digitsOnly) ?? 0;
  }

  /// Miqdor matnidan (masalan "2 dona", "2") faqat raqamlarni oladi.
  static int parseQuantity(String raw) {
    final digits = RegExp(r'\d+').stringMatch(raw) ?? '0';
    final val = int.tryParse(digits) ?? 1;
    return val <= 0 ? 1 : val;
  }

  /// Barcha mahsulotlarning (dona narxi x soni) jamini hisoblaydi.
  int get total {
    if (customTotal != null && customTotal! > 0) {
      return customTotal!.round();
    }
    var sum = 0;
    for (final item in items) {
      final unitPrice = parsePrice(item.price);
      final qty = parseQuantity(item.quantity);
      sum += unitPrice * qty;
    }
    return sum;
  }

  /// Butun sonni "25 000" ko'rinishida formatlaydi.
  static String money(int value) {
    final isNegative = value < 0;
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final posFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) {
        buffer.write(' ');
      }
    }
    return (isNegative ? '-' : '') + buffer.toString();
  }

  /// Chek raqamini 6 xonali qilib formatlaydi (masalan: 000125)
  static String formatCheckNumber(String rawId) {
    final digits = RegExp(r'\d+').allMatches(rawId).map((m) => m.group(0)).join();
    if (digits.isEmpty) return '000001';
    if (digits.length >= 6) return digits.substring(digits.length - 6);
    return digits.padLeft(6, '0');
  }

  /// Miqdor matnini har doim "X dona" ko'rinishida chiqaradi
  static String formatQuantityText(String raw) {
    final qty = parseQuantity(raw);
    return '$qty dona';
  }

  /// Narx matnini "25 000 so'm" ko'rinishida chiqaradi
  static String formatPriceText(String raw) {
    final price = parsePrice(raw);
    return '${money(price)} so\'m';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final cafeName = (customCafeName != null && customCafeName!.trim().isNotEmpty)
            ? customCafeName!.trim()
            : appState.effectiveReceiptName;

        final address = (customAddress != null && customAddress!.trim().isNotEmpty)
            ? customAddress!.trim()
            : (appState.restaurantAddress.trim().isNotEmpty ? appState.restaurantAddress.trim() : 'Navoiy ko\'chasi 12, Buxoro');

        final phone = (customPhone != null && customPhone!.trim().isNotEmpty)
            ? customPhone!.trim()
            : (appState.restaurantPhone.trim().isNotEmpty ? appState.restaurantPhone.trim() : '+998 90 123 45 67');

        final slogan = (customSlogan != null && customSlogan!.trim().isNotEmpty)
            ? customSlogan!.trim()
            : (appState.receiptSlogan.trim().isNotEmpty ? appState.receiptSlogan.trim() : 'Yaxshi ta\'m  •  Baxtli onlar');

        final footerText = (customFooter != null && customFooter!.trim().isNotEmpty)
            ? customFooter!.trim()
            : (appState.receiptFooterNote.trim().isNotEmpty ? appState.receiptFooterNote.trim() : 'Bizni tanlaganingiz uchun rahmat!');

        final logoUrl = customLogoUrl ?? appState.appLogoUrl;
        final showQr = customShowQr ?? appState.receiptQrEnabled;

        // Sana va vaqt
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
        final cashierDisplayName = waiter.trim().isNotEmpty ? waiter.trim() : 'Admin';

        // 80mm thermal paper standard width in preview
        const cardWidth = 370.0;

        return ClipPath(
          clipper: const ZigzagClipper(zigzagHeight: 5, zigzagWidth: 10),
          child: Container(
            width: cardWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // QO'SHIMCHA MENYU TUGMASI (AGAR SOZLAMA BO'LSA)
                if (showThreeDotsMenu)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.receipt_long, size: 16, color: Colors.black87),
                            const SizedBox(width: 6),
                            Text(
                              "80mm Chek Ko'rinishi",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        if (onOpenSettings != null)
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, size: 18, color: Colors.black87),
                            tooltip: 'Chek sozlamalari',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: onOpenSettings,
                          ),
                      ],
                    ),
                  ),

                // ASOSIY CHEK BADANI
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ==========================================
                      // 1. HEADER: LOGO + KAFE NOMI + SLOGAN
                      // ==========================================
                      _buildHeaderLogo(cafeName, slogan, logoUrl),

                      const SizedBox(height: 12),

                      // ASOSIY TO'G'RI CHIZIQ (SOLID DIVIDER)
                      Container(height: 1.5, color: Colors.black),

                      const SizedBox(height: 10),

                      // ==========================================
                      // 2. KAFE VA CHEK MA'LUMOTLARI (2 USTUNLI)
                      // ==========================================
                      _buildInfoSection(
                        cafeName: cafeName,
                        address: address,
                        phone: phone,
                        dateStr: dateStr,
                        timeStr: timeStr,
                        checkId: formattedCheckId,
                        cashierName: cashierDisplayName,
                      ),

                      const SizedBox(height: 10),

                      // DASHED DIVIDER CHIZIQ
                      _buildDashedLine(),

                      const SizedBox(height: 10),

                      // ==========================================
                      // 3. MAHSULOTLAR JADVALI SARLAVHASI
                      // № | Nomi | Miqdori | Narx
                      // (SUMMA USTUNI UMUMAN YO'Q)
                      // ==========================================
                      _buildTableHeader(),

                      const SizedBox(height: 8),

                      // ==========================================
                      // 4. MAHSULOTLAR RO'YXATI
                      // ==========================================
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              "Buyurtmada mahsulotlar yo'q",
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        )
                      else
                        ...List.generate(items.length, (index) {
                          final item = items[index];
                          final rowNum = item.index ?? (index + 1);
                          return _buildTableRow(
                            num: rowNum,
                            name: item.name,
                            qty: formatQuantityText(item.quantity),
                            price: formatPriceText(item.price),
                          );
                        }),

                      const SizedBox(height: 12),

                      // TO'LIQ TO'G'RI CHIZIQ
                      Container(height: 1.0, color: Colors.black38),

                      const SizedBox(height: 10),

                      // ==========================================
                      // 5. JAMI HISOB (KREDIT KARTA BELGISI BILAN)
                      // ==========================================
                      _buildTotalRow(total),

                      const SizedBox(height: 14),

                      // ==========================================
                      // 6. QR CODE QISMI
                      // ==========================================
                      if (showQr) ...[
                        _buildQrCodeSection(),
                        const SizedBox(height: 14),
                      ],

                      // ==========================================
                      // 7. YURAKCHA DIVIDER ( ── ♡ ── )
                      // ==========================================
                      _buildHeartDivider(),

                      const SizedBox(height: 10),

                      // ==========================================
                      // 8. FOOTER: RAHMAT MATNI VA KAFE NOMI
                      // ==========================================
                      _buildFooterSection(footerText, cafeName),

                      const SizedBox(height: 4),
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

  /// 1. Top Logo Header
  Widget _buildHeaderLogo(String cafeName, String slogan, String? logoUrl) {
    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      return Column(
        children: [
          _buildCustomLogoImage(logoUrl.trim()),
          const SizedBox(height: 8),
          Text(
            cafeName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: Colors.black,
            ),
          ),
          if (slogan.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              slogan,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      );
    }

    // Default Reference Logo: Chef hat + Fork/Knife + "Family Cafe" + Slogan
    return Column(
      children: [
        // Chef hat with fork and knife icon
        SizedBox(
          height: 48,
          width: 54,
          child: CustomPaint(
            painter: ChefHatPainter(),
          ),
        ),
        const SizedBox(height: 4),
        // Stylized Brand Name
        Text(
          cafeName.isNotEmpty ? cafeName : 'Family Cafe',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
            fontStyle: FontStyle.italic,
            letterSpacing: 0.5,
            color: Colors.black,
          ),
        ),
        Container(
          width: 46,
          height: 1.5,
          color: Colors.black,
          margin: const EdgeInsets.only(top: 1, bottom: 4),
        ),
        if (slogan.isNotEmpty)
          Text(
            slogan,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              color: Colors.black87,
            ),
          ),
      ],
    );
  }

  /// Logo rasmini har qanday manbadan (Base64, Network, File, Asset) yuklash
  Widget _buildCustomLogoImage(String pathOrUrl) {
    try {
      if (pathOrUrl.startsWith('data:image/')) {
        final commaIdx = pathOrUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? pathOrUrl.substring(commaIdx + 1) : pathOrUrl;
        final bytes = base64Decode(base64Str);
        return ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.dstIn),
          child: Image.memory(
            bytes,
            height: 60,
            width: 140,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, size: 48, color: Colors.black),
          ),
        );
      } else if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
        return Image.network(
          pathOrUrl,
          height: 60,
          width: 140,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, size: 48, color: Colors.black),
        );
      } else if (pathOrUrl.startsWith('assets/')) {
        return Image.asset(
          pathOrUrl,
          height: 60,
          width: 140,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, size: 48, color: Colors.black),
        );
      } else if (!kIsWeb) {
        final file = File(pathOrUrl);
        if (file.existsSync()) {
          return Image.file(
            file,
            height: 60,
            width: 140,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, size: 48, color: Colors.black),
          );
        }
      }
    } catch (_) {}

    return const Icon(Icons.restaurant, size: 48, color: Colors.black);
  }

  /// 2. Kafe va Chek ma'lumotlari (2 ustunli)
  Widget _buildInfoSection({
    required String cafeName,
    required String address,
    required String phone,
    required String dateStr,
    required String timeStr,
    required String checkId,
    required String cashierName,
  }) {
    const textStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Colors.black,
      height: 1.3,
    );
    const boldStyle = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      color: Colors.black,
      height: 1.3,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CHAP USTUN: Kafe Nomi, Manzil, Telefon
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.storefront_outlined, size: 14, color: Colors.black),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cafeName,
                        style: boldStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.black),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: textStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: Colors.black),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        phone,
                        style: textStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // O'RTA VERTICAL DIVIDER
          Container(
            width: 1.0,
            color: Colors.black54,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // O'NG USTUN: Sana, Vaqt, Chek №, Kassir
          Expanded(
            flex: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.black),
                    const SizedBox(width: 6),
                    Text(dateStr, style: textStyle),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_outlined, size: 13, color: Colors.black),
                    const SizedBox(width: 6),
                    Text(timeStr, style: textStyle),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.receipt_outlined, size: 13, color: Colors.black),
                    const SizedBox(width: 6),
                    Text('Chek №: $checkId', style: textStyle),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 13, color: Colors.black),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Kassir: $cashierName',
                        style: textStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dashed Horizontal Line
  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 4.0;
        const dashSpace = 3.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1.0,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black87),
              ),
            );
          }),
        );
      },
    );
  }

  /// 3. Table Header: № | Nomi | Miqdori | Narx
  Widget _buildTableHeader() {
    const headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: Colors.black,
    );

    return const Row(
      children: [
        SizedBox(
          width: 22,
          child: Text('№', style: headerStyle),
        ),
        Expanded(
          flex: 6,
          child: Text('Nomi', style: headerStyle),
        ),
        Expanded(
          flex: 3,
          child: Text('Miqdori', textAlign: TextAlign.center, style: headerStyle),
        ),
        Expanded(
          flex: 4,
          child: Text('Narx', textAlign: TextAlign.right, style: headerStyle),
        ),
      ],
    );
  }

  /// 4. Table Row
  Widget _buildTableRow({
    required int num,
    required String name,
    required String qty,
    required String price,
  }) {
    const cellStyle = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
      color: Colors.black,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text('$num', style: cellStyle),
          ),
          Expanded(
            flex: 6,
            child: Text(
              name,
              style: cellStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              qty,
              textAlign: TextAlign.center,
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              price,
              textAlign: TextAlign.right,
              style: cellStyle,
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Total Row
  Widget _buildTotalRow(int totalSum) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(Icons.payment, size: 22, color: Colors.black),
            SizedBox(width: 8),
            Text(
              'Jami:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ],
        ),
        Text(
          '${money(totalSum)} so\'m',
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  /// 6. QR Code Section (URL matnisiz, haqiqiy ishlaydigan QR)
  Widget _buildQrCodeSection() {
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 1.0),
            ),
            child: QrImageView(
              data: 'https://zaverouz.netlify.app/',
              version: QrVersions.auto,
              size: 115.0,
              padding: const EdgeInsets.all(4),
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.crop_free, size: 18, color: Colors.black),
            SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QR skaner qiling va',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Zavero web saytiga o\'ting!',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// 7. Heart Divider ( ─── ♡ ─── )
  Widget _buildHeartDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1.0, color: Colors.black87),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.favorite_border, size: 15, color: Colors.black87),
        ),
        Expanded(
          child: Container(height: 1.0, color: Colors.black87),
        ),
      ],
    );
  }

  /// 8. Footer Section
  Widget _buildFooterSection(String footerText, String cafeName) {
    return Column(
      children: [
        Text(
          footerText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 24, height: 1.0, color: Colors.black87),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                cafeName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
            Container(width: 24, height: 1.0, color: Colors.black87),
          ],
        ),
      ],
    );
  }
}

/// Chekning yuqori va pastki qirrasini termal qog'ozdek yirtilgan (zigzag) qilib qirquvchi clipper.
class ZigzagClipper extends CustomClipper<Path> {
  final double zigzagHeight;
  final double zigzagWidth;

  const ZigzagClipper({this.zigzagHeight = 5.0, this.zigzagWidth = 10.0});

  @override
  Path getClip(Size size) {
    final path = Path();

    // Tepadan zigzag
    path.moveTo(0, zigzagHeight);
    final countTop = (size.width / zigzagWidth).ceil();
    final actualWidthTop = size.width / countTop;
    for (var i = 0; i < countTop; i++) {
      final x1 = i * actualWidthTop + actualWidthTop / 2;
      const y1 = 0.0;
      final x2 = (i + 1) * actualWidthTop;
      final y2 = zigzagHeight;
      path.lineTo(x1, y1);
      path.lineTo(x2, y2);
    }

    // O'ng tomondan pastga
    path.lineTo(size.width, size.height - zigzagHeight);

    // Pastdan zigzag
    final countBottom = (size.width / zigzagWidth).ceil();
    final actualWidthBottom = size.width / countBottom;
    for (var i = countBottom; i > 0; i--) {
      final x1 = (i - 1) * actualWidthBottom + actualWidthBottom / 2;
      final y1 = size.height;
      final x2 = (i - 1) * actualWidthBottom;
      final y2 = size.height - zigzagHeight;
      path.lineTo(x1, y1);
      path.lineTo(x2, y2);
    }

    // Chap tomondan tepaga
    path.lineTo(0, zigzagHeight);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Standart Reference Chef Hat + Cutlery ikonkasi chizgichi
class ChefHatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Oshpaz qalpog'i (Chef Hat outline)
    final w = size.width;
    final h = size.height;

    final path = Path();
    // Baza
    final baseY = h * 0.85;
    path.moveTo(w * 0.22, baseY);
    path.lineTo(w * 0.78, baseY);

    // Quloqchalar va doiralar
    path.lineTo(w * 0.78, h * 0.65);
    path.cubicTo(w * 0.95, h * 0.60, w * 0.95, h * 0.30, w * 0.72, h * 0.25);
    path.cubicTo(w * 0.70, h * 0.05, w * 0.30, h * 0.05, w * 0.28, h * 0.25);
    path.cubicTo(w * 0.05, h * 0.30, w * 0.05, h * 0.60, w * 0.22, h * 0.65);
    path.close();

    canvas.drawPath(path, paint);

    // Qalpog' ostidagi chiziq
    canvas.drawLine(
      Offset(w * 0.25, h * 0.95),
      Offset(w * 0.75, h * 0.95),
      paint..strokeWidth = 1.8,
    );

    // Ichidagi vilka va pichoq
    // Vilka
    final forkX = w * 0.42;
    canvas.drawLine(Offset(forkX, h * 0.42), Offset(forkX, h * 0.75), paint..strokeWidth = 1.5);
    canvas.drawLine(Offset(forkX - 3, h * 0.42), Offset(forkX - 3, h * 0.55), paint..strokeWidth = 1.2);
    canvas.drawLine(Offset(forkX + 3, h * 0.42), Offset(forkX + 3, h * 0.55), paint..strokeWidth = 1.2);
    canvas.drawLine(Offset(forkX - 3, h * 0.55), Offset(forkX + 3, h * 0.55), paint..strokeWidth = 1.2);

    // Pichoq
    final knifeX = w * 0.58;
    canvas.drawLine(Offset(knifeX, h * 0.42), Offset(knifeX, h * 0.75), paint..strokeWidth = 1.5);
    final knifeBlade = Path()
      ..moveTo(knifeX, h * 0.42)
      ..quadraticBezierTo(knifeX + 4, h * 0.48, knifeX, h * 0.58)
      ..close();
    canvas.drawPath(knifeBlade, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
