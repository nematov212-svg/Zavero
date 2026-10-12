import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/director_service.dart';
import '../services/socket_service.dart';
import '../services/supabase_realtime_service.dart';
import '../widgets/receipt_widget.dart';

class CafeManagementScreen extends StatefulWidget {
  final CafeSaaSItem cafe;
  final AppUser directorUser;

  const CafeManagementScreen({
    super.key,
    required this.cafe,
    required this.directorUser,
  });

  @override
  State<CafeManagementScreen> createState() => _CafeManagementScreenState();
}

class _CafeManagementScreenState extends State<CafeManagementScreen>
    with SingleTickerProviderStateMixin {
  final DirectorService _ds = DirectorService();
  final ApiClient _api = ApiClient();
  late TabController _tabController;
  final List<StreamSubscription> _subscriptions = [];

  bool _isLoading = true;
  Map<String, dynamic> _overviewStats = {};
  List<Product> _products = [];
  List<Category> _categories = [];
  List<Hall> _halls = [];
  List<TableModel> _tables = [];
  List<Receipt> _receipts = [];
  List<CustomerOrder> _orders = [];
  Map<String, dynamic> _settings = {};
  List<Map<String, dynamic>> _notifications = [];

  String _productSearch = '';
  int? _selectedCategoryId;
  final Set<int> _selectedProductIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _api.targetCafeId = widget.cafe.cafeId;
    _setupRealtime();
    _loadCafeData();
  }

  void _setupRealtime() {
    final cafeId = widget.cafe.cafeId;
    final socket = SocketService();
    socket.joinAdditionalRoom(cafeId);

    _subscriptions.add(socket.on(CafeSocketEvent.productsUpdated).listen((_) => _refreshProducts()));
    _subscriptions.add(socket.on(CafeSocketEvent.categoriesUpdated).listen((_) => _refreshCategories()));
    _subscriptions.add(socket.on(CafeSocketEvent.tableStatusUpdated).listen((_) => _refreshTables()));
    _subscriptions.add(socket.on(CafeSocketEvent.tableOrderUpdated).listen((_) => _refreshTables()));
    _subscriptions.add(socket.on(CafeSocketEvent.receiptAdded).listen((_) => _refreshReceipts()));
    _subscriptions.add(socket.on(CafeSocketEvent.customerOrderUpdated).listen((_) => _refreshOrders()));
    _subscriptions.add(socket.on(CafeSocketEvent.settingsUpdated).listen((_) => _refreshSettings()));

    final supa = SupabaseRealtimeService();
    supa.subscribeToCafe(cafeId);
    _subscriptions.add(supa.on(RealtimeEventType.products).listen((_) => _refreshProducts()));
    _subscriptions.add(supa.on(RealtimeEventType.categories).listen((_) => _refreshCategories()));
    _subscriptions.add(supa.on(RealtimeEventType.tables).listen((_) => _refreshTables()));
    _subscriptions.add(supa.on(RealtimeEventType.receipts).listen((_) => _refreshReceipts()));
    _subscriptions.add(supa.on(RealtimeEventType.customerOrders).listen((_) => _refreshOrders()));
  }

  Future<void> _refreshProducts() async {
    try {
      final p = await _ds.getProductsForCafe(widget.cafe.cafeId);
      if (mounted) setState(() => _products = p);
    } catch (_) {}
  }

  Future<void> _refreshCategories() async {
    try {
      final c = await _ds.getCategoriesForCafe(widget.cafe.cafeId);
      if (mounted) setState(() => _categories = c);
    } catch (_) {}
  }

  Future<void> _refreshTables() async {
    try {
      final t = await _ds.getTablesForCafe(widget.cafe.cafeId);
      if (mounted) setState(() => _tables = t);
    } catch (_) {}
  }

  Future<void> _refreshReceipts() async {
    try {
      final r = await _ds.getReceiptsForCafe(widget.cafe.cafeId);
      if (mounted) setState(() => _receipts = r);
    } catch (_) {}
  }

  Future<void> _refreshOrders() async {
    try {
      final o = await _ds.getOrdersForCafe(widget.cafe.cafeId);
      if (mounted) setState(() => _orders = o);
    } catch (_) {}
  }

  Future<void> _refreshSettings() async {
    try {
      final s = await _ds.getSettingsForCafe(widget.cafe.cafeId);
      if (mounted) setState(() => _settings = s);
    } catch (_) {}
  }


  @override
  void dispose() {
    if (_api.targetCafeId == widget.cafe.cafeId) {
      _api.targetCafeId = null;
    }
    SocketService().leaveAdditionalRoom(widget.cafe.cafeId);
    for (final s in _subscriptions) {
      s.cancel();
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCafeData() async {
    setState(() => _isLoading = true);
    final cafeId = widget.cafe.cafeId;
    try {
      final overviewFuture = _ds.getCafeOverview(cafeId);
      final productsFuture = _ds.getProductsForCafe(cafeId);
      final categoriesFuture = _ds.getCategoriesForCafe(cafeId);
      final hallsFuture = _ds.getHallsForCafe(cafeId);
      final tablesFuture = _ds.getTablesForCafe(cafeId);
      final receiptsFuture = _ds.getReceiptsForCafe(cafeId);
      final ordersFuture = _ds.getOrdersForCafe(cafeId);
      final settingsFuture = _ds.getSettingsForCafe(cafeId);
      final notifsFuture = _ds.getNotifications(cafeId);

      final results = await Future.wait([
        overviewFuture,
        productsFuture,
        categoriesFuture,
        hallsFuture,
        tablesFuture,
        receiptsFuture,
        ordersFuture,
        settingsFuture,
        notifsFuture,
      ]);

      if (!mounted) return;
      setState(() {
        final ov = results[0] as Map<String, dynamic>;
        _overviewStats = ov['stats'] is Map ? Map<String, dynamic>.from(ov['stats'] as Map) : {};
        _products = results[1] as List<Product>;
        _categories = results[2] as List<Category>;
        _halls = results[3] as List<Hall>;
        _tables = results[4] as List<TableModel>;
        _receipts = results[5] as List<Receipt>;
        _orders = results[6] as List<CustomerOrder>;
        _settings = results[7] as Map<String, dynamic>;
        _notifications = results[8] as List<Map<String, dynamic>>;
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

  String _formatMoney(num val) {
    final f = NumberFormat('#,###', 'uz_UZ');
    return '${f.format(val)} so\'m';
  }

  // ============================================================
  // PRODUCT (OVQAT) QO'SHISH VA TAHRIRLASH
  // ============================================================
  void _showProductDialog([Product? existing]) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toStringAsFixed(0) : '');
    int? catId = existing?.categoryId ?? (_categories.isNotEmpty ? _categories.first.id : null);
    bool inStock = existing != null ? existing.stock > 0 : true;
    String? imageUrl = existing?.imageUrl;
    Uint8List? pickedBytes;
    bool uploadingImage = false;
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
              Icon(isEdit ? Icons.edit : Icons.add_circle, color: const Color(0xFFFFC107)),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'Ovqatni tahrirlash' : 'Yangi ovqat qo\'shish',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

                  // Image picker / preview
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24, width: 1.5),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: pickedBytes != null
                              ? Image.memory(pickedBytes!, fit: BoxFit.cover)
                              : (imageUrl != null && imageUrl!.isNotEmpty)
                                  ? Image.network(
                                      _api.resolveImageUrl(imageUrl),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.fastfood, size: 48, color: Colors.grey),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(Icons.add_a_photo_outlined, size: 44, color: Colors.grey),
                                    ),
                        ),
                        if (uploadingImage)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black54,
                              child: const Center(
                                child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFC107),
                        side: const BorderSide(color: Color(0xFFFFC107)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: Text(imageUrl != null ? 'Rasmni almashtirish' : 'Rasm tanlash (Cloud Storage)'),
                      onPressed: uploadingImage
                          ? null
                          : () async {
                              try {
                                final picker = ImagePicker();
                                final file = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1024,
                                  maxHeight: 1024,
                                  imageQuality: 85,
                                );
                                if (file == null) return;

                                setDlgState(() => uploadingImage = true);
                                final bytes = await file.readAsBytes();
                                final uploadedUrl = await _api.uploadImage(bytes, filename: file.name);

                                setDlgState(() {
                                  uploadingImage = false;
                                  pickedBytes = bytes;
                                  if (uploadedUrl != null) {
                                    imageUrl = uploadedUrl;
                                  }
                                });

                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Rasm Cloud Storage\'ga yuklandi!'), backgroundColor: Colors.green),
                                );
                              } catch (uploadErr) {
                                setDlgState(() => uploadingImage = false);
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Rasm yuklanmadi: $uploadErr'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ovqat nomi
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Ovqat nomi *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Masalan: Katta Lavash',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Narxi
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Narxi (so\'m, faqat raqam) *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Masalan: 35000',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Kategoriya
                  DropdownButtonFormField<int>(
                    initialValue: catId,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      labelText: 'Kategoriya *',
                      labelStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _categories.map((c) {
                      return DropdownMenuItem<int>(
                        value: c.id,
                        child: Text(c.name, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (v) => setDlgState(() => catId = v),
                  ),
                  const SizedBox(height: 12),

                  // Mavjudlik switch
                  SwitchListTile(
                    title: const Text('Mavjud (Sotuvda bor)', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(inStock ? 'Mijozlar buyurtma bera oladi' : 'Hozircha tugagan', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    value: inStock,
                    activeThumbColor: const Color(0xFFFFC107),
                    onChanged: (val) => setDlgState(() => inStock = val),
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
                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0;

                      if (name.isEmpty || price <= 0 || catId == null) {
                        setDlgState(() => error = 'Barcha majburiy (*) maydonlarni to\'g\'ri to\'ldiring!');
                        return;
                      }

                      setDlgState(() => saving = true);
                      try {
                        await _ds.saveProductForCafe(widget.cafe.cafeId, {
                          if (isEdit) 'id': existing.id,
                          'name': name,
                          'price': price,
                          'categoryId': catId,
                          'stock': inStock ? 100 : 0,
                          'iconCodePoint': existing?.icon.codePoint ?? 0xf1e5,
                          'imageUrl': imageUrl,
                        });

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadCafeData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEdit ? 'Ovqat yangilandi!' : 'Yangi ovqat qo\'shildi!'),
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
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'Saqlash' : 'Qo\'shish'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProduct(Product p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Ovqatni o\'chirish', style: TextStyle(color: Colors.white)),
        content: Text('Rostdan ham "${p.name}" ovqatini o\'chirmoqchimisiz?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _ds.deleteProductForCafe(widget.cafe.cafeId, p.id);
                _selectedProductIds.remove(p.id);
                _loadCafeData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${p.name}" o\'chirildi'), backgroundColor: Colors.orange),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelectedProducts() {
    if (_selectedProductIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Tanlangan ovqatlarni o\'chirish', style: TextStyle(color: Colors.white)),
        content: Text('Tanlangan ${_selectedProductIds.length} ta ovqatni haqiqatan ham o\'chirmoqchimisiz?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final ids = _selectedProductIds.toList();
                await _ds.deleteProductsBulkForCafe(widget.cafe.cafeId, ids);
                setState(() => _selectedProductIds.clear());
                _loadCafeData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${ids.length} ta ovqat muvaffaqiyatli o\'chirildi'), backgroundColor: Colors.orange),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ZAL QO'SHISH VA TAHRIRLASH
  // ============================================================
  void _showHallDialog([Hall? existing]) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    int iconCode = existing?.icon.codePoint ?? Icons.meeting_room.codePoint;
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
              const Icon(Icons.meeting_room, color: Color(0xFFFFC107)),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'Zal nomini tahrirlash' : 'Yangi zal qo\'shish',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.red.shade900.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                    child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'Zal nomi *',
                    labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                    hintText: 'Masalan: 1-zal, VIP, Padval, Yozgi zal...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
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
                        setDlgState(() => error = 'Zal nomini kiriting');
                        return;
                      }
                      setDlgState(() => saving = true);
                      try {
                        await _ds.saveHallForCafe(widget.cafe.cafeId, {
                          if (isEdit) 'id': existing.id,
                          'name': name,
                          'iconCodePoint': iconCode,
                        });
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadCafeData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEdit ? 'Zal yangilandi!' : 'Yangi zal qo\'shildi!'),
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
              child: Text(isEdit ? 'Saqlash' : 'Qo\'shish'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteHall(Hall h) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Zalni o\'chirish', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
          'Rostdan ham "${h.name}" zalini o\'chirmoqchimisiz? Ushbu zaldagi barcha stollar ham o\'chiriladi!',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _ds.deleteHallForCafe(widget.cafe.cafeId, h.id);
                _loadCafeData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${h.name}" zali o\'chirildi'), backgroundColor: Colors.orange),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STOL QO'SHISH VA TAHRIRLASH
  // ============================================================
  void _showAddTableDialog({int? initialHallId, TableModel? existing}) {
    final isEdit = existing != null;
    final numCtrl = TextEditingController(text: existing != null ? '${existing.number}' : '');
    int seats = existing?.seats ?? 4;
    int? hallId = existing?.hallId ?? initialHallId ?? (_halls.isNotEmpty ? _halls.first.id : null);
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
              const Icon(Icons.table_restaurant, color: Color(0xFFFFC107)),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'Stolni tahrirlash (№ ${existing.number})' : 'Yangi stol qo\'shish',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.red.shade900.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                    child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                DropdownButtonFormField<int>(
                  initialValue: hallId,
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    labelText: 'Zal / Hudud *',
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _halls.map((h) => DropdownMenuItem(value: h.id, child: Text(h.name))).toList(),
                  onChanged: (v) => setDlgState(() => hallId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'Stol raqami *',
                    labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                    hintText: 'Masalan: 15',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('O\'rindiqlar soni:', style: TextStyle(color: Colors.white)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFFFC107)),
                      onPressed: () => setDlgState(() {
                        if (seats > 1) seats--;
                      }),
                    ),
                    Text('$seats', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFFC107)),
                      onPressed: () => setDlgState(() => seats++),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black87),
              onPressed: saving
                  ? null
                  : () async {
                      final n = int.tryParse(numCtrl.text.trim());
                      if (n == null || hallId == null) {
                        setDlgState(() => error = 'Stol raqami va zalni tanlang');
                        return;
                      }
                      setDlgState(() => saving = true);
                      try {
                        if (isEdit) {
                          await _ds.updateTableForCafe(widget.cafe.cafeId, existing.id, {
                            'hallId': hallId,
                            'number': n,
                            'seats': seats,
                          });
                        } else {
                          await _ds.saveTableForCafe(widget.cafe.cafeId, {
                            'hallId': hallId,
                            'number': n,
                            'seats': seats,
                            'status': 'free',
                          });
                        }
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadCafeData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdit ? 'Stol yangilandi!' : 'Yangi stol qo\'shildi!'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setDlgState(() {
                          saving = false;
                          error = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: Text(isEdit ? 'Saqlash' : 'Qo\'shish'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // OGOHLANTIRISH (NOTIFICATION) YUBORISH
  // ============================================================
  void _showSendNotificationDialog() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String priority = 'urgent'; // urgent, normal, info
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
              Icon(Icons.campaign, color: Color(0xFFFFC107)),
              SizedBox(width: 10),
              Text('Cafe egasiga ogohlantirish yuborish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      decoration: BoxDecoration(color: Colors.red.shade900.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                      child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Sarlavha *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Masalan: Texnik profilaktika',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: msgCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Xabar matni *',
                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      hintText: 'Masalan: Bugun soat 22:00 da serverda texnik ishlar olib boriladi.',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Muhimlik darajasi:', style: TextStyle(color: Colors.white, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('⚠️ Shoshilinch / Muhim'),
                        selected: priority == 'urgent',
                        selectedColor: Colors.redAccent,
                        backgroundColor: const Color(0xFF334155),
                        labelStyle: TextStyle(color: priority == 'urgent' ? Colors.white : Colors.white70, fontWeight: FontWeight.bold),
                        onSelected: (val) => setDlgState(() => priority = 'urgent'),
                      ),
                      ChoiceChip(
                        label: const Text('ℹ️ Ma\'lumot'),
                        selected: priority == 'info',
                        selectedColor: const Color(0xFFFFC107),
                        backgroundColor: const Color(0xFF334155),
                        labelStyle: TextStyle(color: priority == 'info' ? Colors.black87 : Colors.white70, fontWeight: FontWeight.bold),
                        onSelected: (val) => setDlgState(() => priority = 'info'),
                      ),
                      ChoiceChip(
                        label: const Text('Oddiy'),
                        selected: priority == 'normal',
                        selectedColor: Colors.blueAccent,
                        backgroundColor: const Color(0xFF334155),
                        labelStyle: TextStyle(color: priority == 'normal' ? Colors.white : Colors.white70, fontWeight: FontWeight.bold),
                        onSelected: (val) => setDlgState(() => priority = 'normal'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black87),
              onPressed: saving
                  ? null
                  : () async {
                      final t = titleCtrl.text.trim();
                      final m = msgCtrl.text.trim();
                      if (t.isEmpty || m.isEmpty) {
                        setDlgState(() => error = 'Sarlavha va xabar matnini kiriting');
                        return;
                      }
                      setDlgState(() => saving = true);
                      try {
                        await _ds.sendNotification(
                          cafeId: widget.cafe.cafeId,
                          title: t,
                          message: m,
                          priority: priority,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadCafeData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ogohlantirish yuborildi! Cafe ilovalarida paydo bo\'ladi.'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setDlgState(() {
                          saving = false;
                          error = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: const Text('Yuborish'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD SCREEN
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFFC107)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.cafe.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.cafe.isBlocked ? Colors.red.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.cafe.status.toUpperCase(),
                    style: TextStyle(
                      color: widget.cafe.isBlocked ? Colors.redAccent : Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'ID: ${widget.cafe.cafeId} • Egasi: ${widget.cafe.ownerName.isNotEmpty ? widget.cafe.ownerName : widget.cafe.ownerEmail}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Yangilash',
            onPressed: _loadCafeData,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFFFFC107),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFFC107),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Dashboard'),
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Ovqatlar'),
            Tab(icon: Icon(Icons.category_outlined), text: 'Menu'),
            Tab(icon: Icon(Icons.table_restaurant), text: 'Stollar'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Buyurtmalar'),
            Tab(icon: Icon(Icons.payments_outlined), text: 'To\'lovlar'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Sozlamalar'),
            Tab(icon: Icon(Icons.notifications_active_outlined), text: 'Ogohlantirishlar'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFC107)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildProductsTab(),
                _buildCategoriesTab(),
                _buildTablesTab(),
                _buildOrdersTab(),
                _buildReceiptsTab(),
                _buildSettingsTab(),
                _buildNotificationsTab(),
              ],
            ),
    );
  }

  // 1. DASHBOARD TAB
  Widget _buildDashboardTab() {
    final todayRev = _overviewStats['todayRevenue'] ?? 0;
    final totalRev = _overviewStats['totalRevenue'] ?? 0;
    final todayReceipts = _overviewStats['todayReceiptsCount'] ?? 0;
    final busyTables = _overviewStats['busyTablesCount'] ?? 0;
    final tablesCount = _overviewStats['tablesCount'] ?? _tables.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildMetricBox('Bugungi Tushum', _formatMoney(todayRev), Icons.monetization_on, Colors.green),
              _buildMetricBox('Jami Tushum', _formatMoney(totalRev), Icons.account_balance_wallet, Colors.amber),
              _buildMetricBox('Bugungi Cheklar', '$todayReceipts ta', Icons.receipt, Colors.cyan),
              _buildMetricBox('Band Stollar', '$busyTables / $tablesCount', Icons.table_bar, Colors.orange),
              _buildMetricBox('Jami Ovqatlar', '${_products.length} ta', Icons.fastfood, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),

          // Quick actions
          const Text('Tezkor boshqaruv:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Yangi ovqat qo\'shish', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showProductDialog(),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.table_restaurant, color: Color(0xFFFFC107)),
                label: const Text('Yangi stol qo\'shish'),
                onPressed: _showAddTableDialog,
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900.withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.campaign, color: Colors.amber),
                label: const Text('Xabar / Ogohlantirish yuborish'),
                onPressed: _showSendNotificationDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox(String title, String val, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // 2. PRODUCTS (OVQATLAR) TAB
  Widget _buildProductsTab() {
    final filtered = _products.where((p) {
      final matchesSearch = _productSearch.isEmpty || p.name.toLowerCase().contains(_productSearch.toLowerCase());
      final matchesCat = _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
      return matchesSearch && matchesCat;
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E293B),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        hintText: 'Ovqat nomini qidirish...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setState(() => _productSearch = v.trim()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Ovqat qo\'shish', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _showProductDialog(),
                  ),
                ],
              ),
              if (_selectedProductIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedProductIds.length} ta ovqat tanlandi',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all, size: 18, color: Colors.grey),
                        label: const Text('Bekor qilish', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        onPressed: () => setState(() => _selectedProductIds.clear()),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: Text('O\'chirish (${_selectedProductIds.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: _confirmDeleteSelectedProducts,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Category filter pills
        if (_categories.isNotEmpty)
          Container(
            height: 48,
            color: const Color(0xFF1E293B),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Barchasi'),
                    selected: _selectedCategoryId == null,
                    selectedColor: const Color(0xFFFFC107),
                    backgroundColor: const Color(0xFF334155),
                    labelStyle: TextStyle(color: _selectedCategoryId == null ? Colors.black87 : Colors.white),
                    onSelected: (_) => setState(() => _selectedCategoryId = null),
                  ),
                ),
                ..._categories.map((c) {
                  final sel = _selectedCategoryId == c.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.name),
                      selected: sel,
                      selectedColor: const Color(0xFFFFC107),
                      backgroundColor: const Color(0xFF334155),
                      labelStyle: TextStyle(color: sel ? Colors.black87 : Colors.white),
                      onSelected: (_) => setState(() => _selectedCategoryId = c.id),
                    ),
                  );
                }),
              ],
            ),
          ),

        // Product list
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Ovqatlar topilmadi', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];
                    final isSelected = _selectedProductIds.contains(p.id);
                    final catName = _categories.firstWhere((c) => c.id == p.categoryId, orElse: () => Category(id: 0, name: 'Boshqa', icon: Icons.fastfood)).name;
                    return Card(
                      color: isSelected ? const Color(0xFF334155) : const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected
                            ? const BorderSide(color: Color(0xFFFFC107), width: 1.5)
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFFFFC107),
                              checkColor: Colors.black87,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedProductIds.add(p.id);
                                  } else {
                                    _selectedProductIds.remove(p.id);
                                  }
                                });
                              },
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 44,
                                height: 44,
                                color: const Color(0xFF0F172A),
                                child: (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                                    ? Image.network(
                                        _api.resolveImageUrl(p.imageUrl),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, color: Colors.grey),
                                      )
                                    : const Icon(Icons.fastfood, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                        title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('$catName • ${_formatMoney(p.price)}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: p.stock > 0 ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p.stock > 0 ? 'Mavjud' : 'Tugagan',
                                style: TextStyle(color: p.stock > 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Color(0xFFFFC107), size: 18),
                              onPressed: () => _showProductDialog(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              onPressed: () => _confirmDeleteProduct(p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // 3. MENU / CATEGORIES TAB
  Widget _buildCategoriesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Menu Kategoriyalari:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black87),
                icon: const Icon(Icons.add),
                label: const Text('Kategoriya qo\'shish'),
                onPressed: () {
                  final catCtrl = TextEditingController();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E293B),
                      title: const Text('Yangi kategoriya', style: TextStyle(color: Colors.white)),
                      content: TextField(
                        controller: catCtrl,
                        style: const TextStyle(color: Colors.black87, fontSize: 15),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          labelText: 'Kategoriya nomi',
                          labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black87),
                          onPressed: () async {
                            final name = catCtrl.text.trim();
                            if (name.isEmpty) return;
                            Navigator.pop(ctx);
                            await _ds.saveCategoryForCafe(widget.cafe.cafeId, {
                              'name': name,
                              'iconCodePoint': Icons.restaurant_menu.codePoint,
                            });
                            _loadCafeData();
                          },
                          child: const Text('Qo\'shish'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._categories.map((c) {
            final count = _products.where((p) => p.categoryId == c.id).length;
            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.folder, color: Color(0xFFFFC107)),
                title: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('$count ta ovqat biriktirilgan', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    await _ds.deleteCategoryForCafe(widget.cafe.cafeId, c.id);
                    _loadCafeData();
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // 4. TABLES TAB
  Widget _buildTablesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Stollar va Zallar boshqaruvi:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 10,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.meeting_room, color: Color(0xFFFFC107)),
                    label: const Text('Zal qo\'shish'),
                    onPressed: () => _showHallDialog(),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Stol qo\'shish', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _showAddTableDialog(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_halls.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.meeting_room_outlined, color: Colors.grey, size: 48),
                    const SizedBox(height: 12),
                    const Text('Hozircha zallar mavjud emas', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Yangi zal (masalan: 1-zal, VIP, Padval) qo\'shing', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black87),
                      icon: const Icon(Icons.add),
                      label: const Text('Zal yaratish'),
                      onPressed: () => _showHallDialog(),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._halls.map((h) {
              final hallTables = _tables.where((t) => t.hallId == h.id).toList();
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.meeting_room, color: Color(0xFFFFC107), size: 22),
                        const SizedBox(width: 8),
                        Text(h.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${hallTables.length} ta stol', style: const TextStyle(color: Color(0xFFFFC107), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFFC107), size: 20),
                          tooltip: '${h.name} ga stol qo\'shish',
                          onPressed: () => _showAddTableDialog(initialHallId: h.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                          tooltip: 'Zal nomini tahrirlash',
                          onPressed: () => _showHallDialog(h),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          tooltip: 'Zalni o\'chirish',
                          onPressed: () => _confirmDeleteHall(h),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (hallTables.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.grey, size: 18),
                            const SizedBox(width: 8),
                            Text('Ushbu zalda hali stollar yo\'q.', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                            const Spacer(),
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Stol qo\'shish'),
                              onPressed: () => _showAddTableDialog(initialHallId: h.id),
                            ),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: hallTables.map((t) {
                          final isBusy = t.status != TableStatus.free;
                          return Container(
                            width: 105,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isBusy ? Colors.red.shade900.withValues(alpha: 0.3) : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isBusy ? Colors.redAccent : Colors.white24),
                            ),
                            child: Column(
                              children: [
                                Text('№ ${t.number}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 2),
                                Text('${t.seats} kishilik', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    InkWell(
                                      onTap: () => _showAddTableDialog(existing: t),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.edit, color: Color(0xFFFFC107), size: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () async {
                                        await _ds.deleteTableForCafe(widget.cafe.cafeId, t.id);
                                        _loadCafeData();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // 5. ORDERS TAB
  Widget _buildOrdersTab() {
    return _orders.isEmpty
        ? const Center(child: Text('Buyurtmalar mavjud emas', style: TextStyle(color: Colors.grey)))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _orders.length,
            itemBuilder: (ctx, i) {
              final o = _orders[i];
              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFFFC107)),
                  title: Text('Buyurtma #${o.id} • Stol: ${o.tableNumber ?? "-"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Status: ${o.status.name} • ${_formatMoney(o.total)} • ${o.date.toString().substring(0, 16)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              );
            },
          );
  }

  // 6. RECEIPTS (TO'LOVLAR) TAB
  Widget _buildReceiptsTab() {
    return _receipts.isEmpty
        ? const Center(child: Text('Cheklar / To\'lovlar mavjud emas', style: TextStyle(color: Colors.grey)))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _receipts.length,
            itemBuilder: (ctx, i) {
              final r = _receipts[i];
              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(r.method == PaymentMethod.card ? Icons.credit_card : Icons.payments, color: Colors.greenAccent),
                  title: Text('Chek #${r.id} • ${_formatMoney(r.total)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('To\'lov turi: ${r.method.name} • Vaqti: ${r.date.toString().substring(0, 16)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              );
            },
          );
  }

  // 7. SETTINGS & RECEIPT TAB (Chek va Kafe Sozlamalari)
  Widget _buildSettingsTab() {
    return _CafeSettingsTabContent(
      cafe: widget.cafe,
      initialSettings: _settings,
      onSave: (newSettings) async {
        await _ds.saveSettingsForCafe(widget.cafe.cafeId, newSettings);
        if (mounted) {
          setState(() {
            _settings = newSettings;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kafe va chek sozlamalari saqlandi!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );
  }

  // 8. NOTIFICATIONS TAB
  Widget _buildNotificationsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E293B),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cafe Ogohlantirishlari:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black87),
                icon: const Icon(Icons.campaign),
                label: const Text('Yangi xabar yuborish'),
                onPressed: _showSendNotificationDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _notifications.isEmpty
              ? const Center(child: Text('Hozircha ogohlantirishlar yo\'q', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (ctx, i) {
                    final n = _notifications[i];
                    final isUrgent = n['priority'] == 'urgent';
                    final isRead = n['isRead'] == true;
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isUrgent ? Colors.redAccent : Colors.white10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isUrgent ? Icons.warning_amber : Icons.info_outline,
                                  color: isUrgent ? Colors.redAccent : const Color(0xFFFFC107),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    n['title']?.toString() ?? '',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isRead ? Colors.green.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isRead ? 'O\'qilgan' : 'Yangi',
                                    style: TextStyle(color: isRead ? Colors.greenAccent : Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                                  onPressed: () async {
                                    await _ds.deleteNotification(n['id'] as int, cafeId: widget.cafe.cafeId);
                                    _loadCafeData();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(n['message']?.toString() ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 10),
                            Text(
                              'Yuborilgan vaqti: ${n['createdAt'] != null ? n['createdAt'].toString().substring(0, 16) : ""}',
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Kafe va 80mm Chek sozlamalari (jonli 1:1 preview va Logo boshqaruvi bilan)
class _CafeSettingsTabContent extends StatefulWidget {
  final CafeSaaSItem cafe;
  final Map<String, dynamic> initialSettings;
  final Future<void> Function(Map<String, dynamic> newSettings) onSave;

  const _CafeSettingsTabContent({
    required this.cafe,
    required this.initialSettings,
    required this.onSave,
  });

  @override
  State<_CafeSettingsTabContent> createState() => _CafeSettingsTabContentState();
}

class _CafeSettingsTabContentState extends State<_CafeSettingsTabContent> {
  late TextEditingController _nameCtrl;
  late TextEditingController _sloganCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addrCtrl;
  late TextEditingController _noteCtrl;
  String? _logoUrl;
  bool _qrEnabled = true;
  bool _saving = false;

  final List<ReceiptItem> _sampleItems = const [
    ReceiptItem(name: 'Mini shaurma', quantity: '1 dona', price: '25 000'),
    ReceiptItem(name: 'Coca-Cola 0.5', quantity: '2 dona', price: '12 000'),
    ReceiptItem(name: 'Kartoshka fri', quantity: '1 dona', price: '15 000'),
    ReceiptItem(name: 'Cheesecake', quantity: '1 dona', price: '18 000'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.initialSettings['restaurantName']?.toString() ??
          widget.initialSettings['receiptName']?.toString() ??
          appState.effectiveReceiptName,
    );
    _sloganCtrl = TextEditingController(
      text: widget.initialSettings['receiptSlogan']?.toString() ?? appState.receiptSlogan,
    );
    _phoneCtrl = TextEditingController(
      text: widget.initialSettings['restaurantPhone']?.toString() ?? appState.restaurantPhone,
    );
    _addrCtrl = TextEditingController(
      text: widget.initialSettings['restaurantAddress']?.toString() ?? appState.restaurantAddress,
    );
    _noteCtrl = TextEditingController(
      text: widget.initialSettings['receiptFooterNote']?.toString() ?? appState.receiptFooterNote,
    );
    _logoUrl = widget.initialSettings['appLogoUrl']?.toString() ?? appState.appLogoUrl;
    if (widget.initialSettings.containsKey('receiptQrEnabled')) {
      _qrEnabled = widget.initialSettings['receiptQrEnabled'] == true;
    } else {
      _qrEnabled = appState.receiptQrEnabled;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sloganCtrl.dispose();
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
        setState(() {
          _logoUrl = base64Str;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rasm tanlashda xatolik: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _clearLogo() {
    setState(() {
      _logoUrl = null;
    });
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    try {
      final newSettings = Map<String, dynamic>.from(widget.initialSettings);
      newSettings['restaurantName'] = _nameCtrl.text.trim();
      newSettings['receiptName'] = _nameCtrl.text.trim();
      newSettings['receiptSlogan'] = _sloganCtrl.text.trim();
      newSettings['restaurantPhone'] = _phoneCtrl.text.trim();
      newSettings['restaurantAddress'] = _addrCtrl.text.trim();
      newSettings['receiptFooterNote'] = _noteCtrl.text.trim();
      newSettings['receiptQrEnabled'] = _qrEnabled;
      if (_logoUrl != null) {
        newSettings['appLogoUrl'] = _logoUrl;
      } else {
        newSettings.remove('appLogoUrl');
      }

      appState.updateSettings(
        name: _nameCtrl.text.trim(),
        receiptName: _nameCtrl.text.trim(),
        slogan: _sloganCtrl.text.trim(),
        address: _addrCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        footerNote: _noteCtrl.text.trim(),
        logoUrl: _logoUrl,
        qrEnabled: _qrEnabled,
      );

      await widget.onSave(newSettings);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;

          final formContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kafe va Chek Sozlamalari:',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bu yerda kiritilgan barcha ma\'lumotlar va logotip 80mm thermal printer chekida avtomatik aks etadi.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // KAFE NOMI
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Restoran / Kafe nomi',
                  prefixIcon: const Icon(Icons.storefront, color: Color(0xFF1E293B)),
                  labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // SLOGAN
              TextField(
                controller: _sloganCtrl,
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Slogan / Tagline (Chek sarlavhasi ostida)',
                  hintText: 'Yaxshi ta\'m • Baxtli onlar',
                  prefixIcon: const Icon(Icons.star_outline, color: Color(0xFF1E293B)),
                  labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // LOGO TANLASH BO'LIMI
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.image_outlined, color: Color(0xFFFFC107), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Kafe Logotipi (80mm Chek uchun)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Logo preview box
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: _logoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(_logoUrl!.contains(',') ? _logoUrl!.split(',')[1] : _logoUrl!),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, color: Colors.black54),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.restaurant_menu, size: 36, color: Colors.black87),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFC107),
                                  foregroundColor: Colors.black87,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _pickLogo,
                                icon: const Icon(Icons.photo_library, size: 18),
                                label: const Text('Galereyadan tanlash'),
                              ),
                              if (_logoUrl != null) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: _clearLogo,
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  label: const Text('Logoni o\'chirish'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // TELEFON
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Telefon raqam',
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFF1E293B)),
                  labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // MANZIL
              TextField(
                controller: _addrCtrl,
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Manzil',
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFF1E293B)),
                  labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // CHEK TAGSO'ZI / FOOTER
              TextField(
                controller: _noteCtrl,
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Chek tagso\'zi (Rahmat matni)',
                  hintText: 'Bizni tanlaganingiz uchun rahmat!',
                  prefixIcon: const Icon(Icons.favorite_outline, color: Color(0xFF1E293B)),
                  labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // QR CODE SWITCH
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: SwitchListTile(
                  title: const Text('QR Kodni chekda ko\'rsatish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Skaner qilganda Zavero web sahifasiga o\'tadi', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  activeThumbColor: const Color(0xFFFFC107),
                  value: _qrEnabled,
                  onChanged: (v) => setState(() => _qrEnabled = v),
                ),
              ),
              const SizedBox(height: 24),

              // SAQLASH TUGMASI
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _saving ? null : _handleSave,
                  icon: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                      : const Icon(Icons.save),
                  label: const Text('Sozlamalarni saqlash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          );

          final previewContent = Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.remove_red_eye_outlined, color: Color(0xFFFFC107), size: 18),
                    SizedBox(width: 8),
                    Text(
                      '80mm Jonli Chek Preview',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: ReceiptWidget(
                  checkId: '000125',
                  waiter: 'Admin',
                  dateTime: DateTime.now().toIso8601String(),
                  dateOnly: '08.10.2026',
                  timeOnly: '14:32',
                  customCafeName: _nameCtrl.text,
                  customSlogan: _sloganCtrl.text,
                  customPhone: _phoneCtrl.text,
                  customAddress: _addrCtrl.text,
                  customFooter: _noteCtrl.text,
                  customLogoUrl: _logoUrl,
                  customShowQr: _qrEnabled,
                  items: _sampleItems,
                ),
              ),
            ],
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: formContent),
                const SizedBox(width: 32),
                Expanded(flex: 5, child: previewContent),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              formContent,
              const SizedBox(height: 36),
              const Divider(color: Colors.white24),
              const SizedBox(height: 20),
              previewContent,
            ],
          );
        },
      ),
    );
  }
}

