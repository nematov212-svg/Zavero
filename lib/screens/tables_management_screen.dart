import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/localization_service.dart';

class TablesManagementScreen extends StatefulWidget {
  const TablesManagementScreen({super.key});

  @override
  State<TablesManagementScreen> createState() => _TablesManagementScreenState();
}

class _TablesManagementScreenState extends State<TablesManagementScreen> {
  Hall? _selectedHall;

  @override
  void initState() {
    super.initState();
    if (appState.halls.isNotEmpty) {
      _selectedHall = appState.halls.first;
    }
  }

  void _showAddTableDialog() {
    final hall = _selectedHall ?? (appState.halls.isNotEmpty ? appState.halls.first : null);
    if (hall == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avval zal qo\'shing')),
      );
      return;
    }

    final currentTables = appState.tables.where((t) => t.hallId == hall.id).toList();
    int nextNum = 1;
    if (currentTables.isNotEmpty) {
      nextNum = currentTables.map((t) => t.number).reduce((a, b) => a > b ? a : b) + 1;
    }

    final numberCtrl = TextEditingController(text: nextNum.toString());
    final seatsCtrl = TextEditingController(text: '4');
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.add_circle_outline, color: kDarkYellow),
              const SizedBox(width: 10),
              Text('${hall.name} - Yangi stol', style: const TextStyle(fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stol raqami *',
                  prefixIcon: Icon(Icons.table_restaurant),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: seatsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sig\'imi (o\'rinlar soni)',
                  prefixIcon: Icon(Icons.chair_outlined),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kDarkYellow,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final numVal = int.tryParse(numberCtrl.text.trim());
                final seatsVal = int.tryParse(seatsCtrl.text.trim()) ?? 4;
                if (numVal == null || numVal <= 0) {
                  setDState(() => error = 'To\'g\'ri stol raqamini kiriting');
                  return;
                }
                final exists = appState.tables.any((t) => t.hallId == hall.id && t.number == numVal);
                if (exists) {
                  setDState(() => error = 'Bu zalda $numVal-raqamli stol allaqachon mavjud');
                  return;
                }
                await appState.addTableToHall(hallId: hall.id, number: numVal, seats: seatsVal);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${hall.name}ga $numVal-stol qo\'shildi')),
                  );
                }
              },
              child: const Text('Qo\'shish'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddHallDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Yangi zal qo\'shish'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Zal nomi *',
            hintText: 'Masalan: Yozgi ayvon, VIP zal',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kDarkYellow, foregroundColor: Colors.white),
            onPressed: () async {
              final n = nameCtrl.text.trim();
              if (n.isNotEmpty) {
                final newHall = await appState.addHall(n);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (mounted) {
                  setState(() {
                    _selectedHall = newHall;
                  });
                }
              }
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTable(TableModel table) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${table.number}-stol o\'chirilsinmi?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Ushbu ${table.number}-stolni o\'chirishni tasdiqlaysizmi?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final ok = await appState.deleteTableById(tableId: table.id, force: true);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? '${table.number}-stol muvaffaqiyatli o\'chirildi!' : 'Stolni o\'chirishda xatolik yuz berdi'),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('O\'chirish', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIALOG: BARCHA ESKI STOLLARNI TOZALASH (WIPE ALL TABLES)
  // ============================================================
  void _showClearAllTablesDialog() {
    final hallName = _selectedHall?.name ?? 'tanlangan zal';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text('Stollarni tozalash', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Haqiqatan ham barcha eski stollarni tozalab, o\'chirmoqchimisiz?\n\nBu amal qaytarilmaydi va yangi stollarni noldan qo\'shish imkonini beradi.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey)),
          ),
          if (_selectedHall != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent),
              onPressed: () async {
                Navigator.pop(ctx);
                final hallId = _selectedHall!.id;
                await appState.clearHallTables(hallId);
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$hallName zali stollari tozalandi!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text('$hallName stollarini tozalash'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await appState.clearAllTables();
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Barcha stollar butunlay tozalandi! Endi o\'zingiz yangi stol qo\'shishingiz mumkin.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Barchasini tozalash', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIALOG: ZALNI O'CHIRISH (DELETE HALL)
  // ============================================================
  void _confirmDeleteHall(Hall hall) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
            const SizedBox(width: 8),
            Text('${hall.name} zalini o\'chirish', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Haqiqatan ham "${hall.name}" zalini va uning barcha stollarini butunlay o\'chirmoqchimisiz?\n\nBu amal qaytarilmaydi.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await appState.deleteHall(hall.id);
              if (mounted) {
                setState(() {
                  _selectedHall = appState.halls.isNotEmpty ? appState.halls.first : null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${hall.name} zali muvaffaqiyatli o\'chirildi!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('O\'chirish', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIALOG: STOL UCHUN ALOXIDA QR KOD VA CHOP ETISH
  // ============================================================
  void _showTableQRDialog(TableModel table) {
    try {
      final curUser = appState.currentUser;
      final cafeId = curUser?.workspaceId ?? 'cafe1';
      final cafeName = curUser?.cafeName ?? 'ZAVERO';
      final hallName = _selectedHall?.name ?? 'Zal';
      final tableName = '${table.number}-stol ($hallName)';

      // Clean, fast web URL for QR Code
      final baseSocketUrl = ApiClient().socketUrl;
      final qrMenuUrl = '$baseSocketUrl/menu?cafeId=$cafeId&tableNumber=${table.number}&tableName=${Uri.encodeComponent(tableName)}&hallId=${table.hallId}';

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0x33FFB300), width: 1.5),
          ),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFFFB300), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${table.number}-stol QR Menyusi',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          Text(
                            hallName,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stand Card Container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFB300), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Cafe Branding Name
                      Text(
                        cafeName.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$tableName • $hallName'.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Fast QR Code (Fallback to QrImageView on offline)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        ),
                        child: SizedBox(
                          width: 160,
                          height: 160,
                          child: Image.network(
                            'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(qrMenuUrl)}',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return QrImageView(
                                data: qrMenuUrl,
                                size: 160.0,
                                backgroundColor: Colors.white,
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                                padding: const EdgeInsets.all(2),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFB300)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Scan Instruction
                      const Text(
                        '📸 Kamerangizni qarating',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Menyuni ko‘ring va qulay buyurtma bering',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFB300),
                          side: const BorderSide(color: Color(0xFFFFB300)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                        label: const Text('Ochish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          try {
                            final uri = Uri.parse(qrMenuUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          } catch (e) {
                            debugPrint('Launch URL error: $e');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Nusxalash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: qrMenuUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('QR Menyu havolasi nusxalandi! 📋'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Print Sticker Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('STIKERNI CHOP ETISH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _printTableQRSticker(
                        cafeName: cafeName,
                        tableNumber: table.number,
                        hallName: hallName,
                        qrUrl: qrMenuUrl,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error in _showTableQRDialog: $e');
    }
  }

  Future<void> _printTableQRSticker({
    required String cafeName,
    required int tableNumber,
    required String hallName,
    required String qrUrl,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, 110 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.black, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  cafeName.toUpperCase(),
                  style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.amber,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(
                    '$tableNumber-STOL ($hallName)',
                    style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrUrl,
                    width: 140,
                    height: 140,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'SMART QR MENYU',
                  style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                ),
                pw.Text(
                  'Kamerangizni qarating va taom tanlang!',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${cafeName}_${tableNumber}_stol_qr_stiker',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        if (_selectedHall == null && appState.halls.isNotEmpty) {
          _selectedHall = appState.halls.first;
        }

        final currentHallTables = _selectedHall == null
            ? <TableModel>[]
            : appState.tables.where((t) => t.hallId == _selectedHall!.id).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(tr('tables_management')),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                tooltip: 'Barcha stollarni tozalash',
                onPressed: _showClearAllTablesDialog,
              ),
              IconButton(
                icon: const Icon(Icons.add_home_work_outlined),
                tooltip: tr('add_hall'),
                onPressed: _showAddHallDialog,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: kDarkYellow,
            foregroundColor: Colors.white,
            onPressed: _showAddTableDialog,
            icon: const Icon(Icons.add),
            label: Text(tr('add_table')),
          ),
          body: Column(
            children: [
              // Hall Selection Chips
              if (appState.halls.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: appState.halls.map((h) {
                              final isSel = _selectedHall?.id == h.id;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(h.icon, size: 16, color: isSel ? Colors.white : Colors.black87),
                                      const SizedBox(width: 6),
                                      Text(h.name),
                                      if (isSel) ...[
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => _confirmDeleteHall(h),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent.withValues(alpha: 0.85),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, size: 13, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  selected: isSel,
                                  selectedColor: kDarkYellow,
                                  labelStyle: TextStyle(
                                    color: isSel ? Colors.white : Colors.black87,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedHall = h);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      if (_selectedHall != null)
                        IconButton(
                          tooltip: '${_selectedHall!.name} zalini o\'chirish',
                          icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 24),
                          onPressed: () => _confirmDeleteHall(_selectedHall!),
                        ),
                    ],
                  ),
                ),

              // Tables Grid
              Expanded(
                child: currentHallTables.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.table_restaurant_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _selectedHall == null
                                   ? 'Avval zal qo\'shing'
                                  : '${_selectedHall!.name}da hali stollar yo\'q',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: kDarkYellow, foregroundColor: Colors.white),
                              onPressed: _showAddTableDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Stol qo\'shish'),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.15,
                        ),
                        itemCount: currentHallTables.length,
                        itemBuilder: (context, i) {
                          final table = currentHallTables[i];
                          final isOccupied = table.status == TableStatus.occupied;
                          final isReserved = table.status == TableStatus.reserved;

                          Color statusColor = Colors.green;
                          String statusText = tr('table_free');
                          if (isOccupied) {
                            statusColor = Colors.redAccent;
                            statusText = tr('table_occupied');
                          } else if (isReserved) {
                            statusColor = Colors.amber;
                            statusText = 'Band qilingan';
                          }

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: IconButton(
                                              icon: const Icon(Icons.qr_code_2, size: 20, color: Color(0xFFFFC107)),
                                              padding: EdgeInsets.zero,
                                              tooltip: 'QR Menyu kodi & Chop etish',
                                              onPressed: () => _showTableQRDialog(table),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                              padding: EdgeInsets.zero,
                                              tooltip: 'O\'chirish',
                                              onPressed: () => _confirmDeleteTable(table),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Center(
                                    child: Text(
                                      '${table.number}-stol',
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.chair_outlined, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text('${table.seats} o\'rinli', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () => _showTableQRDialog(table),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          child: Text(
                                            'QR Menyu',
                                            style: TextStyle(color: Color(0xFFFFC107), fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
