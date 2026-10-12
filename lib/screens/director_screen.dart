import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/director_service.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/pin_security_service.dart';
import 'auth_screen.dart';
import 'cafe_management_screen.dart';

class DirectorScreen extends StatefulWidget {
  final AppUser directorUser;
  const DirectorScreen({super.key, required this.directorUser});

  @override
  State<DirectorScreen> createState() => _DirectorScreenState();
}

class _DirectorScreenState extends State<DirectorScreen> with SingleTickerProviderStateMixin {
  final DirectorService _ds = DirectorService();
  late TabController _tabController;
  int _currentTabIndex = 0;

  DirectorMetrics _metrics = DirectorMetrics();
  List<CafeSaaSItem> _cafes = [];
  List<DeviceInfo> _devices = [];
  List<Map<String, dynamic>> _supportTickets = [];
  StreamSubscription? _supportSub;

  int get _unresolvedTicketsCount =>
      _supportTickets.where((t) => t['status'] != 'resolved').length;

  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _currentTabIndex) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
    _supportSub = SocketService().on(CafeSocketEvent.supportIssueReported).listen((_) {
      _loadSupportTickets();
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _supportSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSupportTickets() async {
    try {
      final tickets = await _ds.getSupportTickets();
      if (mounted) setState(() => _supportTickets = tickets);
    } catch (_) {}
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final metricsFuture = _ds.getMetrics();
      final cafesFuture = _ds.getCafes(q: _searchQuery, status: _statusFilter);
      final devicesFuture = _ds.getDevices();
      final ticketsFuture = _ds.getSupportTickets();

      final results = await Future.wait([metricsFuture, cafesFuture, devicesFuture, ticketsFuture]);

      if (!mounted) return;
      setState(() {
        _metrics = results[0] as DirectorMetrics;
        _cafes = results[1] as List<CafeSaaSItem>;
        _devices = results[2] as List<DeviceInfo>;
        _supportTickets = results[3] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ma\'lumotlarni yuklashda xatolik: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await appState.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (r) => false,
    );
  }

  // ============================================================
  // DIALOGS: CREATE CAFE
  // ============================================================
  void _showCreateCafeDialog() {
    final nameCtrl = TextEditingController();
    final receiptCtrl = TextEditingController();
    final ownerNameCtrl = TextEditingController();
    final ownerPhoneCtrl = TextEditingController();
    final ownerEmailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool obscurePass = true;
    int days = 30;
    bool saving = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.storefront, color: Color(0xFFFFC107)),
              SizedBox(width: 10),
              Text('Yangi Cafe qo\'shish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Kafe nomi *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Masalan: Samarqand Osh Markazi',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (v) {
                      if (receiptCtrl.text.isEmpty || (nameCtrl.text.isNotEmpty && receiptCtrl.text == nameCtrl.text.substring(0, nameCtrl.text.length - 1))) {
                        receiptCtrl.text = v;
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: receiptCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Chekda chiqadigan nom (Receipt Name)',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Masalan: SAMARQAND OSH',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ownerNameCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Kafe egasi F.I.Sh *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Masalan: Rustam Karimov',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ownerPhoneCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Telefon raqam',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: '+998 90 123 45 67',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Manzil',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Masalan: Samarqand sh., Registon ko\'chasi 14',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ownerEmailCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Egasi login / emaili (@cafe.uz) *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'nom@cafe.uz',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    obscureText: obscurePass,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Dastlabki parol (faqat raqam) *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Parolni kiriting',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePass ? Icons.visibility_off : Icons.visibility,
                          color: Colors.black54,
                        ),
                        onPressed: () => setDlgState(() => obscurePass = !obscurePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Dastlabki obuna muddati:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1, 30, 60, 90, 120, 280, 365, 36500].map((d) {
                      final selected = days == d;
                      final labelText = d == 1 ? '1 kun' : (d == 36500 ? '♾️ Cheksiz' : '$d kun');
                      return ChoiceChip(
                        label: Text(
                          labelText,
                          style: TextStyle(
                            color: selected ? Colors.black87 : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: selected,
                        selectedColor: const Color(0xFFFFC107),
                        backgroundColor: const Color(0xFF334155),
                        side: BorderSide(color: selected ? const Color(0xFFFFC107) : Colors.white24),
                        onSelected: (val) {
                          if (val) setDlgState(() => days = d);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black87,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final ownerName = ownerNameCtrl.text.trim();
                      final email = ownerEmailCtrl.text.trim().toLowerCase();
                      final pass = passCtrl.text.trim();

                      if (name.isEmpty || email.isEmpty || pass.isEmpty) {
                        setDlgState(() => error = 'Barcha majburiy (*) maydonlarni to\'ldiring');
                        return;
                      }
                      if (pass.length < 4) {
                        setDlgState(() => error = 'Parol kamida 4 ta raqamdan iborat bo\'lishi shart!');
                        return;
                      }
                      if (!email.endsWith('@cafe.uz')) {
                        setDlgState(() => error = 'Email formati qat\'iy ravishda @cafe.uz bilan tugashi shart!');
                        return;
                      }

                      setDlgState(() {
                        saving = true;
                        error = null;
                      });

                      try {
                        await _ds.createCafe(
                          cafeName: name,
                          receiptName: receiptCtrl.text.trim(),
                          ownerName: ownerName,
                          ownerPhone: ownerPhoneCtrl.text.trim(),
                          ownerEmail: email,
                          ownerPassword: pass,
                          durationDays: days,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadAllData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Yangi cafe muvaffaqiyatli ochildi!'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setDlgState(() {
                          saving = false;
                          error = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('CAFE YARATISH', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOGS: EDIT CAFE (TAHRIRLASH)
  // ============================================================
  void _showEditCafeDialog(CafeSaaSItem cafe) {
    final nameCtrl = TextEditingController(text: cafe.name);
    final receiptCtrl = TextEditingController(text: cafe.receiptName);
    final ownerNameCtrl = TextEditingController(text: cafe.ownerName);
    final ownerPhoneCtrl = TextEditingController(text: cafe.ownerPhone);
    final ownerEmailCtrl = TextEditingController(text: cafe.ownerEmail);
    final passCtrl = TextEditingController();
    bool obscurePass = true;
    String status = cafe.status.isNotEmpty ? cafe.status : (cafe.isBlocked ? 'blocked' : 'active');
    bool saving = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFFFFC107)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${cafe.name} — Tahrirlash', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Kafe nomi *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: receiptCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Chekda chiqadigan nom',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ownerNameCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Kafe egasi F.I.Sh',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ownerPhoneCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Telefon raqam',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ownerEmailCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Egasi login / email (@cafe.uz)',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    obscureText: obscurePass,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Yangi parol (o\'zgartirish shart bo\'lsa)',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Bo\'sh qoldirilsa o\'zgarmaydi',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePass ? Icons.visibility_off : Icons.visibility,
                          color: Colors.black54,
                        ),
                        onPressed: () => setDlgState(() => obscurePass = !obscurePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Kafe holati:', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Faol (Active)'),
                        selected: status == 'active',
                        selectedColor: Colors.green,
                        backgroundColor: const Color(0xFF334155),
                        labelStyle: TextStyle(color: status == 'active' ? Colors.white : Colors.white70, fontWeight: FontWeight.bold),
                        onSelected: (val) {
                          if (val) setDlgState(() => status = 'active');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Bloklangan'),
                        selected: status == 'blocked',
                        selectedColor: Colors.redAccent,
                        backgroundColor: const Color(0xFF334155),
                        labelStyle: TextStyle(color: status == 'blocked' ? Colors.white : Colors.white70, fontWeight: FontWeight.bold),
                        onSelected: (val) {
                          if (val) setDlgState(() => status = 'blocked');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black87,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        setDlgState(() => error = 'Kafe nomi kiritilishi shart!');
                        return;
                      }

                      setDlgState(() {
                        saving = true;
                        error = null;
                      });

                      try {
                        await _ds.updateCafe(
                          cafeId: cafe.cafeId,
                          cafeName: name,
                          receiptName: receiptCtrl.text.trim(),
                          ownerName: ownerNameCtrl.text.trim(),
                          ownerPhone: ownerPhoneCtrl.text.trim(),
                          ownerEmail: ownerEmailCtrl.text.trim().toLowerCase(),
                          ownerPassword: passCtrl.text.trim().isNotEmpty ? passCtrl.text.trim() : null,
                          status: status,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadAllData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kafe ma\'lumotlari muvaffaqiyatli saqlandi!'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setDlgState(() {
                          saving = false;
                          error = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('SAQLASH', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOGS: CHEKNI TAHRIRLASH VA LOGO BILAN CHIQARISH (RECEIPT SETTINGS)
  // ============================================================
  void _showReceiptSettingsDialog(CafeSaaSItem cafe) async {
    final nameCtrl = TextEditingController(text: cafe.receiptName.isNotEmpty ? cafe.receiptName : cafe.name);
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: cafe.ownerPhone);
    final headerCtrl = TextEditingController();
    final footerCtrl = TextEditingController(text: 'Xaridingiz uchun rahmat! Yana kutib qolamiz');
    final logoCtrl = TextEditingController();
    final servicePercentCtrl = TextEditingController(text: '0');
    bool showLogo = true;
    bool saving = false;
    String? error;

    // Load current settings from backend
    _ds.getCafeReceiptSettings(cafe.cafeId).then((data) {
      if (data != null) {
        if (data['receiptName'] != null) nameCtrl.text = data['receiptName'].toString();
        if (data['restaurantAddress'] != null) addressCtrl.text = data['restaurantAddress'].toString();
        if (data['restaurantPhone'] != null) phoneCtrl.text = data['restaurantPhone'].toString();
        if (data['receiptHeader'] != null) headerCtrl.text = data['receiptHeader'].toString();
        if (data['receiptFooter'] != null) footerCtrl.text = data['receiptFooter'].toString();
        if (data['receiptLogoUrl'] != null) logoCtrl.text = data['receiptLogoUrl'].toString();
        if (data['showLogoOnReceipt'] != null) showLogo = data['showLogoOnReceipt'] == true;
        if (data['servicePercent'] != null) servicePercentCtrl.text = data['servicePercent'].toString();
      }
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: Color(0xFFFFC107)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${cafe.name} - Chek sozlamalari',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                      child: Text(error!, style: const TextStyle(color: Color(0xFFFECACA), fontSize: 13)),
                    ),
                  // CHEK SARLAVHASI
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Chekdagi Kafe Nomi (Sarlavha) *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // MANZIL
                  TextField(
                    controller: addressCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Manzil (Chekda chiqishi uchun)',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // TELEFON
                  TextField(
                    controller: phoneCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Telefon raqam',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // LOGO URL
                  TextField(
                    controller: logoCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Chek Logosi URL / Rasm havolasi',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'https://... yoki assets/logo/logo.png',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // CHEK USTKI MATNI (HEADER)
                  TextField(
                    controller: headerCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Chek yuqorisidagi qo‘shimcha matn (Header)',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Masalan: Xush kelibsiz! WiFi: CafePass123',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // CHEK PASTKI MATNI (FOOTER)
                  TextField(
                    controller: footerCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Chek pastidagi matn (Footer)',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Masalan: Xaridingiz uchun rahmat!',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // XIZMAT HAQI FOIZI (%)
                  TextField(
                    controller: servicePercentCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Xizmat haqi foizi (%)',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: '0 yoki 10 yoki 15',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // LOGO KO'RSATILSINMI SWITCH
                  SwitchListTile(
                    title: const Text('Chekda logoni chop etish', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Chek tepasida ZAVERO yoki maxsus kafe logosi chiqadi', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    value: showLogo,
                    activeThumbColor: const Color(0xFFFFC107),
                    onChanged: (val) => setDlgState(() => showLogo = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final rName = nameCtrl.text.trim();
                      if (rName.isEmpty) {
                        setDlgState(() => error = 'Chek sarlavhasi bo‘sh bo‘lishi mumkin emas');
                        return;
                      }
                      setDlgState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final sPercent = double.tryParse(servicePercentCtrl.text.trim()) ?? 0;
                        await _ds.updateCafeReceiptSettings(
                          cafeId: cafe.cafeId,
                          receiptName: rName,
                          restaurantAddress: addressCtrl.text.trim(),
                          restaurantPhone: phoneCtrl.text.trim(),
                          receiptHeader: headerCtrl.text.trim(),
                          receiptFooter: footerCtrl.text.trim(),
                          receiptLogoUrl: logoCtrl.text.trim(),
                          showLogoOnReceipt: showLogo,
                          servicePercent: sPercent,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadAllData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chek sozlamalari muvaffaqiyatli saqlandi!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        setDlgState(() {
                          saving = false;
                          error = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                  : const Text('SAQLASH', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QUICK UNBLOCK: 150,000 SO'M TO'LOV BILAN BLOKDAN CHIQARISH (+30 KUN)
  // ============================================================
  void _quickUnblock150k(CafeSaaSItem cafe) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.monetization_on_rounded, color: Color(0xFFFFC107), size: 28),
            SizedBox(width: 10),
            Text('150 000 so‘m to‘lov & Blokdan chiqarish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Haqiqatan ham "${cafe.name}" kafesidan 150 000 so‘m oylik obuna to‘lovi qabul qilindimi?\n\nKafening holati "Faol" ga o‘zgartiriladi va obunasi 30 kunga uzaytiriladi.',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _ds.unblockAndExtendSubscription(cafe.cafeId, days: 30);
                _loadAllData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${cafe.name}" kafesi 150 000 so‘m to‘lov tasdiqlanib, 30 kunga uzaytirildi va blokdan chiqarildi!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('TASDIQLASH VA OCHISH (+30 KUN)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIALOGS: DELETE CAFE CONFIRMATION (O'CHIRISH)
  // ============================================================
  void _showDeleteConfirmDialog(CafeSaaSItem cafe) {
    bool deleting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 10),
              Text('Kafeni o\'chirish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Haqiqatan ham "${cafe.name}" kafesini o\'chirishni xohlaysizmi?\n\nUshbu kafega tegishli barcha zallar, stollar, menyu, buyurtmalar va hisobotlar ma\'lumotlar bazasidan to\'liq o\'chiriladi.',
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: deleting ? null : () => Navigator.pop(ctx),
              child: const Text('BEKOR QILISH', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: deleting
                  ? null
                  : () async {
                      setDlgState(() => deleting = true);
                      try {
                        await _ds.deleteCafe(cafe.cafeId);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadAllData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('"${cafe.name}" kafesi muvaffaqiyatli o\'chirildi!'), backgroundColor: Colors.redAccent),
                        );
                      } catch (e) {
                        setDlgState(() => deleting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
              child: deleting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('O\'CHIRISH', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOG: SUPPORT TICKETS (Murojaatlar va Muammolar)
  // ============================================================
  void _showSupportTicketsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFFFFC107)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Kelib tushgan murojaatlar va muammolar',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: () async {
                    await _loadSupportTickets();
                    setDlgState(() {});
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              height: 480,
              child: _supportTickets.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 56, color: Colors.greenAccent),
                          SizedBox(height: 12),
                          Text(
                            'Hech qanday muammo yo\'q.\nBarcha cafelar normal ishlamoqda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _supportTickets.length,
                      itemBuilder: (context, i) {
                        final t = _supportTickets[i];
                        final status = t['status']?.toString() ?? 'pending';
                        final isPending = status == 'pending';
                        final isInProgress = status == 'in_progress';
                        final isResolved = status == 'resolved';

                        Color statusColor = Colors.amber;
                        String statusLabel = 'Yangi murojaat (Kutilmoqda)';
                        if (isInProgress) {
                          statusColor = Colors.orangeAccent;
                          statusLabel = 'Tuzatilmoqda (Kafe to\'xtatilgan)';
                        } else if (isResolved) {
                          statusColor = Colors.greenAccent;
                          statusLabel = 'Hal qilingan';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    t['created_at']?.toString().substring(0, 16).replaceAll('T', ' ') ?? '',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${t['cafe_name'] ?? t['cafe_id']} — ${t['title'] ?? "Muammo xabari"}',
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t['description'] ?? '',
                                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                              ),
                              if (t['phone'] != null && t['phone'].toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('Tel: ${t['phone']} (Yuboruvchi: ${t['user_name'] ?? "Xodim"})', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (isPending)
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orangeAccent.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.build_rounded, size: 16),
                                      label: const Text('Muammoni tuzatish (Ilovani to\'xtatish)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () async {
                                        try {
                                          await _ds.startFixTicket(t['id']);
                                          await _loadSupportTickets();
                                          setDlgState(() {});
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Kafe ilovasi vaqtincha to\'xtatildi va tuzatish holatiga o\'tkazildi.'), backgroundColor: Colors.orange),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red));
                                          }
                                        }
                                      },
                                    ),
                                  if (isInProgress)
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.check_circle, size: 16),
                                      label: const Text('Muammo hal qilindi (Ishga tushirish)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () async {
                                        try {
                                          await _ds.resolveTicket(t['id']);
                                          await _loadSupportTickets();
                                          setDlgState(() {});
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Muammo hal qilindi. Kafe ilovasi to\'liq qayta ishga tushirildi!'), backgroundColor: Colors.green),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red));
                                          }
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('YOPISH', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // DIALOGS: CREATE USER (Cafe, Ishchi, Mijoz)
  // ============================================================
  void _showCreateUserDialog([String? preselectedCafeId]) {
    String? selectedCafe = preselectedCafeId ?? (_cafes.isNotEmpty ? _cafes.first.cafeId : null);
    String role = 'worker'; // worker, admin, customer
    final nameCtrl = TextEditingController();
    final surnameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool saving = false;
    String? error;

    String getExpectedDomain() {
      if (role == 'admin') return '@cafe.uz';
      if (role == 'worker') return '@ishchi.uz';
      return '@mijoz.uz';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Color(0xFFFFC107)),
              SizedBox(width: 10),
              Text('Yangi foydalanuvchi yaratish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),

                  // Cafe select
                  DropdownButtonFormField<String>(
                    initialValue: selectedCafe,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Tegishli Cafe *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _cafes.map((c) {
                      return DropdownMenuItem(
                        value: c.cafeId,
                        child: Text(c.name, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    selectedItemBuilder: (context) {
                      return _cafes.map((c) {
                        return Text(c.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold));
                      }).toList();
                    },
                    onChanged: (v) => setDlgState(() => selectedCafe = v),
                  ),
                  const SizedBox(height: 12),

                  // Role select
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Foydalanuvchi roli *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Cafe Egasi (@cafe.uz)', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'worker', child: Text('Ishchi / Kassir / Ofitsiant (@ishchi.uz)', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'customer', child: Text('Mijoz (@mijoz.uz)', style: TextStyle(color: Colors.white))),
                    ],
                    selectedItemBuilder: (context) {
                      return const [
                        Text('Cafe Egasi (@cafe.uz)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                        Text('Ishchi / Kassir / Ofitsiant (@ishchi.uz)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                        Text('Mijoz (@mijoz.uz)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      ];
                    },
                    onChanged: (v) {
                      if (v != null) {
                        setDlgState(() {
                          role = v;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Ismi *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Masalan: Ali',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: surnameCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Familiyasi',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Masalan: Valiyev',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: phoneCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Telefon',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: '+998 90 123 45 67',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Email (${getExpectedDomain()}) *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Emailni kiriting',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: passCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Parol (faqat raqam) *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Parolni kiriting',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black87,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim().toLowerCase();
                      final pass = passCtrl.text.trim();
                      final name = nameCtrl.text.trim();

                      if (selectedCafe == null || name.isEmpty || email.isEmpty || pass.isEmpty) {
                        setDlgState(() => error = 'Barcha majburiy (*) maydonlarni to\'ldiring');
                        return;
                      }

                      if (pass.length < 4) {
                        setDlgState(() => error = 'Parol kamida 4 ta raqamdan iborat bo\'lishi shart!');
                        return;
                      }

                      final expected = getExpectedDomain();
                      if (!email.endsWith(expected)) {
                        setDlgState(() => error = 'Ushbu rol uchun email $expected bilan tugashi shart!');
                        return;
                      }

                      setDlgState(() {
                        saving = true;
                        error = null;
                      });

                      try {
                        await _ds.createUser(
                          cafeId: selectedCafe!,
                          name: name,
                          surname: surnameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          role: role,
                          email: email,
                          password: pass,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadAllData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Foydalanuvchi muvaffaqiyatli yaratildi!'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setDlgState(() {
                          saving = false;
                          error = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Yaratish'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOGS: EXTEND SUBSCRIPTION (1 kun, 30, 60, 90, 120, 280, 365, Cheksiz, Ochmaydigan, Custom)
  // ============================================================
  void _showExtendDialog(CafeSaaSItem cafe) {
    int selectedDays = 30;
    final customCtrl = TextEditingController(text: '30');
    bool isCustom = false;
    bool isBlockOption = false;
    bool saving = false;

    final options = [
      {'days': 1, 'label': '1 kun', 'sub': 'Sinov / Ishlash'},
      {'days': 30, 'label': '30 kun', 'sub': '1 oy'},
      {'days': 60, 'label': '60 kun', 'sub': '2 oy'},
      {'days': 90, 'label': '90 kun', 'sub': '3 oy'},
      {'days': 120, 'label': '120 kun', 'sub': '4 oy'},
      {'days': 280, 'label': '280 kun', 'sub': '~9 oy'},
      {'days': 365, 'label': '365 kun', 'sub': '1 yil'},
      {'days': 36500, 'label': '♾️ Cheksiz', 'sub': '100 yil'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final now = DateTime.now();
          final baseDate = (cafe.endDate != null && cafe.endDate!.isAfter(now))
              ? cafe.endDate!
              : now;

          int effectiveDays = selectedDays;
          if (isCustom) {
            final parsed = int.tryParse(customCtrl.text.trim());
            effectiveDays = (parsed != null && parsed > 0) ? parsed : 30;
          }
          final previewDate = baseDate.add(Duration(days: effectiveDays));

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt, color: Color(0xFFFFC107), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cafe.name} obunasi',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Joriy tugash sanasi: ${cafe.endDate != null ? cafe.endDate!.toString().substring(0, 10) : "Muddatsiz / Ko'rsatilmagan"}',
                        style: TextStyle(
                          color: cafe.isExpired ? Colors.amber : (cafe.isBlocked ? Colors.redAccent : Colors.grey),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Muddatni tanlang:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 12),

                    // CHIPS WRAP
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...options.map((opt) {
                          final d = opt['days'] as int;
                          final isSelected = !isBlockOption && !isCustom && selectedDays == d;

                          return InkWell(
                            onTap: () {
                              setDlgState(() {
                                isBlockOption = false;
                                isCustom = false;
                                selectedDays = d;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFC107) : const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFFFD54F) : Colors.white12,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFFFC107).withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    opt['label'] as String,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black87 : Colors.white,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    opt['sub'] as String,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black54 : Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        // "🚫 Ochmaydigan" (Bloklash) chip
                        InkWell(
                          onTap: () {
                            setDlgState(() {
                              isBlockOption = true;
                              isCustom = false;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isBlockOption ? Colors.redAccent : const Color(0xFF2E1619),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isBlockOption ? Colors.red : Colors.redAccent.withValues(alpha: 0.4),
                                width: isBlockOption ? 1.8 : 1.0,
                              ),
                              boxShadow: isBlockOption
                                  ? [
                                      BoxShadow(
                                        color: Colors.redAccent.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.block,
                                  size: 15,
                                  color: isBlockOption ? Colors.white : Colors.redAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '🚫 Ochmaydigan',
                                  style: TextStyle(
                                    color: isBlockOption ? Colors.white : Colors.redAccent,
                                    fontWeight: isBlockOption ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // "✏️ Boshqa kun" chip
                        InkWell(
                          onTap: () {
                            setDlgState(() {
                              isBlockOption = false;
                              isCustom = true;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isCustom ? const Color(0xFFFFC107) : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCustom ? const Color(0xFFFFD54F) : Colors.white12,
                                width: isCustom ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_calendar,
                                  size: 15,
                                  color: isCustom ? Colors.black87 : Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Boshqa kun',
                                  style: TextStyle(
                                    color: isCustom ? Colors.black87 : Colors.white,
                                    fontWeight: isCustom ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (isCustom) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: customCtrl,
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setDlgState(() {}),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          labelText: 'Kunlar sonini kiriting',
                          labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                          hintText: 'Masalan: 45 yoki 180',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.edit, color: Colors.black54),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // PREVIEW INFO BANNER
                    if (isBlockOption)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock, color: Colors.redAccent, size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kafe ochilmaydigan holatga o\'tkaziladi',
                                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Ushbu cafe bloklanadi va barcha xodimlarning dasturga kirishi taqiqlanadi.',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.calendar_month, color: Color(0xFFFFC107), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    effectiveDays == 36500
                                        ? 'Yangi muddat: ♾️ Cheksiz (100 yil)'
                                        : (effectiveDays == 1
                                            ? 'Yangi tugash sanasi: ${previewDate.toString().substring(0, 10)} (1 kun ishlash)'
                                            : 'Yangi tugash sanasi: ${previewDate.toString().substring(0, 10)} (+$effectiveDays kun)'),
                                    style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    effectiveDays == 1
                                        ? 'Kafe 1 kun davomida to\'liq ishlay oladi (sinov muddati).'
                                        : (effectiveDays == 36500
                                            ? 'Kafega 100 yillik cheksiz xizmat huquqi beriladi.'
                                            : 'Obuna uzaytiriladi va kafe faol holatga keltiriladi.'),
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey)),
              ),
              if (isBlockOption)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          setDlgState(() => saving = true);
                          try {
                            await _ds.blockCafe(cafe.cafeId, reason: 'Director tomonidan ochilmaydigan qilindi');
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _loadAllData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Kafe muvaffaqiyatli bloklandi (ochilmaydi)!'), backgroundColor: Colors.redAccent),
                            );
                          } catch (e) {
                            setDlgState(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  icon: saving ? const SizedBox.shrink() : const Icon(Icons.block, size: 18),
                  label: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('🚫 Ochmaydigan qilish (Bloklash)', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          int finalDays = selectedDays;
                          if (isCustom) {
                            final parsed = int.tryParse(customCtrl.text.trim());
                            if (parsed == null || parsed <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Iltimos, musbat kunlar sonini kiriting')),
                              );
                              return;
                            }
                            finalDays = parsed;
                          }

                          setDlgState(() => saving = true);
                          try {
                            final newEnd = await _ds.extendSubscription(cafe.cafeId, days: finalDays);
                            if (cafe.isBlocked) {
                              await _ds.unblockCafe(cafe.cafeId);
                            }
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _loadAllData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Obuna muvaffaqiyatli uzaytirildi! Yangi sana: ${newEnd?.substring(0, 10)}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setDlgState(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  icon: saving ? const SizedBox.shrink() : const Icon(Icons.bolt, size: 18),
                  label: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                      : Text(
                          effectiveDays == 36500
                              ? '♾️ Cheksiz qilish'
                              : (effectiveDays == 1
                                  ? '⚡ 1 kun ishlashni yoqish'
                                  : '⚡ Uzaytirish (+$effectiveDays kun)'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }



  // ============================================================
  // DIALOGS: BLOCK / UNBLOCK
  // ============================================================
  void _toggleBlock(CafeSaaSItem cafe) {
    if (cafe.isBlocked) {
      // Unblock
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('${cafe.name} ni blokdan ochish'),
          content: const Text(
            'Ushbu kafeni blokdan ochishni tasdiqlaysizmi? Kafe va uning ishchilari tizimga qayta kirish huquqiga ega bo\'ladi.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                Navigator.pop(ctx);
                await _ds.unblockCafe(cafe.cafeId);
                _loadAllData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kafe blokdan ochildi!'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Blokdan ochish', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      // Block
      final reasonCtrl = TextEditingController(text: 'To\'lov muddati kechikkanligi sababli');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('${cafe.name} ni bloklash', style: const TextStyle(color: Colors.redAccent)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Diqqat! Bloklangan kafe va uning xodimlari dasturga kira olmaydi va "Xizmat muddati to\'xtatilgan" xabari ko\'rinadi.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Bloklash sababi',
                  labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(ctx);
                await _ds.blockCafe(cafe.cafeId, reason: reasonCtrl.text.trim());
                _loadAllData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kafe muvaffaqiyatli bloklandi!'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              child: const Text('Bloklash', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  // ============================================================
  // DIALOGS: CAFE DETAILS MODAL
  // ============================================================
  void _showCafeDetailModal(CafeSaaSItem cafe) async {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: _ds.getCafeDetail(cafe.cafeId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AlertDialog(
              backgroundColor: Color(0xFF1E293B),
              content: SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          final data = snapshot.data!;
          final users = (data['users'] as List? ?? []);
          final devices = (data['devices'] as List? ?? []);
          final events = (data['events'] as List? ?? []);

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFFFC107)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${cafe.name} (${cafe.cafeId})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              height: 520,
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Xodimlar'),
                        Tab(text: 'Qurilmalar'),
                        Tab(text: 'Obuna tarixi'),
                      ],
                      labelColor: Color(0xFFFFC107),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Color(0xFFFFC107),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // 1. Staff
                          ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, i) {
                              final u = users[i] as Map;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.white12,
                                  child: Icon(
                                    u['role'] == 'admin' ? Icons.admin_panel_settings : Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  '${u['name']} (${u['role']})',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${u['email'] ?? u['username']} · ${u['phone'] ?? ""}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              );
                            },
                          ),

                          // 2. Devices
                          ListView.builder(
                            itemCount: devices.length,
                            itemBuilder: (context, i) {
                              final d = devices[i] as Map;
                              return ListTile(
                                leading: const Icon(Icons.devices, color: Colors.blueAccent),
                                title: Text(
                                  '${d['device_name']}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  'Turi: ${d['device_type']} · Oxirgi faollik: ${d['last_seen']?.toString().substring(0, 16) ?? ""}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              );
                            },
                          ),

                          // 3. Subscription History
                          ListView.builder(
                            itemCount: events.length,
                            itemBuilder: (context, i) {
                              final ev = events[i] as Map;
                              return ListTile(
                                leading: const Icon(Icons.history, color: Color(0xFFFFC107)),
                                title: Text(
                                  '${ev['event_type']?.toString().toUpperCase()}: ${ev['reason'] ?? ""}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  '${ev['created_at']?.toString().substring(0, 16) ?? ""} · ${ev['created_by'] ?? ""}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Yopish', style: TextStyle(color: Colors.grey)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // DIALOGS: CHANGE DIRECTOR CREDENTIALS (LOGIN VA PAROL)
  // ============================================================
  void _showChangeCredentialsDialog() {
    final oldLoginCtrl = TextEditingController(text: widget.directorUser.username);
    final oldPassCtrl = TextEditingController();
    final newLoginCtrl = TextEditingController(text: widget.directorUser.username);
    final newPassCtrl = TextEditingController();
    bool oldPassObscure = true;
    bool newPassObscure = true;
    bool saving = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: Color(0xFFFFC107)),
              SizedBox(width: 10),
              Text('Login va parolni o‘zgartirish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(error!, style: const TextStyle(color: Color(0xFFFECACA), fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: oldLoginCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Eski login / email',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: oldPassCtrl,
                    obscureText: oldPassObscure,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Eski parol *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Joriy parolingizni kiriting',
                      suffixIcon: IconButton(
                        icon: Icon(oldPassObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setDlgState(() => oldPassObscure = !oldPassObscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  TextField(
                    controller: newLoginCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Yangi login / email *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Yangi loginni kiriting',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: newPassObscure,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Yangi parol *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Kamida 4 ta belgi',
                      suffixIcon: IconButton(
                        icon: Icon(newPassObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setDlgState(() => newPassObscure = !newPassObscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final oldPass = oldPassCtrl.text.trim();
                      final newLogin = newLoginCtrl.text.trim();
                      final newPass = newPassCtrl.text.trim();

                      if (oldPass.isEmpty) {
                        setDlgState(() => error = 'Eski parolni kiriting');
                        return;
                      }
                      if (newLogin.isEmpty && newPass.isEmpty) {
                        setDlgState(() => error = 'Yangi login yoki yangi parolni kiriting');
                        return;
                      }
                      if (newPass.isNotEmpty && newPass.length < 4) {
                        setDlgState(() => error = 'Yangi parol kamida 4 ta belgidan iborat bo‘lishi kerak');
                        return;
                      }

                      setDlgState(() {
                        saving = true;
                        error = null;
                      });

                      try {
                        await AuthService().changeCredentials(
                          oldLogin: oldLoginCtrl.text.trim(),
                          oldPassword: oldPass,
                          newLogin: newLogin.isNotEmpty ? newLogin : null,
                          newPassword: newPass.isNotEmpty ? newPass : null,
                        );

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Login va parol muvaffaqiyatli o‘zgartirildi!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        final rawMsg = e.toString().replaceAll('Exception: ', '');
                        setDlgState(() {
                          saving = false;
                          if (rawMsg.contains('xato') || rawMsg.contains('noto') || rawMsg.contains('Parol')) {
                            error = 'Parol noto‘g‘ri';
                          } else {
                            error = rawMsg;
                          }
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                  : const Text('Saqlash', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOGS: DIRECTOR 4-DIGIT PIN SETTINGS (PIN KOD SOZLAMALARI)
  // ============================================================
  void _showDirectorPinSettingsDialog() async {
    final currentPin = await PinSecurityService().getDirectorPin();
    bool isEnabled = currentPin != null && currentPin.isNotEmpty;
    final pinCtrl = TextEditingController(text: currentPin ?? '');
    String? error;
    String? successMsg;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.dialpad_rounded, color: Color(0xFFFFC107), size: 28),
              SizedBox(width: 10),
              Text(
                'Director PIN kod sozlamalari',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? Colors.green.shade900.withValues(alpha: 0.3)
                          : Colors.amber.shade900.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isEnabled ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.amber.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isEnabled ? Icons.verified_user : Icons.gpp_maybe,
                          color: isEnabled ? Colors.greenAccent : const Color(0xFFFFC107),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEnabled ? 'Director PIN kodi faol: ••••' : 'PIN kod o‘rnatilmagan',
                                style: TextStyle(
                                  color: isEnabled ? Colors.greenAccent : const Color(0xFFFFC107),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEnabled
                                    ? 'Ilova ochilganda ushbu 4 xonali PIN orqali to‘g‘ridan-to‘g‘ri Director paneliga kiriladi.'
                                    : 'PIN kod o‘rnatilsa, har safar login/parol kiritmasdan 4 ta raqam bilan tezkor kirasiz.',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                      child: Text(error!, style: const TextStyle(color: Color(0xFFFECACA), fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],

                  if (successMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                      ),
                      child: Text(successMsg!, style: const TextStyle(color: Color(0xFFBBF7D0), fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],

                  const Text(
                    'Yangi 4 xonali PIN kodni kiriting (masalan: 1234):',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      hintText: '1234',
                      hintStyle: const TextStyle(color: Colors.white30),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFFFC107), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final val = pinCtrl.text.trim();
                      if (val.length != 4 || int.tryParse(val) == null) {
                        setDlgState(() {
                          error = 'Aynan 4 ta raqam kiriting (Masalan: 1234)';
                          successMsg = null;
                        });
                        return;
                      }
                      await PinSecurityService().saveDirectorPin(val, widget.directorUser);
                      setDlgState(() {
                        isEnabled = true;
                        error = null;
                        successMsg = 'Tabriklaymiz! Director PIN kodi muvaffaqiyatli saqlandi!';
                      });
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text('PIN kodni saqlash', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),

                  if (isEnabled) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        await PinSecurityService().removeDirectorPin();
                        setDlgState(() {
                          isEnabled = false;
                          pinCtrl.clear();
                          error = null;
                          successMsg = 'Director PIN kodi o‘chirildi va bekor qilindi.';
                        });
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('PIN kodni o‘chirish', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Yopish', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================


  // ============================================================
  // UI BUILD
  // ============================================================
  String _activeNav = 'home';

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 700 && screenWidth < 1024;
    final isMobile = screenWidth < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: isDesktop ? null : _buildDrawer(isMobile: true),
      appBar: _buildTopHeader(isDesktop: isDesktop, isMobile: isMobile),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sidebar for Desktop
          if (isDesktop) _buildSidebar(),

          // Main Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCafesAndMetricsTab(isMobile: isMobile, isTablet: isTablet),
                      _buildDevicesTab(),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // TOP HEADER BAR
  PreferredSizeWidget _buildTopHeader({required bool isDesktop, required bool isMobile}) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      titleSpacing: isMobile ? 8 : 16,
      leading: isDesktop
          ? null
          : Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF334155)),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Z! Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              'Z!',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'ZAVERO',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 17,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Director',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          // Status Pill
          if (!isMobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF10B981)),
                  SizedBox(width: 6),
                  Text(
                    'Tizim faol',
                    style: TextStyle(
                      color: Color(0xFF059669),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        // SMS / Support notification bell
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                _unresolvedTicketsCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                color: const Color(0xFF475569),
                size: 22,
              ),
              tooltip: 'Murojaatlar va xabarlar',
              onPressed: _showSupportTicketsDialog,
            ),
            if (_unresolvedTicketsCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$_unresolvedTicketsCount',
                    style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),

        // Settings gear
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Color(0xFF475569), size: 22),
          tooltip: 'Sozlamalar',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dialpad_rounded, color: Color(0xFFF59E0B)),
                      title: const Text('PIN kod sozlamalari (4 raqam)', style: TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showDirectorPinSettingsDialog();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_reset_rounded, color: Color(0xFFF59E0B)),
                      title: const Text('Login va parol almashtirish', style: TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showChangeCredentialsDialog();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.refresh_rounded, color: Color(0xFF3B82F6)),
                      title: const Text('Ma\'lumotlarni yangilash', style: TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _loadAllData();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 4),

        // Super Admin Profile Capsule (Animated, Zero-Overflow)
        PopupMenuButton<String>(
          offset: const Offset(0, 48),
          color: Colors.white,
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          onSelected: (val) {
            if (val == 'pin_security') _showDirectorPinSettingsDialog();
            if (val == 'credentials') _showChangeCredentialsDialog();
            if (val == 'refresh') _loadAllData();
            if (val == 'logout') _logout();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.directorUser.name.isNotEmpty ? widget.directorUser.name : 'ZAVERO Director',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.directorUser.email.isNotEmpty ? widget.directorUser.email : 'director@zavero.uz',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'pin_security',
              child: Row(children: [Icon(Icons.pin_rounded, size: 18, color: Color(0xFFF59E0B)), SizedBox(width: 10), Text('PIN Kod sozlamalari')]),
            ),
            const PopupMenuItem(
              value: 'credentials',
              child: Row(children: [Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFFF59E0B)), SizedBox(width: 10), Text('Login / Parol o\'zgartirish')]),
            ),
            const PopupMenuItem(
              value: 'refresh',
              child: Row(children: [Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF3B82F6)), SizedBox(width: 10), Text('Tizimni yangilash')]),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(children: [Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent), SizedBox(width: 10), Text('Chiqish', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))]),
            ),
          ],
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ],
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.directorUser.name.isNotEmpty ? widget.directorUser.name : 'ZAVERO Director',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Boshqaruvchi',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Colors.grey.shade200, height: 1),
      ),
    );
  }

  // LEFT SIDEBAR (Desktop)
  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Sidebar menu items
          _buildSidebarNavItem(
            id: 'home',
            icon: Icons.home_rounded,
            title: 'Bosh sahifa',
            onTap: () {
              setState(() {
                _activeNav = 'home';
                _currentTabIndex = 0;
                _tabController.animateTo(0);
              });
            },
          ),
          _buildSidebarNavItem(
            id: 'cafes',
            icon: Icons.store_mall_directory_rounded,
            title: 'Cafelar',
            onTap: () {
              setState(() {
                _activeNav = 'cafes';
                _currentTabIndex = 0;
                _tabController.animateTo(0);
              });
            },
          ),
          _buildSidebarNavItem(
            id: 'settings',
            icon: Icons.settings_rounded,
            title: 'Sozlamalar',
            onTap: _showDirectorPinSettingsDialog,
          ),

          const Spacer(),

          // Promo Box at bottom
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFEF3C7),
                  const Color(0xFFFDE68A).withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCD34D).withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Zavero',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF78350F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Professional cafe boshqaruv tizimi',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sizning biznesingiz bizning g\'amxo\'rligimiz!',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.amber.shade900.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(Icons.coffee_rounded, size: 36, color: Colors.amber.shade700.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required String id,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isSelected = _activeNav == id;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: isSelected ? const Color(0xFFFEF3C7) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? const Border(left: BorderSide(color: Color(0xFFF59E0B), width: 4)) : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? const Color(0xFFD97706) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF78350F) : const Color(0xFF334155),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // DRAWER (Mobile / Tablet)
  Widget _buildDrawer({required bool isMobile}) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Z!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  const Text('ZAVERO Director', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A))),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.home_rounded, color: Color(0xFFF59E0B)),
                    title: const Text('Bosh sahifa', style: TextStyle(fontWeight: FontWeight.bold)),
                    selected: _activeNav == 'home',
                    selectedTileColor: const Color(0xFFFEF3C7),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _activeNav = 'home';
                        _tabController.animateTo(0);
                      });
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.store_mall_directory_rounded, color: Color(0xFFF59E0B)),
                    title: const Text('Cafelar', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _activeNav = 'cafes';
                        _tabController.animateTo(0);
                      });
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF3B82F6)),
                    title: const Text('Yangi User qo\'shish'),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreateUserDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_business_rounded, color: Color(0xFF10B981)),
                    title: const Text('Yangi Cafe qo\'shish'),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreateCafeDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.pin_rounded, color: Color(0xFFF59E0B)),
                    title: const Text('PIN kod sozlamalari'),
                    onTap: () {
                      Navigator.pop(context);
                      _showDirectorPinSettingsDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_rounded, color: Color(0xFF64748B)),
                    title: const Text('Login va parol'),
                    onTap: () {
                      Navigator.pop(context);
                      _showChangeCredentialsDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded, color: Color(0xFF3B82F6)),
                    title: const Text('Yangilash'),
                    onTap: () {
                      Navigator.pop(context);
                      _loadAllData();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('Chiqish', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // BOTTOM TAB NAVIGATION
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFFEF3C7),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: Color(0xFFD97706),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
              }
              return TextStyle(color: Colors.grey.shade600, fontSize: 12);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Color(0xFFD97706), size: 24);
              }
              return IconThemeData(color: Colors.grey.shade600, size: 24);
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentTabIndex,
            onDestinationSelected: (idx) {
              setState(() => _currentTabIndex = idx);
              _tabController.animateTo(idx);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Cafelar va Metrikalar',
              ),
              NavigationDestination(
                icon: Icon(Icons.devices_outlined),
                selectedIcon: Icon(Icons.devices_rounded),
                label: 'Qurilmalar',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 1: CAFES & METRICS
  Widget _buildCafesAndMetricsTab({required bool isMobile, required bool isTablet}) {
    return RefreshIndicator(
      color: const Color(0xFFF59E0B),
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: isMobile ? 14 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP 4 PASTEL KPI CARDS
            _buildMetricsGrid(isMobile: isMobile, isTablet: isTablet),
            SizedBox(height: isMobile ? 16 : 22),

            // 2. SEARCH & QUICK ACTIONS BAR
            _buildSearchAndActionRow(isMobile: isMobile),
            const SizedBox(height: 14),

            // 3. STATUS FILTER CHIPS
            _buildFilterChipsRow(),
            SizedBox(height: isMobile ? 16 : 20),

            // 4. CAFES CARDS GRID
            if (_cafes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.store_mall_directory_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('Birorta ham kafe topilmadi', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossCount = constraints.maxWidth > 1150
                      ? 2
                      : (constraints.maxWidth > 800 ? 2 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: isMobile ? 385 : 340,
                    ),
                    itemCount: _cafes.length,
                    itemBuilder: (context, i) => _buildCafeCard(_cafes[i], isMobile: isMobile),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // SEARCH & ACTION ROW
  Widget _buildSearchAndActionRow({required bool isMobile}) {
    final searchField = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Cafelarni qidirish (nomi, egasi, email)...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
        onChanged: (val) {
          _searchQuery = val;
          _ds.getCafes(q: val, status: _statusFilter).then((res) {
            if (mounted) setState(() => _cafes = res);
          });
        },
      ),
    );

    final cafeBtn = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFBBF24),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _showCreateCafeDialog,
      icon: const Icon(Icons.storefront_rounded, size: 18),
      label: const Text('Yangi Cafe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
    );

    final userBtn = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF334155),
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _showCreateUserDialog(),
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Color(0xFF475569)),
      label: const Text('Yangi User', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
    );

    if (isMobile) {
      return Column(
        children: [
          searchField,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: cafeBtn),
              const SizedBox(width: 8),
              Expanded(child: userBtn),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchField),
        const SizedBox(width: 12),
        cafeBtn,
        const SizedBox(width: 8),
        userBtn,
      ],
    );
  }

  // FILTER CHIPS ROW
  Widget _buildFilterChipsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Barchasi', 'all', icon: Icons.check),
          const SizedBox(width: 8),
          _buildFilterChip('Faol cafelar', 'active', count: _metrics.activeCafes),
          const SizedBox(width: 8),
          _buildFilterChip('Bloklanganlar', 'blocked', count: _metrics.blockedCafes),
          const SizedBox(width: 8),
          _buildFilterChip('Muddati tugaganlar', 'expired', count: _metrics.expiredCafes),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String status, {int? count, IconData? icon}) {
    final isSelected = _statusFilter == status;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() => _statusFilter = status);
        _ds.getCafes(q: _searchQuery, status: status).then((res) {
          if (mounted) setState(() => _cafes = res);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFBBF24) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected && icon != null) ...[
              Icon(icon, size: 14, color: Colors.black87),
              const SizedBox(width: 5),
            ],
            Text(
              count != null ? '$label ($count)' : label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4 TOP PASTEL KPI CARDS
  Widget _buildMetricsGrid({required bool isMobile, required bool isTablet}) {
    final cards = [
      _buildMetricCard(
        title: 'Jami Cafe',
        value: '${_metrics.totalCafes} ta',
        subtitle: 'Tizimdagi barcha cafelar',
        icon: Icons.storefront_rounded,
        bgColor: const Color(0xFFEFF6FF), // Pastel Blue
        iconBgColor: const Color(0xFFDBEAFE),
        iconColor: const Color(0xFF2563EB),
        borderColor: const Color(0xFFBFDBFE),
      ),
      _buildMetricCard(
        title: 'Ulangan qurilmalar',
        value: '${_metrics.activeDevices} ta',
        subtitle: 'Faol ulangan qurilmalar',
        icon: Icons.people_alt_rounded,
        bgColor: const Color(0xFFF5F3FF), // Pastel Purple
        iconBgColor: const Color(0xFFEDE9FE),
        iconColor: const Color(0xFF7C3AED),
        borderColor: const Color(0xFFDDD6FE),
      ),
      _buildMetricCard(
        title: 'Faol Cafe',
        value: '${_metrics.activeCafes} ta',
        subtitle: 'Xizmat muddati aktiv',
        icon: Icons.check_circle_rounded,
        bgColor: const Color(0xFFF0FDF4), // Pastel Green
        iconBgColor: const Color(0xFFDCFCE7),
        iconColor: const Color(0xFF16A34A),
        borderColor: const Color(0xFFBBF7D0),
      ),
      _buildMetricCard(
        title: 'Bloklangan Cafe',
        value: '${_metrics.blockedCafes} ta',
        subtitle: 'Bloklangan yoki muddati tugagan',
        icon: Icons.block_flipped,
        bgColor: const Color(0xFFFEF2F2), // Pastel Coral
        iconBgColor: const Color(0xFFFEE2E2),
        iconColor: const Color(0xFFDC2626),
        borderColor: const Color(0xFFFECACA),
      ),
    ];

    if (isMobile) {
      // 2x2 grid for mobile
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
        children: cards,
      );
    }

    if (isTablet) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 2.3,
        children: cards,
      );
    }

    // 4 columns on Desktop
    return Row(
      children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color iconBgColor,
    required Color iconColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  // CAFE CARD
  Widget _buildCafeCard(CafeSaaSItem cafe, {required bool isMobile}) {
    Color statusBg = const Color(0xFFDCFCE7);
    Color statusText = const Color(0xFF16A34A);
    String statusLabel = 'Faol';

    if (cafe.isBlocked) {
      statusBg = const Color(0xFFFEE2E2);
      statusText = const Color(0xFFDC2626);
      statusLabel = 'Bloklangan';
    } else if (cafe.isExpired) {
      statusBg = const Color(0xFFFEF3C7);
      statusText = const Color(0xFFD97706);
      statusLabel = 'Muddati tugagan';
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cafe.isBlocked ? const Color(0xFFFECACA) : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cafe Avatar Square
              Stack(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.coffee_rounded, color: Color(0xFFFBBF24), size: 22),
                        const SizedBox(height: 2),
                        Text(
                          cafe.name.isNotEmpty ? cafe.name.split(' ').first : 'Cafe',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cafe.isBlocked ? Colors.redAccent : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Title, Status Pill, ID & Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            cafe.name,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // ID with Copy Button
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'ID: ${cafe.cafeId}',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: cafe.cafeId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ID nusxalandi!'), duration: Duration(seconds: 1)),
                            );
                          },
                          child: Icon(Icons.copy_rounded, size: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    Text(
                      'Chek: ${cafe.receiptName}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
            ],
          ),

          const SizedBox(height: 8),

          // Egasi & Email
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Egasi: ${cafe.ownerName.isNotEmpty ? cafe.ownerName : "Ko'rsatilmagan"}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  cafe.ownerEmail,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Sub-Stat 4 Mini Badges Row
          Row(
            children: [
              Expanded(child: _buildSubStatTile(Icons.people_outline_rounded, '${cafe.usersCount}', 'Xodimlar', const Color(0xFF3B82F6))),
              const SizedBox(width: 8),
              Expanded(child: _buildSubStatTile(Icons.table_restaurant_outlined, '${cafe.tablesCount}', 'Stollar', const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildSubStatTile(Icons.receipt_outlined, '${cafe.receiptsCount}', 'Cheklar', const Color(0xFF8B5CF6))),
              const SizedBox(width: 8),
              Expanded(child: _buildSubStatTile(Icons.phone_android_rounded, '${cafe.activeDevicesCount}', 'Qurilmalar', const Color(0xFFF59E0B))),
            ],
          ),

          const Spacer(),

          // Obuna tugash sanasi bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Obuna tugash sanasi:',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      cafe.endDate != null ? cafe.endDate!.toString().substring(0, 10) : 'Noma\'lum',
                      style: TextStyle(
                        color: cafe.isExpired ? Colors.redAccent : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Action Buttons Row (Horizontally scrollable to avoid overflow on phones)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Primary KIRISH button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CafeManagementScreen(
                        cafe: cafe,
                        directorUser: widget.directorUser,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 15),
                  label: const Text('KIRISH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),

                // Chek / Receipt settings button
                _buildCardIconButton(
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFF10B981),
                  bgColor: const Color(0xFFDCFCE7),
                  tooltip: 'Chek sozlamalari (Logo va matn)',
                  onTap: () => _showReceiptSettingsDialog(cafe),
                ),
                const SizedBox(width: 6),

                // Edit pencil button
                _buildCardIconButton(
                  icon: Icons.edit_outlined,
                  color: const Color(0xFF475569),
                  bgColor: const Color(0xFFF1F5F9),
                  tooltip: 'Tahrirlash',
                  onTap: () => _showEditCafeDialog(cafe),
                ),
                const SizedBox(width: 6),

                // 150K To'lov button
                _buildCardIconButton(
                  icon: Icons.monetization_on_outlined,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  tooltip: '150 000 so‘m to‘lov (+30 kun)',
                  onTap: () => _quickUnblock150k(cafe),
                ),
                const SizedBox(width: 6),

                // Extend lightning button
                _buildCardIconButton(
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFEDE9FE),
                  tooltip: 'Muddatni uzaytirish',
                  onTap: () => _showExtendDialog(cafe),
                ),
                const SizedBox(width: 6),

                // Block / Unblock button
                _buildCardIconButton(
                  icon: cafe.isBlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                  color: cafe.isBlocked ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  bgColor: cafe.isBlocked ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  tooltip: cafe.isBlocked ? 'Blokdan chiqarish' : 'Bloklash',
                  onTap: () => _toggleBlock(cafe),
                ),
                const SizedBox(width: 6),

                // Delete trash button
                _buildCardIconButton(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEE2E2),
                  tooltip: 'O\'chirish',
                  onTap: () => _showDeleteConfirmDialog(cafe),
                ),
                const SizedBox(width: 6),

                // Info button
                _buildCardIconButton(
                  icon: Icons.info_outline_rounded,
                  color: const Color(0xFF64748B),
                  bgColor: const Color(0xFFF1F5F9),
                  tooltip: 'Batafsil ma\'lumot',
                  onTap: () => _showCafeDetailModal(cafe),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubStatTile(IconData icon, String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(count, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardIconButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(7.5),
            child: Icon(icon, color: color, size: 16),
          ),
        ),
      ),
    );
  }

  // TAB 2: DEVICES
  Widget _buildDevicesTab() {
    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Ulangan qurilmalar topilmadi', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _devices.length,
      itemBuilder: (context, i) {
        final d = _devices[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFFEF3C7),
              child: Icon(
                d.deviceType == 'phone'
                    ? Icons.phone_android_rounded
                    : (d.deviceType == 'tablet' ? Icons.tablet_mac_rounded : Icons.desktop_windows_rounded),
                color: const Color(0xFFD97706),
              ),
            ),
            title: Text(d.deviceName, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Turi: ${d.deviceType} · Oxirgi faollik: ${d.lastSeen?.toString().substring(0, 16) ?? "Noma'lum"} · User: ${d.userName ?? "Noma'lum"}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: 'Qurilmani uzish',
              onPressed: () async {
                await _ds.revokeDevice(d.id);
                _loadAllData();
              },
            ),
          ),
        );
      },
    );
  }
}

