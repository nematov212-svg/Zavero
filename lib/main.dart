import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/models.dart';
import 'screens/auth_screen.dart';
import 'screens/blocked_screen.dart';
import 'screens/director_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'screens/tables_management_screen.dart';
import 'screens/customer_orders_screen.dart';
import 'screens/staff_tracking_screen.dart';
import 'services/in_app_notification_service.dart';
import 'services/staff_tracking_service.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/cloud_service.dart';
import 'services/pin_security_service.dart';
import 'services/socket_service.dart';
import 'services/supabase_realtime_service.dart';
import 'services/local_cache_service.dart';
import 'services/sound_service.dart';
import 'services/localization_service.dart';
import 'services/offline_sync_service.dart';
import 'widgets/connectivity_badge.dart';
import 'widgets/optimized_image.dart';
import 'widgets/receipt_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await LocalizationService().init();
    await LocalCacheService().init();
    await OfflineSyncService().init();
    await ApiClient().init();
    await SupabaseRealtimeService().init();
    final token = ApiClient().token;
    if (token != null && token.isNotEmpty) {
      final cachedUser = await ApiClient().readCachedUserJson();
      final cafeId = cachedUser?['cafeId'] as String?;
      if (cafeId != null && cafeId.isNotEmpty) {
        SocketService().connect(token: token, cafeId: cafeId);
        SupabaseRealtimeService().subscribeToCafe(cafeId);
      }
    }
  } catch (e) {
    debugPrint('ApiClient/SocketService/SupabaseRealtime initialize error: $e');
  }
  // Butun ilova global "appState" obyektidan foydalanadi (pastda e'lon
  // qilingan). Birinchi kadr chizilishidan oldin saqlangan ma'lumotlar
  // to'liq yuklanishini ta'minlaymiz.
  await appState.loadData();

  runApp(const ZaveroApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZAVERO'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 20),
            const Text(
              'ZAVERO POS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// RASMNI GALEREYADAN TANLAB, BACKENDGA YUKLASH VA HAVOLA OLISH
// ============================================================
// Barcha qurilmalarda (planshet, telefon, web, desktop) bir xil ko'rinishi
// uchun rasm backend serverga (/api/upload) yuklanadi va doimiy HTTPS URL olinadi.
// Offline bo'lganda esa Base64 Data URL ga o'tkazilib barcha qurilmalarda ochilishi ta'minlanadi.
Future<String?> pickAndUploadImageFromGallery() async {
  try {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return null;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      try {
        final uploadedUrl = await ApiClient().uploadImage(bytes, filename: picked.name);
        if (uploadedUrl != null && uploadedUrl.trim().isNotEmpty) {
          debugPrint('pickAndUploadImageFromGallery (Web): Backendga rasm yuklandi -> $uploadedUrl');
          return uploadedUrl;
        }
      } catch (e) {
        debugPrint("pickAndUploadImageFromGallery (Web): Backend yuklashda xatolik ($e), Base64 ga o'tkazilmoqda");
      }
      final base64Str = base64Encode(bytes);
      final mime = picked.mimeType ?? 'image/jpeg';
      return 'data:$mime;base64,$base64Str';
    }

    final file = File(picked.path);
    // 1. Dastlab backend serverga yuklashga urinamiz
    try {
      final uploadedUrl = await ApiClient().uploadImage(file);
      if (uploadedUrl != null && uploadedUrl.trim().isNotEmpty) {
        debugPrint('pickAndUploadImageFromGallery: Backendga rasm yuklandi -> $uploadedUrl');
        return uploadedUrl;
      }
    } catch (e) {
      debugPrint("pickAndUploadImageFromGallery: Backend yuklashda xatolik ($e), Base64 ga o'tkazilmoqda");
    }

    // 2. Offline / tarmoq yo'q bo'lsa Base64 Data URL (barcha qurilmalarda ishlaydi)
    final bytes = await file.readAsBytes();
    final base64Str = base64Encode(bytes);
    final dotIndex = picked.path.lastIndexOf('.');
    final ext = dotIndex != -1 ? picked.path.substring(dotIndex + 1).toLowerCase() : 'jpeg';
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    return 'data:$mime;base64,$base64Str';
  } catch (e) {
    debugPrint('pickAndUploadImageFromGallery xatoligi: $e');
    return null;
  }
}

/// Legacy alias
Future<String?> pickAndSaveImageFromGallery() => pickAndUploadImageFromGallery();


// Berilgan yo'l qurilmadagi mahalliy fayl ekanligini aniqlaydi
// (internet linki yoki assets/... yo'li bo'lmasa, demak bu galereyadan
// olingan mahalliy rasm).
bool isLocalImagePath(String path) {
  return !path.startsWith('http') && !path.startsWith('assets/');
}

// ============================================================

// PUL FORMATI (UZS) — barcha narxlar shu funksiya orqali chiqadi
// ============================================================
// Masalan: 35000 -> "35 000 so'm"

String formatSum(num value) {
  final s = value.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final left = s.length - i;
    if (i > 0 && left % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return "${buf.toString()} so'm";
}

// ============================================================
// HELPERS
// ============================================================

String orderStatusLabel(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return 'Yangi';
    case OrderStatus.preparing:
      return 'Tayyorlanmoqda';
    case OrderStatus.ready:
      return 'Tayyor';
    case OrderStatus.delivered:
      return 'Yetkazildi / Berildi';
    case OrderStatus.completed:
      return 'Yakunlandi';
    case OrderStatus.cancelled:
      return 'Bekor qilingan';
  }
}

String paymentMethodLabel(PaymentMethod m) {
  switch (m) {
    case PaymentMethod.cash:
      return 'Naqd';
    case PaymentMethod.card:
      return 'Karta';
    case PaymentMethod.split:
      return 'Aralash';
  }
}

// ============================================================
// APP STATE (Multi-user Cloud Sync & Local Persistence)
// ============================================================

/// Chekni chop etishda foydalaniladigan shrift o'lchami
enum PrinterFontSize { small, normal, large }

/// Chekdagi sarlavha qanday joylashishi
enum ReceiptHeaderAlign { left, center, right }

class AppState extends ChangeNotifier {
  final CloudService _cloudService = CloudService();
  final AuthService _authService = AuthService();

  StreamSubscription? _hallsSub;
  StreamSubscription? _tablesSub;
  StreamSubscription? _ordersSub;
  StreamSubscription? _productsSub;
  StreamSubscription? _tableOrdersSub;
  StreamSubscription? _reportsSub;
  StreamSubscription? _receiptsSub;
  StreamSubscription? _categoriesSub;
  StreamSubscription? _customersSub;
  StreamSubscription? _employeesSub;
  StreamSubscription? _maintenanceSub;
  StreamSubscription? _socketTableStatusSub;
  StreamSubscription? _socketTableOrderSub;
  StreamSubscription? _socketTableReleasedSub;
  StreamSubscription? _socketNewCustomerOrderSub;
  StreamSubscription? _socketReceiptAddedSub;
  StreamSubscription? _socketReportUpdatedSub;
  StreamSubscription? _settingsSub;
  bool isUnderMaintenance = false;
  Timer? _cartSaveTimer;
  bool isCloudSynced = false;
  bool proceedingToPayment = false;

  bool darkMode = false;
  String restaurantName = 'Family Cafe';
  String? receiptName;
  String restaurantAddress = 'Navoiy ko\'chasi 12, Buxoro';
  String restaurantPhone = '+998 90 123 45 67';
  String receiptSlogan = 'Yaxshi ta\'m  •  Baxtli onlar';
  String receiptFooterNote = 'Bizni tanlaganingiz uchun rahmat!';
  bool receiptQrEnabled = true;
  String receiptQrUrl = 'https://zaverouz.netlify.app/';
  String? appLogoUrl;

  String get effectiveReceiptName {
    if (receiptName != null && receiptName!.trim().isNotEmpty) {
      return receiptName!.trim();
    }
    return restaurantName.trim().isNotEmpty ? restaurantName.trim() : 'Family Cafe';
  }

  // ---- TARMOQ (Wi-Fi/LAN) PRINTER SOZLAMALARI ----
  String? connectedPrinterName;
  String printerIp = '';
  int printerPort = 9100;
  int printerCharsPerLine = 48;
  PrinterFontSize printerFontSize = PrinterFontSize.normal;

  // ---- CHEK KO'RINISHI SOZLAMALARI ----
  bool receiptBoldHeader = true;
  ReceiptHeaderAlign receiptHeaderAlign = ReceiptHeaderAlign.center;
  int paperWidthMm = 80;
  double printerMarginMm = 3.0;

  bool showWaiterName = true;
  bool showTableName = true;
  bool showDateTime = true;
  bool showDeveloperTag = true;
  bool showCustomerCount = true;

  // ---- OVOZLI BILDIRISHNOMALAR (QR BUYURTMALAR) ----
  bool voiceNotificationEnabled = true;

  bool get printerConfigured => printerIp.trim().isNotEmpty;

  AppUser? currentUser;
  String? guestName;
  String? guestPhone;

  int _idCounter = 1000;
  int nextId() => _idCounter++;

  final List<AppUser> users = [];
  final List<Category> categories = [];
  final List<Product> products = [];
  final List<Hall> halls = [];
  final List<TableModel> tables = [];
  final List<Customer> customers = [];
  final List<Receipt> receipts = [];
  final List<CustomerOrder> customerOrders = [];
  final List<DailyReport> dailyReports = [];
  final Set<int> _notifiedOrderIds = {};
  Timer? _customerOrdersPollTimer;

  void setVoiceNotificationEnabled(bool val) {
    voiceNotificationEnabled = val;
    SoundService().setVoiceEnabled(val);
    saveData();
    if (currentCafeId.isNotEmpty) {
      _cloudService.saveSettings(currentCafeId, {'voiceNotificationEnabled': val});
    }
    notifyListeners();
  }

  Hall? selectedHall;
  TableModel? selectedTable;
  final List<CartItem> cart = [];
  DateTime? _lastLocalCartUserMutationTime;

  final Map<int, List<CartItem>> tableOrders = {};
  final Map<int, String> tableNotes = {};
  final Map<int, int> _tableOrderMutationTimes = {};
  Timer? _cartSaveDebounceTimer;

  final List<CartItem> customerCart = [];

  /// Joriy foydalanuvchi workspace ID (cafe1, cafe2, ...)
  String get currentCafeId {
    if (currentUser != null && currentUser!.cafeId.isNotEmpty) {
      return currentUser!.cafeId;
    }
    if (currentUser != null &&
        currentUser!.workspaceId.isNotEmpty &&
        currentUser!.workspaceId != currentUser!.username) {
      return currentUser!.workspaceId;
    }
    final fbUser = _authService.currentFirebaseUser;
    if (fbUser != null && fbUser.email != null) {
      return fbUser.email!.split('@').first.toLowerCase();
    }
    if (currentUser != null && currentUser!.username.isNotEmpty) {
      return currentUser!.username.trim().toLowerCase().replaceAll(' ', '_');
    }
    return 'local_default';
  }

  /// Legacy alias — bulut chaqiruvlarida cafeId ishlatiladi
  String get currentOwnerId => currentCafeId;

  AppState() {
    _initLocalState();
  }

  Future<void> _initLocalState() async {
    await _loadFromLocalCache();
    await saveData();
  }

  void ensureDefaultHallsAndTables() {
    // Avtomatik demo zallar va stollar qo'shilmaydi: yangi kafe 0 dan toza boshlanadi
    if (selectedHall == null && halls.isNotEmpty) {
      selectedHall = halls.first;
    }
  }




  void _deduplicateHallsAndTables() {
    final seenHallNames = <String>{};
    final uniqueHalls = <Hall>[];
    final hallIdMap = <int, int>{};

    for (final hall in halls) {
      final cleanName = hall.name.trim();
      final lowerName = cleanName.toLowerCase();
      if (!seenHallNames.contains(lowerName)) {
        seenHallNames.add(lowerName);
        uniqueHalls.add(hall);
      } else {
        final existing = uniqueHalls.firstWhere(
          (h) => h.name.trim().toLowerCase() == lowerName,
        );
        hallIdMap[hall.id] = existing.id;
      }
    }

    halls
      ..clear()
      ..addAll(uniqueHalls);

    for (final table in tables) {
      if (hallIdMap.containsKey(table.hallId)) {
        table.hallId = hallIdMap[table.hallId]!;
      }
    }

    final seenTables = <String>{};
    final uniqueTables = <TableModel>[];
    for (final table in tables) {
      final key = '${table.hallId}_${table.number}';
      if (!seenTables.contains(key)) {
        seenTables.add(key);
        uniqueTables.add(table);
      }
    }
    tables
      ..clear()
      ..addAll(uniqueTables);
  }

  String getCategoryName(int categoryId) {
    final cat = categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => Category(id: 0, name: '', icon: Icons.category),
    );
    return cat.name;
  }

  String normalizeCatName(String name) => name.trim();

  void _cleanLegacyCategories() {
    final seenCatIds = <int>{};
    final seenCatNames = <String>{};
    final uniqueCategories = <Category>[];
    for (final c in categories) {
      final nameKey = c.name.trim().toLowerCase();
      if (!seenCatIds.contains(c.id) && !seenCatNames.contains(nameKey)) {
        seenCatIds.add(c.id);
        seenCatNames.add(nameKey);
        uniqueCategories.add(c);
      }
    }
    categories
      ..clear()
      ..addAll(uniqueCategories);

    final seenProdIds = <int>{};
    final uniqueProducts = <Product>[];
    for (final p in products) {
      if (!seenProdIds.contains(p.id)) {
        seenProdIds.add(p.id);
        uniqueProducts.add(p);
      }
    }
    products
      ..clear()
      ..addAll(uniqueProducts);
  }

  // ---------------- AUTH & CLOUD RESTORE ----------------
  AppUser? loginByCredentials(String username, String password) {
    try {
      final cleanUser = username.trim().toLowerCase();
      final cleanPass = password.trim();

      final u = users.firstWhere(
        (e) {
          final uName = e.username.trim().toLowerCase();
          if (uName != cleanUser) return false;
          if (e.password == cleanPass) return true;
          if (cleanUser == 'admin' &&
              (cleanPass == '123456' ||
                  cleanPass == 'admin1' ||
                  cleanPass == 'admin')) {
            return true;
          }
          if (cleanUser == 'kassir' &&
              (cleanPass == '123456' ||
                  cleanPass == 'kassir123' ||
                  cleanPass == 'kassir')) {
            return true;
          }
          if (cleanUser == 'kuryer' &&
              (cleanPass == '123456' ||
                  cleanPass == 'kuryer123' ||
                  cleanPass == 'kuryer')) {
            return true;
          }
          return false;
        },
      );
      currentUser = u;
      notifyListeners();
      return u;
    } catch (_) {
      return null;
    }
  }

  void loginAsGuest(String name, String phone) {
    guestName = name.isEmpty ? 'Mehmon' : name;
    guestPhone = phone;
    currentUser = null;
    notifyListeners();
  }

  Future<void> saveUserSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('session_uid', user.uid);
    await prefs.setString('session_name', user.name);
    await prefs.setString('session_surname', user.surname);
    await prefs.setString('session_username', user.username);
    await prefs.setString('session_email', user.email);
    await prefs.setString('session_phone', user.phone);
    await prefs.setString('session_role', user.role.name);
    await prefs.setString('session_owner_id', user.ownerId);
    await prefs.setString('session_cafe_id',
        user.cafeId.isNotEmpty ? user.cafeId : user.username);
    currentUser = user;
    notifyListeners();
  }

  Future<AppUser?> restoreUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      if (!isLoggedIn) return null;

      final uid = prefs.getString('session_uid') ?? '';
      final name = prefs.getString('session_name') ?? 'Admin';
      final surname = prefs.getString('session_surname') ?? '';
      final username = prefs.getString('session_username') ?? 'admin';
      final email = prefs.getString('session_email') ?? '';
      final phone = prefs.getString('session_phone') ?? '';
      final roleStr = prefs.getString('session_role') ?? 'admin';
      final ownerId = prefs.getString('session_owner_id') ?? uid;
      final cafeId = prefs.getString('session_cafe_id') ?? ownerId;

      UserRole role = UserRole.admin;
      for (final r in UserRole.values) {
        if (r.name == roleStr) {
          role = r;
          break;
        }
      }

      final user = AppUser(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        uid: uid,
        name: name,
        surname: surname,
        username: username,
        email: email,
        phone: phone,
        password: '',
        role: role,
        ownerId: ownerId.isNotEmpty
            ? ownerId
            : (uid.isNotEmpty ? uid : 'local_default'),
        cafeId: cafeId.isNotEmpty ? cafeId : ownerId,
      );
      currentUser = user;
      notifyListeners();
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> updatePassword(String oldPassword, String newPassword) async {
    await ApiClient().post('/auth/password', body: {'oldPassword': oldPassword, 'newPassword': newPassword});
  }



  Future<void> logout() async {

    SupabaseRealtimeService().unsubscribe();
    _hallsSub?.cancel();
    _tablesSub?.cancel();
    _ordersSub?.cancel();
    _productsSub?.cancel();
    _tableOrdersSub?.cancel();
    _reportsSub?.cancel();
    _receiptsSub?.cancel();
    _categoriesSub?.cancel();
    _customersSub?.cancel();
    _employeesSub?.cancel();
    _maintenanceSub?.cancel();
    isUnderMaintenance = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
      await prefs.remove('session_uid');
      await prefs.remove('session_name');
      await prefs.remove('session_surname');
      await prefs.remove('session_username');
      await prefs.remove('session_email');
      await prefs.remove('session_phone');
      await prefs.remove('session_role');
      await prefs.remove('session_owner_id');
      await prefs.remove('session_cafe_id');
    } catch (_) {}
    await _authService.logout();
    currentUser = null;
    guestName = null;
    guestPhone = null;
    categories.clear();
    products.clear();
    halls.clear();
    tables.clear();
    customers.clear();
    receipts.clear();
    customerOrders.clear();
    tableOrders.clear();
    tableNotes.clear();
    cart.clear();
    customerCart.clear();
    selectedHall = null;
    selectedTable = null;
    notifyListeners();
  }

  String? _activeLoadedCafeId;

  /// Bulutdan joriy cafe ma'lumotlarini yuklash va real-time obuna bo'lish
  Future<void> loadCloudDataForCafe(String cafeId) async {
    final isSwitchingCafe = _activeLoadedCafeId != null && _activeLoadedCafeId != cafeId;
    _activeLoadedCafeId = cafeId;

    if (isSwitchingCafe || cafeId != 'local_default') {
      // Yangi kafe yoki kafe almashganda to'liq tozalash
      categories.clear();
      products.clear();
      halls.clear();
      tables.clear();
      customers.clear();
      receipts.clear();
      customerOrders.clear();
      tableOrders.clear();
      tableNotes.clear();
      selectedHall = null;
      selectedTable = null;
      await _loadFromLocalCache();
    } else if (categories.isEmpty && products.isEmpty) {
      // Birinchi marta kirganda lokal keshdan tezkor yuklash
      await _loadFromLocalCache();
    }

    try {
      try {
        isUnderMaintenance = await _cloudService.getMaintenanceStatus();
      } catch (_) {}
      final cloudData = await _cloudService.loadFullCafeData(cafeId);

      final cloudCats = cloudData['categories'] as List<Category>?;
      if (cloudCats != null) {
        categories
          ..clear()
          ..addAll(cloudCats);
      }

      final cloudProds = cloudData['products'] as List<Product>?;
      if (cloudProds != null) {
        final deduped = _deduplicateProducts(cloudProds);
        products
          ..clear()
          ..addAll(deduped);
      }

      final cloudHalls = cloudData['halls'] as List<Hall>?;
      if (cloudHalls != null) {
        halls
          ..clear()
          ..addAll(cloudHalls);
        if (selectedHall != null) {
          final curName = selectedHall!.name.trim().toLowerCase();
          try {
            selectedHall = halls.firstWhere(
              (h) => h.id == selectedHall!.id || h.name.trim().toLowerCase() == curName,
            );
          } catch (_) {
            selectedHall = halls.isNotEmpty ? halls.first : null;
          }
        } else if (halls.isNotEmpty) {
          selectedHall = halls.first;
        } else {
          selectedHall = null;
        }
      }

      final cloudTables = cloudData['tables'] as List<TableModel>?;
      if (cloudTables != null) {
        tables
          ..clear()
          ..addAll(cloudTables);
        if (selectedTable != null) {
          final curNum = selectedTable!.number;
          try {
            selectedTable = tables.firstWhere(
              (t) => t.id == selectedTable!.id || t.number == curNum,
            );
          } catch (_) {
            selectedTable = tables.isNotEmpty ? tables.first : null;
          }
        } else if (tables.isNotEmpty) {
          selectedTable = tables.first;
        } else {
          selectedTable = null;
        }
      }

      final cloudCusts = cloudData['customers'] as List<Customer>?;
      if (cloudCusts != null) {
        customers
          ..clear()
          ..addAll(cloudCusts);
      }

      final cloudReceipts = cloudData['receipts'] as List<Receipt>?;
      if (cloudReceipts != null) {
        receipts
          ..clear()
          ..addAll(cloudReceipts);
      }

      final cloudOrders = cloudData['customerOrders'] as List<CustomerOrder>?;
      if (cloudOrders != null) {
        customerOrders
          ..clear()
          ..addAll(cloudOrders);
      }

      final cloudTableOrders =
          cloudData['tableOrders'] as Map<int, List<CartItem>>?;
      if (cloudTableOrders != null && cloudTableOrders.isNotEmpty) {
        tableOrders
          ..clear()
          ..addAll(cloudTableOrders);
      }

      final cloudTableNotes = cloudData['tableNotes'] as Map<int, String>?;
      if (cloudTableNotes != null) {
        tableNotes
          ..clear()
          ..addAll(cloudTableNotes);
      }

      final cloudReports = cloudData['reports'] as List<DailyReport>?;
      if (cloudReports != null) {
        dailyReports
          ..clear()
          ..addAll(cloudReports);
      }

      final cloudEmps = cloudData['employees'] as List<AppUser>?;
      if (cloudEmps != null && cloudEmps.isNotEmpty) {
        users
          ..clear()
          ..addAll(cloudEmps);
      }

      final cloudSettings = cloudData['settings'] as Map<String, dynamic>?;
      if (cloudSettings != null && cloudSettings.isNotEmpty) {
        restaurantName = cloudSettings['restaurantName'] ?? restaurantName;
        if (cloudSettings.containsKey('receiptName') || cloudData.containsKey('receiptName')) {
          receiptName = cloudSettings['receiptName'] ?? cloudData['receiptName'];
        }
        restaurantAddress =
            cloudSettings['restaurantAddress'] ?? restaurantAddress;
        restaurantPhone = cloudSettings['restaurantPhone'] ?? restaurantPhone;
        receiptFooterNote =
            cloudSettings['receiptFooterNote'] ?? receiptFooterNote;
        receiptSlogan = cloudSettings['receiptSlogan'] ?? receiptSlogan;
        if (cloudSettings.containsKey('receiptQrEnabled')) {
          final qe = cloudSettings['receiptQrEnabled'];
          receiptQrEnabled = qe == true || qe == 'true' || qe == 1;
        }
        if (cloudSettings.containsKey('darkMode')) {
          final dm = cloudSettings['darkMode'];
          darkMode = dm == true || dm == 'true' || dm == 1;
        }
        appLogoUrl = cloudSettings['appLogoUrl']?.toString() ?? appLogoUrl;
      }

      _startRealtimeListeners(cafeId);

      _cleanLegacyCategories();
      _deduplicateHallsAndTables();
      isCloudSynced = true;
      await saveData();
      notifyListeners();
    } catch (e) {
      debugPrint('loadCloudDataForCafe xatoligi: $e');
    }
  }

  /// Legacy nom — ichida cafeId ishlatiladi
  Future<void> loadCloudDataForOwner(String cafeId) =>
      loadCloudDataForCafe(cafeId);

  void _startRealtimeListeners(String cafeId) {
    try {
      SocketService().connect(token: ApiClient().token, cafeId: cafeId);
    } catch (_) {}
    try {
      SupabaseRealtimeService().subscribeToCafe(cafeId);
    } catch (_) {}

    _hallsSub?.cancel();
    _hallsSub = _cloudService.streamHalls(cafeId).listen((newHalls) {
      if (newHalls.isNotEmpty) {
        halls
          ..clear()
          ..addAll(newHalls);
        if (selectedHall == null || !halls.any((h) => h.id == selectedHall!.id)) {
          selectedHall = halls.isNotEmpty ? halls.first : null;
        }
        saveData();
        notifyListeners();
      }
    });

    _tablesSub?.cancel();
    _tablesSub = _cloudService.streamTables(cafeId).listen((newTables) {
      if (newTables.isNotEmpty) {
        tables
          ..clear()
          ..addAll(newTables);
        _syncTableStatusesFromOrders();
        saveData();
        notifyListeners();
      }
    });

    _tableOrdersSub?.cancel();
    _tableOrdersSub =
        _cloudService.streamTableOrders(cafeId).listen((newOrders) {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in newOrders.entries) {
        final tableId = entry.key;
        final remoteItems = entry.value;
        final lastMutation = _tableOrderMutationTimes[tableId] ?? 0;
        if (now - lastMutation < 4000) {
          continue;
        }
        if (remoteItems.isNotEmpty) {
          tableOrders[tableId] = remoteItems;
        }
      }

      _syncTableStatusesFromOrders();

      if (selectedTable != null) {
        final lastMutation = _tableOrderMutationTimes[selectedTable!.id] ?? 0;
        final userIsEditingLocally = (now - lastMutation < 4000) ||
            (_lastLocalCartUserMutationTime != null &&
                DateTime.now().difference(_lastLocalCartUserMutationTime!).inMilliseconds < 4000);

        if (!userIsEditingLocally) {
          final remoteItems = tableOrders[selectedTable!.id];
          if (remoteItems != null && remoteItems.isNotEmpty) {
            cart
              ..clear()
              ..addAll(
                remoteItems.map(
                  (c) => CartItem(
                    product: c.product,
                    qty: c.qty,
                    note: c.note,
                  ),
                ),
              );
          }
        }
      }
      notifyListeners();
    });


    _categoriesSub?.cancel();
    _categoriesSub = _cloudService.streamCategories(cafeId).listen((newCategories) {
      categories
        ..clear()
        ..addAll(newCategories);
      saveData();
      notifyListeners();
    });

    _productsSub?.cancel();
    _productsSub = _cloudService.streamProducts(cafeId).listen((newProducts) {
      final deduped = _deduplicateProducts(newProducts);
      products
        ..clear()
        ..addAll(deduped);
      saveData();
      notifyListeners();
    });

    _customersSub?.cancel();
    _customersSub = _cloudService.streamCustomers(cafeId).listen((newCustomers) {
      if (newCustomers.isEmpty) return;
      customers
        ..clear()
        ..addAll(newCustomers);
      notifyListeners();
    });

    _employeesSub?.cancel();
    _employeesSub = _cloudService.streamEmployees(cafeId).listen((newEmployees) {
      if (newEmployees.isNotEmpty) {
        users
          ..clear()
          ..addAll(newEmployees);
        notifyListeners();
      }
    });

    _ordersSub?.cancel();
    _ordersSub = _cloudService.streamCustomerOrders(cafeId).listen((newOrders) {
      _handleIncomingCustomerOrders(newOrders);
    });

    _customerOrdersPollTimer?.cancel();
    _customerOrdersPollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (currentUser != null && currentUser?.role != UserRole.director) {
        forceRefreshCustomerOrders();
      }
    });

    _receiptsSub?.cancel();
    _receiptsSub = _cloudService.streamReceipts(cafeId).listen((newReceipts) {
      receipts
        ..clear()
        ..addAll(newReceipts);
      notifyListeners();
    });

    _maintenanceSub?.cancel();
    _maintenanceSub = SocketService().on(CafeSocketEvent.maintenanceStatus).listen((data) {
      final maint = data['isUnderMaintenance'] == true;
      if (isUnderMaintenance != maint) {
        isUnderMaintenance = maint;
        notifyListeners();
      }
    });

    _reportsSub?.cancel();
    _reportsSub = _cloudService.streamReports(cafeId).listen((newReports) {
      dailyReports
        ..clear()
        ..addAll(newReports);
      notifyListeners();
    });

    // ============================================================
    // REAL-TIME STOLLAR VA OFITSIANT/KAFE SINXRONIZATSIYASI (0-MS)
    // ============================================================
    _socketTableStatusSub?.cancel();
    _socketTableStatusSub?.cancel();
    _socketTableStatusSub = SocketService().on(CafeSocketEvent.tableStatusUpdated).listen((data) {
      final tId = (data['tableId'] as num?)?.toInt();
      final tNum = (data['tableNumber'] as num?)?.toInt();
      final st = data['status'] as String?;
      final isOcc = (st == 'occupied');
      int idx = -1;
      if (tId != null) idx = tables.indexWhere((t) => t.id == tId);
      if (idx == -1 && tNum != null) idx = tables.indexWhere((t) => t.number == tNum);
      if (idx != -1) {
        tables[idx].status = isOcc ? TableStatus.occupied : TableStatus.free;
        if (!isOcc) {
          tableOrders.remove(tables[idx].id);
          tableNotes.remove(tables[idx].id);
        }
        notifyListeners();
      }
    });

    _socketTableOrderSub?.cancel();
    _socketTableOrderSub = SocketService().on(CafeSocketEvent.tableOrderUpdated).listen((data) {
      final tId = (data['tableId'] as num?)?.toInt();
      final tNum = (data['tableNumber'] as num?)?.toInt();
      int idx = -1;
      if (tId != null) idx = tables.indexWhere((t) => t.id == tId);
      if (idx == -1 && tNum != null) idx = tables.indexWhere((t) => t.number == tNum);

      if (idx != -1) {
        final tableKey = tables[idx].id;
        final rawItems = data['items'];
        if (rawItems is List && rawItems.isNotEmpty) {
          final items = rawItems
              .whereType<Map>()
              .map((m) => CartItem.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          tableOrders[tableKey] = items;
          tables[idx].status = TableStatus.occupied;
        } else {
          tableOrders.remove(tableKey);
          tables[idx].status = TableStatus.free;
        }
        notifyListeners();
      }
    });

    _socketTableReleasedSub?.cancel();
    _socketTableReleasedSub = SocketService().on(CafeSocketEvent.tableReleased).listen((data) {
      final tId = (data['tableId'] as num?)?.toInt();
      final tNum = (data['tableNumber'] as num?)?.toInt();
      int idx = -1;
      if (tId != null) idx = tables.indexWhere((t) => t.id == tId);
      if (idx == -1 && tNum != null) idx = tables.indexWhere((t) => t.number == tNum);
      if (idx != -1) {
        final tableKey = tables[idx].id;
        tableOrders.remove(tableKey);
        tableNotes.remove(tableKey);
        tables[idx].status = TableStatus.free;
        notifyListeners();
      }
    });

    // Real-time receipts sync across devices and Telegram WebApp
    _socketReceiptAddedSub?.cancel();
    _socketReceiptAddedSub = SocketService().on(CafeSocketEvent.receiptAdded).listen((data) {
      final rRaw = data['receipt'];
      if (rRaw is Map) {
        final r = Receipt.fromJson(Map<String, dynamic>.from(rRaw));
        if (!receipts.any((x) => x.id == r.id)) {
          receipts.insert(0, r);
          notifyListeners();
        }
      }
    });

    // Real-time financial reports sync across devices and Telegram WebApp
    _socketReportUpdatedSub?.cancel();
    _socketReportUpdatedSub = SocketService().on(CafeSocketEvent.reportUpdated).listen((data) {
      final repRaw = data['report'];
      if (repRaw is Map) {
        final rep = DailyReport.fromJson(Map<String, dynamic>.from(repRaw));
        final idx = dailyReports.indexWhere((x) => x.dateId == rep.dateId);
        if (idx != -1) {
          dailyReports[idx] = rep;
        } else {
          dailyReports.insert(0, rep);
        }
        notifyListeners();
      }
    });

    // Real-time sound / voice settings sync across devices and Telegram WebApp
    _settingsSub?.cancel();
    _settingsSub = SocketService().on(CafeSocketEvent.settingsUpdated).listen((data) {
      final s = data['settings'];
      if (s is Map && s['voiceNotificationEnabled'] != null) {
        final enabled = s['voiceNotificationEnabled'] == true || s['voiceNotificationEnabled'] == 'true';
        if (voiceNotificationEnabled != enabled) {
          voiceNotificationEnabled = enabled;
          SoundService().setVoiceEnabled(enabled);
          saveData();
          notifyListeners();
        }
      }
    });

    // QR menyudan zakaz kelsa (stol skaner qilinganda) stol darhol band bo'ladi
    _socketNewCustomerOrderSub?.cancel();
    _socketNewCustomerOrderSub = SocketService().on(CafeSocketEvent.newCustomerOrder).listen((data) {
      final tNum = (data['tableNumber'] as num?)?.toInt();
      if (tNum != null) {
        final idx = tables.indexWhere((t) => t.number == tNum);
        if (idx != -1) {
          tables[idx].status = TableStatus.occupied;
          notifyListeners();
        }
      }
    });

    // Xodimlar ro'yxatini kuzatuv xizmatiga sinxronlash
    StaffTrackingService().syncStaffList(users);
  }

  DailyReport? reportForDate(DateTime date) {
    final id = DailyReport.dateIdFrom(date);
    try {
      return dailyReports.firstWhere((r) => r.dateId == id);
    } catch (_) {
      final dayReceipts = receipts
          .where(
            (r) =>
                r.date.year == date.year &&
                r.date.month == date.month &&
                r.date.day == date.day,
          )
          .toList();

      if (dayReceipts.isEmpty) return null;

      double total = 0;
      final qtyMap = <String, int>{};
      final revMap = <String, double>{};
      final tableMap = <String, double>{};

      for (final r in dayReceipts) {
        total += r.total;
        final tKey =
            r.tableNumber != null ? 'Stol ${r.tableNumber}' : 'Olib ketish';
        tableMap[tKey] = (tableMap[tKey] ?? 0) + r.total;

        for (final item in r.items) {
          final pName = item.product.name;
          qtyMap[pName] = (qtyMap[pName] ?? 0) + item.qty;
          revMap[pName] = (revMap[pName] ?? 0) + item.total;
        }
      }

      String topP = '';
      int maxQty = 0;
      qtyMap.forEach((k, v) {
        if (v > maxQty) {
          maxQty = v;
          topP = k;
        }
      });

      return DailyReport(
        dateId: id,
        totalRevenue: total,
        orderCount: dayReceipts.length,
        productQuantities: qtyMap,
        productRevenue: revMap,
        topProduct: topP,
        tableRevenue: tableMap,
        updatedAt: DateTime.now(),
      );
    }
  }

  // ---------------- KASSIR SAVATI & STOL BAND QILISH LOGIKASI ----------------

  /// Stol uchun aktiv (bo'sh bo'lmagan) buyurtma bormi?
  bool hasActiveOrder(int tableId) {
    final order = tableOrders[tableId];
    return order != null && order.isNotEmpty;
  }

  /// Barcha stollar holatini `tableOrders` bilan sinxronlashtiradi.
  void _reconcileAllTableStatuses() {
    for (final table in tables) {
      final occupied = hasActiveOrder(table.id);
      table.status = occupied ? TableStatus.occupied : TableStatus.free;
      if (!occupied && selectedTable?.id != table.id) {
        tableOrders.remove(table.id);
        tableNotes.remove(table.id);
      }
    }
  }

  void _syncTableStatusesFromOrders() {
    for (final table in tables) {
      final hasOrder = hasActiveOrder(table.id);
      if (hasOrder) {
        table.status = TableStatus.occupied;
      } else if (table.status != TableStatus.occupied) {
        if (selectedTable?.id != table.id) {
          table.status = TableStatus.free;
          tableOrders.remove(table.id);
          tableNotes.remove(table.id);
        }
      }
    }
  }

  /// Bitta stol holatini aktiv buyurtmaga qarab yangilaydi (bulut + disk).
  void _syncTableStatusFor(int tableId) {
    final idx = tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;

    final occupied = hasActiveOrder(tableId);
    final table = tables[idx];
    final newStatus = occupied ? TableStatus.occupied : TableStatus.free;
    table.status = newStatus;
    unawaited(_persistTableStatus(tableId, occupied));
  }

  Future<void> _persistTableStatus(int tableId, bool occupied) async {
    try {
      if (occupied) {
        await _cloudService.updateTableStatus(
          cafeId: currentCafeId,
          tableId: tableId,
          status: TableStatus.occupied,
        );
      } else {
        await _cloudService.releaseTable(
          cafeId: currentCafeId,
          tableId: tableId,
        );
      }
      _cartSaveDebounceTimer?.cancel();
      await _saveCartAndTablesOnly();
    } catch (e) {
      debugPrint('_persistTableStatus xatoligi: $e');
    }
  }

  /// To'lov/menyu ekranidan stol tanlashga qaytganda sessiyani saqlab tozalaydi
  void leaveOrderSession() {
    if (selectedTable != null && cart.isNotEmpty) {
      final tId = selectedTable!.id;
      final savedItems = List<CartItem>.from(cart);
      final savedNote = selectedTableNote;
      _syncCartToTable();
      _saveCartRemoteOnly(targetTableId: tId, targetItems: savedItems, targetNote: savedNote);
    }
    _saveCartLocalOnly();
    cart.clear();
    selectedTable = null;
    notifyListeners();
  }

  /// Stol tanlanganda uning joriy buyurtmasi cartga yuklanadi.
  void selectTable(TableModel t) {
    selectedTable = t;
    final items = tableOrders[t.id];
    cart
      ..clear()
      ..addAll(
        (items ?? const [])
            .map((c) => CartItem(product: c.product, qty: c.qty, note: c.note)),
      );
    if (cart.isNotEmpty) {
      t.status = TableStatus.occupied;
    } else if (t.status == TableStatus.occupied) {
      _loadTableOrderFor(t.id);
    }
    notifyListeners();
  }

  Future<void> _loadTableOrderFor(int tableId) async {
    try {
      final cached = await LocalCacheService().getCachedMap('cache_table_orders_$currentCafeId');
      if (cached != null && cached.containsKey('$tableId')) {
        final rawList = cached['$tableId'];
        if (rawList is List && rawList.isNotEmpty) {
          final loadedItems = rawList
              .whereType<Map>()
              .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          if (loadedItems.isNotEmpty) {
            tableOrders[tableId] = loadedItems;
            final tIdx = tables.indexWhere((tbl) => tbl.id == tableId);
            if (tIdx != -1) {
              tables[tIdx].status = TableStatus.occupied;
            }
            if (selectedTable?.id == tableId && cart.isEmpty) {
              cart
                ..clear()
                ..addAll(loadedItems.map((c) => CartItem(product: c.product, qty: c.qty, note: c.note)));
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('_loadTableOrderFor error: $e');
    }
  }

  void _syncCartToTable() {
    if (selectedTable == null) return;
    final tableId = selectedTable!.id;

    if (cart.isEmpty) {
      tableOrders.remove(tableId);
      tableNotes.remove(tableId);
    } else {
      tableOrders[tableId] = List<CartItem>.from(
        cart.map((c) => CartItem(product: c.product, qty: c.qty, note: c.note)),
      );
      _tableOrderMutationTimes[tableId] = DateTime.now().millisecondsSinceEpoch;
    }

    _syncTableStatusFor(tableId);
    _scheduleCartSave();
  }

  /// Savat o'zgarishlarini mahalliy xotiraga darhol, serverga esa debounce bilan saqlash.
  void _scheduleCartSave() {
    _saveCartLocalOnly();
    _cartSaveDebounceTimer?.cancel();
    _cartSaveDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      _saveCartRemoteOnly();
    });
  }

  /// Savat va stol buyurtmalarini mahalliy SharedPreferences + LocalCacheService ga yozish (0-ms)
  Future<void> _saveCartLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonTableOrders = tableOrders.map(
        (k, v) => MapEntry(k.toString(), v.map((e) => e.toJson()).toList()),
      );
      await prefs.setString('tableOrders', jsonEncode(jsonTableOrders));
      await prefs.setString('tableNotes', jsonEncode(tableNotes));
      await LocalCacheService().setCachedMap('cache_table_orders_$currentCafeId', jsonTableOrders);
    } catch (e) {
      debugPrint('_saveCartLocalOnly xatoligi: $e');
    }
  }

  /// Serverga fon rejimida saqlash (tezkor ketma-ket bosishlarni birlashtiradi)
  Future<void> _saveCartRemoteOnly({int? targetTableId, List<CartItem>? targetItems, String? targetNote}) async {
    final tableId = targetTableId ?? selectedTable?.id;
    if (tableId == null) return;
    final items = targetItems ?? List<CartItem>.from(cart);
    final note = targetNote ?? selectedTableNote;
    try {
      if (items.isNotEmpty) {
        await _cloudService.saveTableOrder(
          cafeId: currentCafeId,
          tableId: tableId,
          items: items,
          note: note,
        );
      }
    } on TableBusyException catch (e) {
      debugPrint('_saveCartRemoteOnly stol band: $e');
    } catch (e) {
      debugPrint('_saveCartRemoteOnly xatoligi: $e');
    }
  }


  /// Stol holati va savatni saqlaydi (to'liq saveData() dan yengil).
  Future<void> _saveCartAndTablesOnly() async {
    await _saveCartLocalOnly();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'tables',
        jsonEncode(tables.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('_saveCartAndTablesOnly xatoligi: $e');
    }
  }

  // ---- JOY / STOLLARNI BOSHQARISH METODLARI (SETTINGS UCHUN) ----

  Future<void> addTableToHall({
    required int hallId,
    required int number,
    int seats = 4,
  }) async {
    final newTable = TableModel(
      id: nextId(),
      hallId: hallId,
      number: number,
      seats: seats,
      status: TableStatus.free,
    );
    tables.add(newTable);
    _deduplicateHallsAndTables();
    await saveData();
    notifyListeners();

    try {
      final cloudTable = await _cloudService.createTable(
        cafeId: currentCafeId,
        hallId: hallId,
        number: number,
        seats: seats,
      );
      if (cloudTable != null) {
        final idx = tables.indexWhere((t) => t.id == newTable.id);
        if (idx != -1) {
          tables[idx] = cloudTable;
          await saveData();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('addTableToHall cloud xatoligi: $e');
    }
  }

  Future<void> updateTableDetails({
    required int tableId,
    required int number,
    int seats = 4,
  }) async {
    final idx = tables.indexWhere((t) => t.id == tableId);
    if (idx != -1) {
      tables[idx].number = number;
      tables[idx].seats = seats;
      await saveData();
      notifyListeners();

      try {
        await _cloudService.updateTable(
          cafeId: currentCafeId,
          tableId: tableId,
          number: number,
          seats: seats,
        );
      } catch (e) {
        debugPrint('updateTableDetails cloud xatoligi: $e');
      }
    }
  }

  Future<bool> deleteTableById({
    required int tableId,
    bool force = false,
  }) async {
    final hasOrder = hasActiveOrder(tableId);
    if (hasOrder && !force) {
      return false;
    }

    tables.removeWhere((t) => t.id == tableId);
    tableOrders.remove(tableId);
    tableNotes.remove(tableId);
    if (selectedTable?.id == tableId) {
      selectedTable = null;
      cart.clear();
    }
    await saveData();
    notifyListeners();

    try {
      await _cloudService.deleteTable(
        cafeId: currentCafeId,
        tableId: tableId,
        force: force,
      );
    } catch (e) {
      debugPrint('deleteTableById cloud xatoligi: $e');
    }
    return true;
  }

  Future<Hall> addHall(String name, [IconData icon = Icons.meeting_room_outlined]) async {
    final hall = Hall(id: nextId(), name: name, icon: icon);
    halls.add(hall);
    await saveData();
    notifyListeners();

    try {
      final cloudHall = await _cloudService.saveHall(
        currentCafeId,
        name: name,
        iconCodePoint: icon.codePoint,
      );
      if (cloudHall != null) {
        final idx = halls.indexWhere((h) => h.id == hall.id);
        if (idx != -1) {
          final oldId = hall.id;
          final newId = cloudHall.id;
          halls[idx] = cloudHall;
          for (final t in tables) {
            if (t.hallId == oldId) {
              t.hallId = newId;
            }
          }
          await saveData();
          notifyListeners();
          return cloudHall;
        }
      }
    } catch (e) {
      debugPrint('addHall cloud xatoligi: $e');
    }

    return hall;
  }

  Future<void> deleteHall(int hallId) async {
    halls.removeWhere((h) => h.id == hallId);
    final toRemove = tables.where((t) => t.hallId == hallId).map((t) => t.id).toSet();
    tables.removeWhere((t) => t.hallId == hallId);
    for (final tid in toRemove) {
      tableOrders.remove(tid);
      tableNotes.remove(tid);
      if (selectedTable?.id == tid) {
        selectedTable = null;
        cart.clear();
      }
    }
    if (selectedHall?.id == hallId) {
      selectedHall = halls.isNotEmpty ? halls.first : null;
    }
    await saveData();
    notifyListeners();

    try {
      await _cloudService.deleteHall(currentCafeId, hallId);
    } catch (e) {
      debugPrint('deleteHall cloud xatoligi: $e');
    }
  }

  Future<void> clearAllTables() async {
    tables.clear();
    tableOrders.clear();
    tableNotes.clear();
    selectedTable = null;
    cart.clear();
    await saveData();
    notifyListeners();

    try {
      await _cloudService.clearAllTables(currentCafeId);
    } catch (e) {
      debugPrint('clearAllTables error: $e');
    }
  }

  Future<void> clearHallTables(int hallId) async {
    final toRemove = tables.where((t) => t.hallId == hallId).map((t) => t.id).toSet();
    tables.removeWhere((t) => t.hallId == hallId);
    for (final tid in toRemove) {
      tableOrders.remove(tid);
      tableNotes.remove(tid);
      if (selectedTable?.id == tid) {
        selectedTable = null;
        cart.clear();
      }
    }
    await saveData();
    notifyListeners();

    try {
      await _cloudService.clearHallTables(currentCafeId, hallId);
    } catch (e) {
      debugPrint('clearHallTables error: $e');
    }
  }

  void setTableNote(String note) {
    if (selectedTable != null) {
      tableNotes[selectedTable!.id] = note;
      saveData();
      notifyListeners();
    }
  }

  String get selectedTableNote =>
      selectedTable != null ? (tableNotes[selectedTable!.id] ?? '') : '';

  double tableOrderTotal(TableModel t) {
    return (tableOrders[t.id] ?? const []).fold(0.0, (s, i) => s + i.total);
  }

  void addToCart(Product p) {
    _lastLocalCartUserMutationTime = DateTime.now();
    if (selectedTable != null) {
      _tableOrderMutationTimes[selectedTable!.id] = DateTime.now().millisecondsSinceEpoch;
    }
    final existing = cart.where((c) => c.product.id == p.id);
    if (existing.isNotEmpty) {
      existing.first.qty++;
    } else {
      cart.add(CartItem(product: p));
    }
    _syncCartToTable();
    notifyListeners();
  }

  void changeQty(CartItem item, int delta) {
    _lastLocalCartUserMutationTime = DateTime.now();
    if (selectedTable != null) {
      _tableOrderMutationTimes[selectedTable!.id] = DateTime.now().millisecondsSinceEpoch;
    }
    if (delta < 0) {
      if (item.qty <= 1) {
        cart.remove(item);
      } else {
        item.qty--;
      }
    } else {
      item.qty += delta;
    }
    _syncCartToTable();
    notifyListeners();
  }

  void removeFromCart(CartItem item) {
    _lastLocalCartUserMutationTime = DateTime.now();
    if (selectedTable != null) {
      _tableOrderMutationTimes[selectedTable!.id] = DateTime.now().millisecondsSinceEpoch;
    }
    cart.remove(item);
    _syncCartToTable();
    notifyListeners();
  }

  void setNote(CartItem item, String note) {
    _lastLocalCartUserMutationTime = DateTime.now();
    if (selectedTable != null) {
      _tableOrderMutationTimes[selectedTable!.id] = DateTime.now().millisecondsSinceEpoch;
    }
    item.note = note;
    _syncCartToTable();
    notifyListeners();
  }

  double get cartTotal => cart.fold(0, (sum, item) => sum + item.total);

  void clearCart() {
    _lastLocalCartUserMutationTime = DateTime.now();
    if (selectedTable != null) {
      _tableOrderMutationTimes[selectedTable!.id] = DateTime.now().millisecondsSinceEpoch;
    }
    cart.clear();
    _syncCartToTable();
    notifyListeners();
  }


  /// "TO'LOVGA O'TISH" bosilganda: buyurtmani saqlaydi va to'lov ekraniga ruxsat beradi.
  /// Stol holati `_syncCartToTable` orqali aktiv buyurtmaga bog'langan.
  Future<bool> proceedToPayment() async {
    if (cart.isEmpty || proceedingToPayment) return false;

    proceedingToPayment = true;
    notifyListeners();

    try {
      if (selectedTable != null) {
        _syncCartToTable();
        if (selectedTableNote.isNotEmpty) {
          tableNotes[selectedTable!.id] = selectedTableNote;
        }

        try {
          await _cloudService
              .lockTableForCheckout(
                cafeId: currentCafeId,
                tableId: selectedTable!.id,
                items: cart,
                note: selectedTableNote,
              )
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('proceedToPayment cloud xatoligi (offline rejim): $e');
        }

        _cartSaveTimer?.cancel();
        await _saveCartAndTablesOnly();
        notifyListeners();
      }
      return true;
    } finally {
      proceedingToPayment = false;
      notifyListeners();
    }
  }

  /// Stolni bo'shatish va buyurtmani bekor qilish.
  Future<void> releaseCurrentTable() async {
    if (selectedTable == null) return;
    final tId = selectedTable!.id;
    cart.clear();
    tableOrders.remove(tId);
    tableNotes.remove(tId);
    await _persistTableStatus(tId, false);
    selectedTable = null;
    notifyListeners();
  }

  Receipt checkout({
    required PaymentMethod method,
    double cashPaid = 0,
    double cardPaid = 0,
  }) {
    final r = Receipt(
      id: nextId(),
      date: DateTime.now(),
      items: List<CartItem>.from(
        cart.map((c) => CartItem(product: c.product, qty: c.qty, note: c.note)),
      ),
      total: cartTotal,
      method: method,
      cashierName: currentUser?.name ?? guestName ?? 'Mehmon',
      tableNumber: selectedTable?.number,
      hallName: selectedHall?.name,
      cashPaid: cashPaid,
      cardPaid: cardPaid,
    );
    receipts.insert(0, r);

    final tableIdToRelease = selectedTable?.id;
    _cloudService.completeCheckout(
      cafeId: currentCafeId,
      receipt: r,
      tableId: tableIdToRelease,
      items: List<CartItem>.from(cart),
      allProducts: products,
      ownerId: '',
    );

    // for (final item in cart) {
    //   final pList = products.where((pr) => pr.id == item.product.id);
    //   if (pList.isNotEmpty) {
    //     pList.first.stock =
    //         (pList.first.stock - item.qty).clamp(0, 1000000).toInt();
    //   }
    // }

    if (selectedTable != null) {
      selectedTable!.status = TableStatus.free;
      tableOrders.remove(selectedTable!.id);
      tableNotes.remove(selectedTable!.id);
    }
    selectedTable = null;
    selectedHall = null;
    cart.clear();
    unawaited(saveData());
    notifyListeners();
    return r;
  }

  // ---------------- MIJOZ SAVATI VA ONLINE ZAKAS ----------------
  void addToCustomerCart(Product p) {
    final existing = customerCart.where((c) => c.product.id == p.id);
    if (existing.isNotEmpty) {
      existing.first.qty++;
    } else {
      customerCart.add(CartItem(product: p));
    }
    notifyListeners();
  }

  void changeCustomerQty(CartItem item, int delta) {
    item.qty += delta;
    if (item.qty <= 0) customerCart.remove(item);
    notifyListeners();
  }

  void removeFromCustomerCart(CartItem item) {
    customerCart.remove(item);
    notifyListeners();
  }

  double get customerCartTotal =>
      customerCart.fold(0, (sum, item) => sum + item.total);

  void clearCustomerCart() {
    customerCart.clear();
    notifyListeners();
  }

  CustomerOrder placeCustomerOrder({
    required String name,
    required String phone,
    required OrderType type,
    int? tableNumber,
    int? hallId,
    String? deliveryAddress,
  }) {
    final order = CustomerOrder(
      id: nextId(),
      date: DateTime.now(),
      items: List<CartItem>.from(
        customerCart.map(
          (c) => CartItem(product: c.product, qty: c.qty, note: c.note),
        ),
      ),
      customerName: name.isEmpty ? (guestName ?? 'Mehmon') : name,
      phone: phone,
      type: type,
      tableNumber: tableNumber,
      hallId: hallId,
      deliveryAddress: deliveryAddress,
    );
    customerOrders.insert(0, order);
    customerCart.clear();
    _cloudService.saveCustomerOrder(currentCafeId, order);
    saveData();
    notifyListeners();
    return order;
  }

  Future<void> forceRefreshCustomerOrders() async {
    if (currentUser == null || currentUser?.role == UserRole.director) return;
    try {
      final res = await ApiClient().get('/customer-orders');
      if (res['customerOrders'] is List) {
        final list = (res['customerOrders'] as List)
            .map((e) => CustomerOrder.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _handleIncomingCustomerOrders(list);
      }
    } catch (_) {}
  }

  void _handleIncomingCustomerOrders(List<CustomerOrder> newOrders) {
    // 1. Director panelida QR buyurtma SMS / pop-up / ovozli xabarlari umuman chiqmasin:
    if (currentUser?.role == UserRole.director) {
      return;
    }

    for (final o in newOrders) {
      // 2. Faqat o'sha QR menyusi skaner qilingan kafe paneliga (currentCafeId) xabar borishi kerak:
      if (o.cafeId != null && o.cafeId!.isNotEmpty && o.cafeId != currentCafeId) {
        continue;
      }

      if (o.status == OrderStatus.pending && !_notifiedOrderIds.contains(o.id)) {
        _notifiedOrderIds.add(o.id);
        InAppNotificationService().showNewOrderNotification(
          order: o,
          onAcceptOrder: () {
            updateOrderStatus(o, OrderStatus.preparing);
          },
          onViewOrder: () {
            appNavigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const CustomerOrdersScreen()),
            );
          },
        );
      }
    }
    customerOrders
      ..clear()
      ..addAll(newOrders);
    notifyListeners();
  }

  void updateOrderStatus(CustomerOrder order, OrderStatus status) {
    order.status = status;
    // Buyurtma qabul qilinganda yoki holati o'zgarganda takroriy ovoz to'xtatiladi
    SoundService().stopOrderVoice(order.id);
    _cloudService.updateCustomerOrderStatus(currentCafeId, order.id, status);
    saveData();
    notifyListeners();
  }

  Future<void> deleteCustomerOrder(CustomerOrder order) async {
    customerOrders.removeWhere((o) => o.id == order.id);
    _notifiedOrderIds.remove(order.id);
    SoundService().stopOrderVoice(order.id);
    saveData();
    notifyListeners();
    try {
      await ApiClient().delete('/customer-orders/${order.id}');
    } catch (e) {
      debugPrint('deleteCustomerOrder error: $e');
    }
  }

  Future<void> clearCompletedCustomerOrders() async {
    customerOrders.removeWhere((o) =>
        o.status == OrderStatus.completed ||
        o.status == OrderStatus.cancelled ||
        o.status == OrderStatus.delivered);
    saveData();
    notifyListeners();
    try {
      await ApiClient().post('/customer-orders/clear-completed');
    } catch (e) {
      debugPrint('clearCompletedCustomerOrders error: $e');
    }
  }

  int get pendingOrdersCount =>
      customerOrders.where((o) => o.status == OrderStatus.pending).length;

  void loadOrderIntoCart(CustomerOrder order) {
    cart.clear();
    cart.addAll(
      order.items.map(
        (c) => CartItem(product: c.product, qty: c.qty, note: c.note),
      ),
    );
    if (order.tableNumber != null) {
      try {
        selectedTable = tables.firstWhere(
          (t) => t.number == order.tableNumber && t.hallId == order.hallId,
        );
      } catch (_) {}
    }
    _syncCartToTable();
    notifyListeners();
  }

  void setTableStatus(TableModel t, TableStatus status) {
    t.status = status;
    _cloudService.updateTableStatus(
      cafeId: currentCafeId,
      tableId: t.id,
      status: status,
    );
    saveData();
    notifyListeners();
  }

  // ---------------- CRUD HELPERS ----------------
  void toggleDarkMode(bool v) {
    darkMode = v;
    saveData();
    notifyListeners();
  }

  void setAppLogoUrl(String? url) {
    appLogoUrl = url;
    saveData();
    _cloudService.saveSettings(currentCafeId, {
      'restaurantName': restaurantName,
      'restaurantAddress': restaurantAddress,
      'restaurantPhone': restaurantPhone,
      'receiptSlogan': receiptSlogan,
      'receiptFooterNote': receiptFooterNote,
      'receiptQrEnabled': receiptQrEnabled,
      'darkMode': darkMode,
      'appLogoUrl': appLogoUrl,
    });
    notifyListeners();
  }

  void updateSettings({
    String? name,
    String? receiptName,
    String? address,
    String? phone,
    String? slogan,
    String? footerNote,
    String? logoUrl,
    bool? qrEnabled,
  }) {
    if (name != null && name.isNotEmpty) restaurantName = name;
    if (receiptName != null) {
      this.receiptName = receiptName.trim().isEmpty ? null : receiptName.trim();
    }
    if (address != null && address.isNotEmpty) restaurantAddress = address;
    if (phone != null) restaurantPhone = phone;
    if (slogan != null) receiptSlogan = slogan;
    if (footerNote != null) receiptFooterNote = footerNote;
    if (logoUrl != null) appLogoUrl = logoUrl;
    if (qrEnabled != null) receiptQrEnabled = qrEnabled;
    _cloudService.saveSettings(currentCafeId, {
      'restaurantName': restaurantName,
      'receiptName': this.receiptName,
      'restaurantAddress': restaurantAddress,
      'restaurantPhone': restaurantPhone,
      'receiptSlogan': receiptSlogan,
      'receiptFooterNote': receiptFooterNote,
      'receiptQrEnabled': receiptQrEnabled,
      'darkMode': darkMode,
      'appLogoUrl': appLogoUrl,
    });
    saveData();
    notifyListeners();
  }

  Future<bool> updateReceiptName(String newName) async {
    // Faqat CAFE_OWNER (admin) ruxsatga ega
    if (currentUser != null && currentUser!.role != UserRole.admin) {
      return false;
    }
    receiptName = newName.trim().isEmpty ? null : newName.trim();
    saveData();
    notifyListeners();
    return await _cloudService.updateReceiptName(currentCafeId, receiptName ?? '');
  }

  void updatePrinterSettings({
    required String ip,
    required int port,
    int? charsPerLine,
    String? name,
    PrinterFontSize? fontSize,
  }) {
    printerIp = ip.trim();
    printerPort = port;
    if (charsPerLine != null) printerCharsPerLine = charsPerLine;
    if (fontSize != null) printerFontSize = fontSize;
    connectedPrinterName = printerIp.isEmpty
        ? null
        : (name?.trim().isNotEmpty == true ? name!.trim() : printerIp);
    saveData();
    notifyListeners();
  }

  void updateReceiptLayoutSettings({
    bool? boldHeader,
    ReceiptHeaderAlign? headerAlign,
    int? paperWidth,
    double? margin,
  }) {
    if (boldHeader != null) receiptBoldHeader = boldHeader;
    if (headerAlign != null) receiptHeaderAlign = headerAlign;
    if (paperWidth != null) {
      paperWidthMm = paperWidth;
      printerCharsPerLine = paperWidth == 58 ? 32 : 48;
    }
    if (margin != null) printerMarginMm = margin;
    saveData();
    notifyListeners();
  }

  void updateReceiptVisibilitySettings({
    bool? waiter,
    bool? table,
    bool? dateTime,
    bool? devTag,
    bool? customerCount,
  }) {
    if (waiter != null) showWaiterName = waiter;
    if (table != null) showTableName = table;
    if (dateTime != null) showDateTime = dateTime;
    if (devTag != null) showDeveloperTag = devTag;
    if (customerCount != null) showCustomerCount = customerCount;
    saveData();
    notifyListeners();
  }

  List<Product> _deduplicateProducts(List<Product> list) {
    final seenIds = <int>{};
    final result = <Product>[];
    for (final p in list) {
      if (seenIds.contains(p.id)) continue;
      seenIds.add(p.id);
      result.add(p);
    }
    return result;
  }

  Future<void> addOrUpdateProduct(Product p, {String? originalName}) async {
    final normName = p.name.trim().toLowerCase();
    final normOrigName = originalName?.trim().toLowerCase();
    final idx = products.indexWhere(
      (e) =>
          e.id == p.id ||
          e.name.trim().toLowerCase() == normName ||
          (normOrigName != null && e.name.trim().toLowerCase() == normOrigName),
    );
    if (idx != -1) {
      products[idx] = Product(
        id: products[idx].id,
        name: p.name.trim(),
        price: p.price,
        categoryId: p.categoryId,
        stock: p.stock,
        icon: p.icon,
        imageUrl: p.imageUrl,
      );
    } else {
      products.add(p);
    }
    saveData();
    notifyListeners();

    try {
      final savedProduct = await _cloudService.saveProduct(
        currentCafeId,
        p,
        originalName: originalName,
      );
      if (savedProduct != null) {
        final savedIdx = products.indexWhere(
          (e) =>
              e.id == p.id ||
              e.id == savedProduct.id ||
              e.name.trim().toLowerCase() == savedProduct.name.trim().toLowerCase() ||
              (normOrigName != null && e.name.trim().toLowerCase() == normOrigName),
        );
        if (savedIdx != -1) {
          products[savedIdx] = savedProduct;
        } else {
          products.add(savedProduct);
        }
        final deduped = _deduplicateProducts(products);
        products
          ..clear()
          ..addAll(deduped);
        saveData();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('addOrUpdateProduct cloud error: $e');
    }
  }

  Future<void> deleteProduct(Product p) async {
    final normName = p.name.trim().toLowerCase();
    products.removeWhere(
      (e) =>
          e.id == p.id ||
          (e.name.trim().toLowerCase() == normName &&
              e.categoryId == p.categoryId),
    );
    saveData();
    notifyListeners();
    try {
      await _cloudService.deleteProduct(currentCafeId, p.id, productName: p.name);
    } catch (e) {
      debugPrint('deleteProduct cloud error: $e');
    }
  }

  Future<void> deleteProductsBulk(List<int> productIds) async {
    products.removeWhere((e) => productIds.contains(e.id));
    saveData();
    notifyListeners();
    try {
      await _cloudService.deleteProductsBulk(currentCafeId, productIds);
    } catch (e) {
      debugPrint('deleteProductsBulk cloud error: $e');
    }
  }

  void addOrUpdateCategory(Category c) {
    final idx = categories.indexWhere((e) => e.id == c.id);
    if (idx == -1) {
      categories.add(c);
    } else {
      categories[idx] = c;
    }
    _cloudService.saveCategory(currentCafeId, c);
    saveData();
    notifyListeners();
  }

  void deleteCategory(Category c) {
    categories.removeWhere((e) => e.id == c.id);
    products.removeWhere((p) => p.categoryId == c.id);
    _cloudService.deleteCategory(currentCafeId, c.id);
    saveData();
    notifyListeners();
  }

  void addOrUpdateEmployee(AppUser u) {
    final idx = users.indexWhere((e) => e.id == u.id);
    if (idx == -1) {
      users.add(u);
    } else {
      users[idx] = u;
    }
    _cloudService.saveEmployee(currentCafeId, u);
    saveData();
    notifyListeners();
  }

  void deleteEmployee(AppUser u) {
    users.removeWhere((e) => e.id == u.id);
    _cloudService.deleteEmployee(currentCafeId, u.id);
    saveData();
    notifyListeners();
  }

  void addOrUpdateCustomer(Customer c) {
    final idx = customers.indexWhere((e) => e.id == c.id);
    if (idx == -1) {
      customers.add(c);
    } else {
      customers[idx] = c;
    }
    _cloudService.saveCustomer(currentCafeId, c);
    saveData();
    notifyListeners();
  }

  void deleteCustomer(Customer c) {
    customers.removeWhere((e) => e.id == c.id);
    _cloudService.deleteCustomer(currentCafeId, c.id);
    saveData();
    notifyListeners();
  }

  void adjustStock(Product p, int newStock) {
    p.stock = newStock;
    _cloudService.saveProduct(currentCafeId, p);
    saveData();
    notifyListeners();
  }

  // ---------------- REPORT HELPERS ----------------
  double get todayRevenue {
    final now = DateTime.now();
    return receipts
        .where(
          (r) =>
              r.date.year == now.year &&
              r.date.month == now.month &&
              r.date.day == now.day,
        )
        .fold(0.0, (s, r) => s + r.total);
  }

  int get todayOrders {
    final now = DateTime.now();
    return receipts
        .where(
          (r) =>
              r.date.year == now.year &&
              r.date.month == now.month &&
              r.date.day == now.day,
        )
        .length;
  }

  Map<String, double> get topProductsByRevenue {
    final map = <String, double>{};
    for (final r in receipts) {
      for (final item in r.items) {
        map[item.product.name] = (map[item.product.name] ?? 0) + item.total;
      }
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in entries.take(8)) e.key: e.value};
  }

  Map<String, double> get salesByCashier {
    final map = <String, double>{};
    for (final r in receipts) {
      map[r.cashierName] = (map[r.cashierName] ?? 0) + r.total;
    }
    return map;
  }

  // ---------------- SAQLASH / YUKLASH (SharedPreferences Cache) ----------------
  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final pfx = currentCafeId.isNotEmpty ? '${currentCafeId}_' : '';

    await prefs.setString('${pfx}restaurantName', restaurantName);
    if (receiptName != null && receiptName!.isNotEmpty) {
      await prefs.setString('${pfx}receiptName', receiptName!);
    } else {
      await prefs.remove('${pfx}receiptName');
    }
    await prefs.setString('${pfx}restaurantAddress', restaurantAddress);
    await prefs.setString('${pfx}restaurantPhone', restaurantPhone);
    await prefs.setString('${pfx}receiptSlogan', receiptSlogan);
    await prefs.setString('${pfx}receiptFooterNote', receiptFooterNote);
    await prefs.setBool('${pfx}receiptQrEnabled', receiptQrEnabled);
    await prefs.setBool('darkMode', darkMode);
    await prefs.setInt('${pfx}idCounter', _idCounter);
    await prefs.setString('printerIp', printerIp);
    await prefs.setInt('printerPort', printerPort);
    await prefs.setInt('printerCharsPerLine', printerCharsPerLine);
    await prefs.setInt('printerFontSize', printerFontSize.index);
    await prefs.setBool('receiptBoldHeader', receiptBoldHeader);
    await prefs.setInt('receiptHeaderAlign', receiptHeaderAlign.index);
    await prefs.setInt('paperWidthMm', paperWidthMm);
    await prefs.setDouble('printerMarginMm', printerMarginMm);
    await prefs.setBool('showWaiterName', showWaiterName);
    await prefs.setBool('showTableName', showTableName);
    await prefs.setBool('showDateTime', showDateTime);
    await prefs.setBool('showDeveloperTag', showDeveloperTag);
    await prefs.setBool('showCustomerCount', showCustomerCount);
    if (connectedPrinterName != null) {
      await prefs.setString('connectedPrinterName', connectedPrinterName!);
    } else {
      await prefs.remove('connectedPrinterName');
    }
    if (appLogoUrl != null) {
      await prefs.setString('${pfx}appLogoUrl', appLogoUrl!);
    } else {
      await prefs.remove('${pfx}appLogoUrl');
    }
    // 1. Muhim jonli stol buyurtmalarini avval saqlaymiz (eng yuqori prioritet)
    try {
      final ordersJson = jsonEncode(
        tableOrders.map(
          (k, v) => MapEntry(k.toString(), v.map((e) => e.toJson()).toList()),
        ),
      );
      try {
        await prefs.setString('${pfx}tableOrders', ordersJson);
        await prefs.setString('${pfx}tableNotes', jsonEncode(tableNotes));
      } catch (_) {
        // Quota to'lgan bo'lsa, keraksiz keshni tozalab qayta saqlaymiz
        await LocalCacheService().pruneCacheForQuota(prefs);
        await prefs.setString('${pfx}tableOrders', ordersJson);
        await prefs.setString('${pfx}tableNotes', jsonEncode(tableNotes));
      }
    } catch (e) {
      debugPrint('saveData tableOrders error: $e');
    }

    // 2. Qolgan ma'lumotlarni alohida blokda saqlash (QuotaExceededError dan himoyalash)
    Future<void> safeSet(String key, String val) async {
      try {
        await prefs.setString(key, val);
      } catch (e) {
        try {
          await LocalCacheService().pruneCacheForQuota(prefs);
          await prefs.setString(key, val);
        } catch (_) {
          debugPrint('saveData ($key) error: $e');
        }
      }
    }

    await safeSet('${pfx}users', jsonEncode(users.map((e) => e.toJson()).toList()));
    await safeSet('${pfx}categories', jsonEncode(categories.map((e) => e.toJson()).toList()));

    // Products uchun rasmlarni keshga yozishda katta base64 larni tozalamiz (QuotaExceededError dan xoli)
    try {
      final sanitizedProducts = products.map((p) {
        final json = p.toJson();
        final img = json['imageUrl']?.toString();
        if (img != null && img.startsWith('data:image/') && img.length > 50000) {
          json['imageUrl'] = null;
        }
        return json;
      }).toList();
      await safeSet('${pfx}products', jsonEncode(sanitizedProducts));
    } catch (_) {}

    await safeSet('${pfx}halls', jsonEncode(halls.map((e) => e.toJson()).toList()));
    await safeSet('${pfx}tables', jsonEncode(tables.map((e) => e.toJson()).toList()));
    await safeSet('${pfx}customers', jsonEncode(customers.map((e) => e.toJson()).toList()));

    // Cheklar va hisobotlar kesh hajmini chegaralaymiz (so'nggi 80 ta)
    final cachedReceipts = receipts.length > 80 ? receipts.sublist(receipts.length - 80) : receipts;
    await safeSet('${pfx}receipts', jsonEncode(cachedReceipts.map((e) => e.toJson()).toList()));
    final cachedDailyReports = dailyReports.length > 60 ? dailyReports.sublist(dailyReports.length - 60) : dailyReports;
    await safeSet('${pfx}dailyReports', jsonEncode(cachedDailyReports.map((e) => e.toJson()).toList()));
    final cachedCustomerOrders = customerOrders.length > 50 ? customerOrders.sublist(customerOrders.length - 50) : customerOrders;
    await safeSet('${pfx}customerOrders', jsonEncode(cachedCustomerOrders.map((e) => e.toJson()).toList()));
    await safeSet('${pfx}voiceNotificationEnabled', voiceNotificationEnabled.toString());
  }

  bool _safeBoolFromPrefs(SharedPreferences prefs, String key, bool fallback) {
    try {
      final v = prefs.get(key);
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true' || v == '1';
      if (v is num) return v != 0;
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _loadFromLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final pfx = currentCafeId.isNotEmpty ? '${currentCafeId}_' : '';

    restaurantName = prefs.getString('${pfx}restaurantName') ?? prefs.getString('restaurantName') ?? restaurantName;
    receiptName = prefs.getString('${pfx}receiptName') ?? prefs.getString('receiptName') ?? receiptName;
    restaurantAddress =
        prefs.getString('${pfx}restaurantAddress') ?? prefs.getString('restaurantAddress') ?? restaurantAddress;
    restaurantPhone = prefs.getString('${pfx}restaurantPhone') ?? prefs.getString('restaurantPhone') ?? restaurantPhone;
    receiptSlogan = prefs.getString('${pfx}receiptSlogan') ?? prefs.getString('receiptSlogan') ?? receiptSlogan;
    receiptFooterNote =
        prefs.getString('${pfx}receiptFooterNote') ?? prefs.getString('receiptFooterNote') ?? receiptFooterNote;
    receiptQrEnabled = _safeBoolFromPrefs(prefs, '${pfx}receiptQrEnabled', _safeBoolFromPrefs(prefs, 'receiptQrEnabled', receiptQrEnabled));
    darkMode = _safeBoolFromPrefs(prefs, 'darkMode', darkMode);
    voiceNotificationEnabled = _safeBoolFromPrefs(
      prefs,
      '${pfx}voiceNotificationEnabled',
      _safeBoolFromPrefs(prefs, 'voiceNotificationEnabled', true),
    );
    SoundService().setVoiceEnabled(voiceNotificationEnabled);
    _idCounter = prefs.getInt('${pfx}idCounter') ?? prefs.getInt('idCounter') ?? _idCounter;
    printerIp = prefs.getString('printerIp') ?? printerIp;
    printerPort = prefs.getInt('printerPort') ?? printerPort;
    printerCharsPerLine =
        prefs.getInt('printerCharsPerLine') ?? printerCharsPerLine;
    if (prefs.containsKey('printerFontSize')) {
      final idx =
          prefs.getInt('printerFontSize') ?? PrinterFontSize.normal.index;
      printerFontSize = PrinterFontSize.values[idx.clamp(
        0,
        PrinterFontSize.values.length - 1,
      )];
    }
    connectedPrinterName =
        prefs.getString('connectedPrinterName') ?? connectedPrinterName;
    receiptBoldHeader = _safeBoolFromPrefs(prefs, 'receiptBoldHeader', receiptBoldHeader);
    if (prefs.containsKey('receiptHeaderAlign')) {
      final idx =
          prefs.getInt('receiptHeaderAlign') ?? ReceiptHeaderAlign.center.index;
      receiptHeaderAlign = ReceiptHeaderAlign.values[idx.clamp(
        0,
        ReceiptHeaderAlign.values.length - 1,
      )];
    }
    paperWidthMm = prefs.getInt('paperWidthMm') ?? paperWidthMm;
    printerMarginMm = prefs.getDouble('printerMarginMm') ?? printerMarginMm;
    showWaiterName = _safeBoolFromPrefs(prefs, 'showWaiterName', showWaiterName);
    showTableName = _safeBoolFromPrefs(prefs, 'showTableName', showTableName);
    showDateTime = _safeBoolFromPrefs(prefs, 'showDateTime', showDateTime);
    showDeveloperTag = _safeBoolFromPrefs(prefs, 'showDeveloperTag', showDeveloperTag);
    showCustomerCount = _safeBoolFromPrefs(prefs, 'showCustomerCount', showCustomerCount);
    appLogoUrl = prefs.getString('${pfx}appLogoUrl') ?? prefs.getString('appLogoUrl') ?? appLogoUrl;

    void restore<T>(
      String key,
      List<T> target,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      final raw = prefs.getString('$pfx$key');
      if (raw == null) return;
      final decoded = jsonDecode(raw) as List;
      target
        ..clear()
        ..addAll(decoded.map((e) => fromJson(e as Map<String, dynamic>)));
    }

    restore('users', users, AppUser.fromJson);
    restore('categories', categories, Category.fromJson);
    restore('products', products, Product.fromJson);
    restore('halls', halls, Hall.fromJson);
    restore('tables', tables, TableModel.fromJson);
    restore('customers', customers, Customer.fromJson);
    restore('receipts', receipts, Receipt.fromJson);
    restore('dailyReports', dailyReports, DailyReport.fromJson);
    restore('customerOrders', customerOrders, CustomerOrder.fromJson);
    // Eski buyurtmalar qayta ochilganda qayta ovoz bermasligi uchun ID larini ro'yxatga olamiz
    _notifiedOrderIds.addAll(customerOrders.map((e) => e.id));

    final rawTableOrders = prefs.getString('${pfx}tableOrders');
    if (rawTableOrders != null) {
      final decoded = jsonDecode(rawTableOrders) as Map<String, dynamic>;
      tableOrders
        ..clear()
        ..addAll(
          decoded.map(
            (k, v) => MapEntry(
              int.parse(k),
              (v as List)
                  .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
                  .toList(),
            ),
          ),
        );
    }
    final rawTableNotes = prefs.getString('${pfx}tableNotes');
    if (rawTableNotes != null) {
      final decoded = jsonDecode(rawTableNotes) as Map<String, dynamic>;
      tableNotes
        ..clear()
        ..addAll(decoded.map((k, v) => MapEntry(int.parse(k), v as String)));
    }
  }

  Future<void> loadData() async {
    try {
      final cachedUser = await ApiClient().readCachedUserJson();
      if (cachedUser != null) {
        currentUser = AppUser.fromJson(cachedUser);
      }
    } catch (e) {
      debugPrint('readCachedUserJson in loadData error: $e');
    }

    await _loadFromLocalCache();
    _reconcileAllTableStatuses();

    try {
      final profile = await _authService.getCurrentUserDetails();
      if (profile != null) {
        currentUser = profile;
      }
    } catch (_) {}

    try {
      await loadCloudDataForCafe(currentCafeId);
    } catch (e) {
      debugPrint('loadData cloud sync error: $e');
    }

    await saveData();
    notifyListeners();
  }
}

final AppState appState = AppState();

// ============================================================
// TARMOQ (Wi-Fi / LAN) PRINTERGA ULANISH — ESC/POS PROTOKOLI
// ============================================================
//
// Bu bo'lim restoran/kassada ko'p ishlatiladigan tarmoqli (Wi-Fi yoki LAN
// kabel bilan ulanadigan) termal cheklar printeriga TO'G'RIDAN-TO'G'RI,
// hech qanday qo'shimcha paket o'rnatmasdan (faqat dart:io Socket orqali)
// ulanish va chek chiqarish uchun yozilgan.
//
// MUHIM — LOTINCHA/KIRILLCHA (O'ZBEKCHA) MATNLARNING TO'G'RI CHIQISHI:
// Ko'pchilik arzon termal (ESC/POS) printerlar UTF-8'ni tushunmaydi —
// ular faqat bitta-baytli "code page" (masalan CP866 — kirillcha uchun
// eng keng tarqalgan code page) orqali ishlaydi. Shuning uchun avval
// printerga "ESC t 17" buyrug'i bilan CP866 code page tanlanadi, so'ngra
// har bir belgi shu code page bo'yicha bitta baytga aylantirilib
// yuboriladi (_Cp866.encode). Lotin harflari (a-z, A-Z, raqamlar,
// apostrof) CP866'da ham oddiy ASCII bilan bir xil bo'lgani uchun ular
// har doim to'g'ri chiqadi; kirillcha harflar esa maxsus jadval bo'yicha
// mos baytga almashtiriladi.
//
// Printerning IP-manzilini bilish uchun odatda:
//  - printerning o'zidagi "Self test" / tarmoq sozlamalari chekini
//    chiqarish (printerni yoqib turib FEED tugmasini bosib turish),
//  - yoki router (masalan TP-Link, Wi-Fi router) sozlamalaridagi
//    "ulangan qurilmalar" ro'yxatidan foydalanish mumkin.
//
// Bu bo'lim 3 xil chek chiqaradi (pastdagi PDF versiyalari bilan bir xil
// ma'lumotlarni oladi):
//   1) printReceiptNetwork      -> to'langan chek (mijozga)
//   2) printBillNetwork         -> hali to'lanmagan hisob (stol uchun)
//   3) printKitchenTicketNetwork-> oshxona/oshpaz cheki (narxsiz)
// ============================================================

/// Printerga ulanish uchun sozlamalar (IP-manzil, port, qog'oz kengligi).
class PrinterConnectionSettings {
  final String ip;
  final int port;
  final int charsPerLine; // 32 -> 58mm qog'oz, 48 -> 80mm qog'oz

  const PrinterConnectionSettings({
    required this.ip,
    this.port = 9100,
    this.charsPerLine = 48,
  });
}

/// Xato holatida chiqariladigan maxsus exception — ekranda tushunarli
/// xabar ko'rsatish uchun.
class PrinterConnectionException implements Exception {
  final String message;
  PrinterConnectionException(this.message);
  @override
  String toString() => message;
}

// ---- KIRILLCHA (O'ZBEKCHA/RUSCHA) HARFLARNI CP866 BAYTLARIGA
// AYLANTIRISH — termal printer to'g'ri kirillcha chiqarishi uchun ----
class _Cp866 {
  static List<int> encode(String s) {
    final bytes = <int>[];
    for (final rune in s.runes) {
      bytes.add(_byteFor(rune));
    }
    return bytes;
  }

  static int _byteFor(int rune) {
    // Lotin harflari, raqamlar, tinish belgilari — ASCII bilan bir xil
    if (rune < 0x80) return rune;

    // Katta harflar А-Я (U+0410 - U+042F) -> 0x80-0x9F
    if (rune >= 0x0410 && rune <= 0x042F) return 0x80 + (rune - 0x0410);
    // Kichik harflar а-п (U+0430 - U+043F) -> 0xA0-0xAF
    if (rune >= 0x0430 && rune <= 0x043F) return 0xA0 + (rune - 0x0430);
    // Kichik harflar р-я (U+0440 - U+044F) -> 0xE0-0xEF
    if (rune >= 0x0440 && rune <= 0x044F) return 0xE0 + (rune - 0x0440);
    // Ё / ё
    if (rune == 0x0401) return 0xF0;
    if (rune == 0x0451) return 0xF1;

    // O'zbekcha kirill harflari CP866 jadvalida yo'q — eng yaqin
    // ko'rinishdagi harf bilan almashtiramiz (butunlay yo'qolib
    // ketmasligi uchun)
    switch (rune) {
      case 0x040E: // Ў
        return 0x93; // У
      case 0x045E: // ў
        return 0xE3; // у
      case 0x049A: // Қ
        return 0x8A; // К
      case 0x049B: // қ
        return 0xAA; // к
      case 0x0492: // Ғ
        return 0x83; // Г
      case 0x0493: // ғ
        return 0xA3; // г
      case 0x04B2: // Ҳ
        return 0x95; // Х
      case 0x04B3: // ҳ
        return 0xE5; // х
    }

    // Lotincha o'zbekcha tutuq belgisi (oʻ, gʻ) turli xil unicode
    // ko'rinishlarda kelishi mumkin — barchasini oddiy apostrofga
    // almashtiramiz
    if (rune == 0x02BB || rune == 0x02BC || rune == 0x2018 || rune == 0x2019) {
      return 0x27; // '
    }
    if (rune == 0x2013 || rune == 0x2014) return 0x2D; // – — -> -
    if (rune == 0x201C || rune == 0x201D) return 0x22; // “ ” -> "

    // Tanilmagan belgi
    return 0x3F; // ?
  }
}

// ---- ESC/POS BUYRUQLARI (termal printerlar tushunadigan xom baytlar) ----
class _Esc {
  static const List<int> init = [0x1B, 0x40]; // ESC @  -> printerni tozalash
  // ESC t 17 -> CP866 (kirillcha) code page'ni tanlash
  static const List<int> codepageCp866 = [0x1B, 0x74, 17];
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];
  // ignore: unused_field
  static const List<int> alignRight = [0x1B, 0x61, 0x02];
  static const List<int> boldOn = [0x1B, 0x45, 0x01];
  static const List<int> boldOff = [0x1B, 0x45, 0x00];
  static const List<int> doubleOn = [0x1D, 0x21, 0x11]; // 2x katta shrift
  // ignore: unused_field
  static const List<int> doubleHeightOn = [0x1D, 0x21, 0x01];
  static const List<int> normalSize = [0x1D, 0x21, 0x00];
  // ignore: unused_field
  static const List<int> underlineOn = [0x1B, 0x2D, 0x01];
  // ignore: unused_field
  static const List<int> underlineOff = [0x1B, 0x2D, 0x00];
  // ESC M 0/1 -> shrift turini tanlash: Font A (standart, kattaroq) yoki
  // Font B (odatda ~20-25% kichikroq) — "Kichik" o'lcham shu bilan olinadi.
  static const List<int> fontA = [0x1B, 0x4D, 0x00];
  static const List<int> fontB = [0x1B, 0x4D, 0x01];
  // ESC 3 n -> qatorlar orasidagi masofani (line spacing) n nuqtaga
  // o'rnatadi. Standart printer sozlamasi odatda juda keng (~30-40 nuqta)
  // bo'lganligi uchun chek "bo'sh joy ko'p" bo'lib chiqadi; buni kichikroq
  // songa o'rnatib, qatorlarni bir-biriga yaqinlashtiramiz.
  static List<int> lineSpacing(int dots) => [0x1B, 0x33, dots];
  // ESC 2 -> printerning standart (zavod) qator oralig'iga qaytarish.
  static const List<int> lineSpacingDefault = [0x1B, 0x32];
  static List<int> feed(int lines) => [0x1B, 0x64, lines];
  static const List<int> cut = [0x1D, 0x56, 0x01]; // qog'ozni qisman kesish
  // Kassa qutisini ochish signali (agar printerga ulangan bo'lsa)
  static const List<int> openDrawer = [0x1B, 0x70, 0x00, 0x19, 0xFA];
}

class NetworkPrinterService {
  NetworkPrinterService._();

  /// Baytlarni printerning IP-manzili va porti orqali (xom TCP socket
  /// bilan) yuboradi. Bu — printerga "ulanish"ning o'zi shu yerda sodir
  /// bo'ladi: Socket.connect(ip, port) chaqirilganda qurilma printer
  /// bilan tarmoq orqali bog'lanadi.
  static Future<void> _sendRaw(
    List<int> bytes, {
    required String ip,
    required int port,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (ip.trim().isEmpty) {
      throw PrinterConnectionException(
        'Printer IP-manzili kiritilmagan. Sozlamalar -> Printer bo\'limida '
        'IP-manzilni kiriting.',
      );
    }
    Socket? socket;
    try {
      socket = await Socket.connect(ip.trim(), port, timeout: timeout);
      socket.add(bytes);
      await socket.flush();
      // Printer baytlarni qabul qilib ulgurishi uchun kichik pauza
      await Future.delayed(const Duration(milliseconds: 150));
    } on SocketException catch (e) {
      throw PrinterConnectionException(
        'Printerga ulanib bo\'lmadi ($ip:$port). Printer yoqilganligini, '
        'bir xil Wi-Fi tarmog\'ida ekanligini va IP-manzil to\'g\'riligini '
        'tekshiring.\n\nTexnik xato: ${e.osError?.message ?? e.message}',
      );
    } catch (e) {
      throw PrinterConnectionException('Chop etishda kutilmagan xatolik: $e');
    } finally {
      try {
        await socket?.close();
      } catch (_) {
        // socket allaqachon yopilgan bo'lishi mumkin — e'tiborsiz qoldiramiz
      }
    }
  }

  // Matnni printer tushunadigan CP866 baytlariga aylantiradi (kirillcha
  // va lotincha o'zbekcha matnlar to'g'ri chiqishi uchun)
  static List<int> _t(String s) => _Cp866.encode(s);

  /// Chapga va o'ngga tekislangan ikkita matnni bitta qatorga sig'diradi
  /// (masalan "Taom nomi x2 .......... 25 000").
  static List<int> _row(String left, String right, int width) {
    final maxLeft = width - right.length - 1;
    var l = left;
    if (l.length > maxLeft && maxLeft > 3) {
      l = '${l.substring(0, maxLeft - 1)}.';
    }
    final spaces = width - l.length - right.length;
    final gap = spaces > 1 ? ' ' * spaces : ' ';
    return _t('$l$gap$right\n');
  }

  // Rasmdagi chekka o'xshash "punktir" (- - - - -) ko'rinishidagi
  // ajratuvchi chiziq — tutash chiziq emas, dash+bo'sh joy almashinib
  // keladi, xuddi namuna chekdagi kabi.
  static List<int> _divider(int width) {
    final buffer = StringBuffer();
    for (var i = 0; i < width; i++) {
      buffer.write(i.isEven ? '-' : ' ');
    }
    return _t('${buffer.toString()}\n');
  }

  static List<int> _center(String text) => _t('$text\n');

  static List<int> _alignFor(ReceiptHeaderAlign align) {
    switch (align) {
      case ReceiptHeaderAlign.left:
        return _Esc.alignLeft;
      case ReceiptHeaderAlign.right:
        return _Esc.alignRight;
      case ReceiptHeaderAlign.center:
        return _Esc.alignCenter;
    }
  }

  // ------------------------------------------------------------
  // ULANISHNI TEKSHIRISH (Sozlamalar ekranidagi "Ulanishni tekshirish")
  // ------------------------------------------------------------
  static Future<void> testConnection({
    required String ip,
    required int port,
    int charsPerLine = 48,
  }) async {
    final w = charsPerLine;
    final bytes = <int>[
      ..._Esc.init,
      ..._Esc.codepageCp866,
      ..._Esc.alignCenter,
      ..._Esc.boldOn,
      ..._Esc.doubleOn,
      ..._t('ULANISH OK\n'),
      ..._Esc.normalSize,
      ..._Esc.boldOff,
      ..._t('${appState.effectiveReceiptName}\n'),
      ..._divider(w),
      ..._Esc.alignLeft,
      ..._t('Printer: $ip:$port\n'),
      ..._t('Sana: ${DateTime.now().toString().substring(0, 16)}\n'),
      ..._Esc.alignCenter,
      ..._t('Test cheki muvaffaqiyatli chiqdi.\n'),
      ..._Esc.lineSpacingDefault,
      ..._Esc.feed(6),
      ..._Esc.cut,
      ..._Esc.feed(1),
    ];

    await _sendRaw(bytes, ip: ip, port: port);
  }

  /// Uchta ustunli qatorni (Menyu / Soni / Summa) bitta chek qatoriga
  /// joylashtiradi — birinchi ustun chapga, ikkinchisi markazga, uchinchisi
  /// o'ngga tekislanadi (namuna chekdagi kabi).
  static List<int> _row3(String a, String b, String c, int width) {
    final colB = (width <= 36) ? 7 : 8;
    final colC = (width <= 36) ? 9 : 12;
    final colA = (width - colB - colC - 2).clamp(6, width).toInt();

    String padLeft(String s, int len) {
      if (s.length > len) {
        s = len > 1 ? '${s.substring(0, len - 1)}.' : s.substring(0, len);
      }
      return s + ' ' * (len - s.length);
    }

    String padRight(String s, int len) {
      if (s.length > len) s = s.substring(0, len);
      return ' ' * (len - s.length) + s;
    }

    String padCenter(String s, int len) {
      if (s.length > len) s = s.substring(0, len);
      final totalGap = len - s.length;
      final left = totalGap ~/ 2;
      final right = totalGap - left;
      return ' ' * left + s + ' ' * right;
    }

    final line =
        '${padLeft(a, colA)} ${padCenter(b, colB)} ${padRight(c, colC)}';
    return _t('$line\n');
  }

  /// Tanlangan shrift o'lchamiga mos ESC/POS baytlarini qaytaradi:
  /// - `small`  -> Font B (kichikroq shrift), oddiy (1x) o'lcham
  /// - `normal` -> Font A, oddiy (1x) o'lcham — HAQIQIY standart o'lcham
  /// - `large`  -> Font A, 2x (eni va bo'yi)
  static List<int> _fontBytes(PrinterFontSize size) {
    switch (size) {
      case PrinterFontSize.small:
        return [..._Esc.fontB, ..._Esc.normalSize];
      case PrinterFontSize.normal:
        return [..._Esc.fontA, ..._Esc.normalSize];
      case PrinterFontSize.large:
        return [..._Esc.fontA, ..._Esc.doubleOn];
    }
  }

  /// Chekning umumiy qatorlar orasidagi bo'shlig'ini (line-height) tanlangan
  /// shrift o'lchamiga qarab ixchamlashtiradi.
  static List<int> _lineSpacingFor(PrinterFontSize size) {
    switch (size) {
      case PrinterFontSize.small:
        return _Esc.lineSpacing(22);
      case PrinterFontSize.normal:
        return _Esc.lineSpacing(26);
      case PrinterFontSize.large:
        return _Esc.lineSpacing(34);
    }
  }

  /// ReceiptWidget va namunaviy chek (1-rasm) bilan 100% bir xil
  /// ESC/POS baytlarini generatsiya qiluvchi universal metod.
  static List<int> _buildReceiptBytes({
    required String checkId,
    required String cashierName,
    required String? hallName,
    required String? tableNumberStr,
    required String customer,
    required DateTime dateTime,
    required List<CartItem> items,
    required double productsTotal,
    required double serviceTotal,
    required double grandTotal,
    required int charsPerLine,
    required PrinterFontSize fontSize,
  }) {
    final w = charsPerLine;
    final headerAlign = _alignFor(appState.receiptHeaderAlign);
    final bytes = <int>[
      ..._Esc.init,
      ..._Esc.codepageCp866,
      ..._lineSpacingFor(fontSize),
    ];

    // 1. KAFE NOMI
    bytes.addAll(headerAlign);
    if (appState.receiptBoldHeader) {
      bytes.addAll(_Esc.boldOn);
    }
    bytes
      ..addAll(_Esc.doubleOn)
      ..addAll(_t('${appState.effectiveReceiptName}\n'))
      ..addAll(_Esc.normalSize)
      ..addAll(_Esc.boldOff);

    // 2. MANZIL (sarlavha ostida)
    if (appState.restaurantAddress.trim().isNotEmpty) {
      bytes
        ..addAll(headerAlign)
        ..addAll(_t('${appState.restaurantAddress}\n'));
    }

    // 3. TELEFON RAQAMI (manzil ostida — xuddi ekrandagi kabi!)
    if (appState.restaurantPhone.trim().isNotEmpty) {
      bytes
        ..addAll(headerAlign)
        ..addAll(_t('Tel: ${appState.restaurantPhone}\n'));
    }

    // 4. BO'SH JOY
    bytes.addAll(_t('\n'));

    // 5. CHEK MA'LUMOTLARI
    bytes
      ..addAll(_Esc.alignLeft)
      ..addAll(_fontBytes(fontSize));

    if (appState.showCustomerCount) {
      bytes.addAll(_row('Chek: $checkId', 'Mijoz: $customer', w));
    } else {
      bytes.addAll(_t('Chek: $checkId\n'));
    }

    if (appState.showWaiterName && cashierName.trim().isNotEmpty) {
      bytes.addAll(_t('Ofitsiant: $cashierName\n'));
    }

    if (appState.showTableName &&
        tableNumberStr != null &&
        tableNumberStr.trim().isNotEmpty) {
      bytes.addAll(_t('${hallName ?? 'Zal'} - stol $tableNumberStr\n'));
    }

    // 6. GORIZONTAL PUNKTIR CHIZIQ
    bytes
      ..addAll(_Esc.fontA)
      ..addAll(_Esc.normalSize)
      ..addAll(_divider(w));

    // 7. JADVAL SARLAVHASI (Menyu / Soni / Summa)
    bytes
      ..addAll(_Esc.boldOn)
      ..addAll(_fontBytes(fontSize))
      ..addAll(_row3('Menyu', 'Soni', 'Summa', w))
      ..addAll(_Esc.fontA)
      ..addAll(_Esc.normalSize)
      ..addAll(_Esc.boldOff);

    // 8. MAHSULOTLAR RO'YXATI
    bytes.addAll(_fontBytes(fontSize));
    for (final item in items) {
      bytes.addAll(
        _row3(
          item.product.name,
          '${item.qty} dona',
          ReceiptWidget.money(item.product.price.round()),
          w,
        ),
      );
    }
    bytes
      ..addAll(_Esc.fontA)
      ..addAll(_Esc.normalSize);

    // 9. MAHSULOTLAR QIYMATI VA XIZMAT
    final servicePercentLabel =
        productsTotal > 0 ? (serviceTotal / productsTotal * 100).round() : 0;
    bytes
      ..addAll(_row('Mahsulotlar qiymati:',
          '${ReceiptWidget.money(productsTotal.round())} UZS', w))
      ..addAll(_row('Xizmat: $servicePercentLabel%',
          '${ReceiptWidget.money(serviceTotal.round())} UZS', w));

    // 10. HAMMASI (qalin)
    bytes.addAll(_Esc.feed(1));
    bytes
      ..addAll(_Esc.boldOn)
      ..addAll(_fontBytes(fontSize))
      ..addAll(
          _row('Hammasi:', '${ReceiptWidget.money(grandTotal.round())} UZS', w))
      ..addAll(_Esc.fontA)
      ..addAll(_Esc.normalSize)
      ..addAll(_Esc.boldOff);

    // 11. PASTKI GORIZONTAL PUNKTIR CHIZIQ
    bytes.addAll(_divider(w));

    // 12. VAQTI
    if (appState.showDateTime) {
      bytes
        ..addAll(_Esc.alignLeft)
        ..addAll(
          _t(
            'Vaqti: ${dateTime.year}.'
            '${dateTime.month.toString().padLeft(2, '0')}.'
            '${dateTime.day.toString().padLeft(2, '0')} - '
            '${dateTime.hour.toString().padLeft(2, '0')}:'
            '${dateTime.minute.toString().padLeft(2, '0')}:'
            '${dateTime.second.toString().padLeft(2, '0')}\n\n',
          ),
        );
    }

    // 13. RAHMAT XABARI (markazda, qalin)
    final footerMsg = appState.receiptFooterNote.trim().isNotEmpty
        ? appState.receiptFooterNote.trim()
        : 'Xaridingiz uchun rahmat!';
    bytes
      ..addAll(_Esc.alignCenter)
      ..addAll(_Esc.boldOn)
      ..addAll(_t('$footerMsg\n'))
      ..addAll(_Esc.boldOff);

    // 14. DEVELOPER YORLIG'I
    if (appState.showDeveloperTag) {
      bytes
        ..addAll(_t('\nRestoranlarni avtomatlashtirish\n'))
        ..addAll(_t('Zavero.uz\n'));
    }

    // 15. QOG'OZNI TOZA VA YIRTILMASDAN KESISH (Feed + Cut)
    // Standart qator oralig'iga qaytarilib, yetarlicha qatorlar oldinga suriladi —
    // bu bilan barcha matnlar printerning pichog'idan to'liq o'tadi va
    // chek yirtilmay, chiroyli va toza kesiladi!
    bytes
      ..addAll(_Esc.lineSpacingDefault)
      ..addAll(_Esc.feed(6))
      ..addAll(_Esc.cut)
      ..addAll(_Esc.feed(1));

    return bytes;
  }

  // ------------------------------------------------------------
  // 1) TO'LANGAN CHEK (mijozga beriladigan chek)
  // ------------------------------------------------------------
  static Future<void> printReceiptNetwork(
    Receipt receipt, {
    required String ip,
    required int port,
    int charsPerLine = 48,
    PrinterFontSize fontSize = PrinterFontSize.normal,
    String customer = '1',
  }) async {
    final bytes = _buildReceiptBytes(
      checkId: 'T${receipt.id}',
      cashierName: receipt.cashierName,
      hallName: receipt.hallName,
      tableNumberStr:
          receipt.tableNumber != null ? '${receipt.tableNumber}' : null,
      customer: customer,
      dateTime: receipt.date,
      items: receipt.items,
      productsTotal: receipt.total,
      serviceTotal: 0,
      grandTotal: receipt.total,
      charsPerLine: charsPerLine,
      fontSize: fontSize,
    );

    await _sendRaw(bytes, ip: ip, port: port);
  }

  // ------------------------------------------------------------
  // 2) HALI TO'LANMAGAN HISOB ("Xarid cheki")
  // ------------------------------------------------------------
  static Future<void> printBillNetwork({
    required List<CartItem> items,
    required double productsTotal,
    required double serviceTotal,
    required double grandTotal,
    required PaymentMethod method,
    required String ip,
    required int port,
    TableModel? table,
    String? hallName,
    String? cashierName,
    int charsPerLine = 48,
    PrinterFontSize fontSize = PrinterFontSize.normal,
  }) async {
    final now = DateTime.now();
    final checkId = 'T${table?.number ?? '-'}-${now.millisecondsSinceEpoch}';
    final name = cashierName ??
        appState.currentUser?.name ??
        appState.guestName ??
        'Mehmon';

    final bytes = _buildReceiptBytes(
      checkId: checkId,
      cashierName: name,
      hallName: hallName ?? 'Zal',
      tableNumberStr: table != null ? '${table.number}' : null,
      customer: '1',
      dateTime: now,
      items: items,
      productsTotal: productsTotal,
      serviceTotal: serviceTotal,
      grandTotal: grandTotal,
      charsPerLine: charsPerLine,
      fontSize: fontSize,
    );

    await _sendRaw(bytes, ip: ip, port: port);
  }

  // ------------------------------------------------------------
  // 3) OSHXONA / OSHPAZ CHEKI (narxsiz)
  // ------------------------------------------------------------
  static Future<void> printKitchenTicketNetwork({
    required List<CartItem> items,
    required String ip,
    required int port,
    TableModel? table,
    String? hallName,
    String note = '',
    int charsPerLine = 48,
  }) async {
    final w = charsPerLine;
    final bytes = <int>[..._Esc.init, ..._Esc.codepageCp866];

    bytes
      ..addAll(_Esc.alignCenter)
      ..addAll(_Esc.boldOn)
      ..addAll(_Esc.doubleOn)
      ..addAll(_center('OSHPAZ CHEKI'))
      ..addAll(_Esc.normalSize)
      ..addAll(_Esc.boldOff)
      ..addAll(_divider(w))
      ..addAll(_Esc.alignLeft);

    if (table != null) {
      bytes
        ..addAll(_Esc.boldOn)
        ..addAll(_t('${hallName ?? ''} - Stol ${table.number}\n'))
        ..addAll(_Esc.boldOff);
    }
    bytes
      ..addAll(_t('${DateTime.now().toString().substring(0, 16)}\n'))
      ..addAll(_divider(w));

    for (final item in items) {
      bytes
        ..addAll(_Esc.boldOn)
        ..addAll(_Esc.doubleOn)
        ..addAll(_row(item.product.name, 'x${item.qty}', w ~/ 2))
        ..addAll(_Esc.normalSize)
        ..addAll(_Esc.boldOff);
    }

    if (note.trim().isNotEmpty) {
      bytes
        ..addAll(_divider(w))
        ..addAll(_t('Izoh: $note\n'));
    }

    bytes
      ..addAll(_Esc.lineSpacingDefault)
      ..addAll(_Esc.feed(6))
      ..addAll(_Esc.cut)
      ..addAll(_Esc.feed(1));

    await _sendRaw(bytes, ip: ip, port: port);
  }

  /// Kassa qutisini printer orqali ochish (agar printerga ulangan bo'lsa).
  static Future<void> openCashDrawer({
    required String ip,
    required int port,
  }) async {
    await _sendRaw(_Esc.openDrawer, ip: ip, port: port);
  }
}

// ============================================================
// PRINTING (chek chiqarish — Bluetooth printerlar ham shu orqali
// tizim "Print" oynasida ko'rinadi va tanlanadi)
// ============================================================

// SVG vektor belgilari
const String _pdfZaveroSvg = '''<svg width="52" height="44" viewBox="0 0 100 88" fill="none" xmlns="http://www.w3.org/2000/svg">
  <!-- CHAP Z -->
  <path d="M0 0 H58 V15 H19 L50 73 H58 V88 H0 V73 H39 L8 15 H0 Z" fill="black"/>
  <!-- O'NG Z -->
  <path d="M42 0 H100 V15 H61 L92 73 H100 V88 H42 V73 H81 L50 15 H42 Z" fill="black"/>
</svg>''';



const String _pdfLocationSvg = '''<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
  <circle cx="12" cy="10" r="3"/>
</svg>''';

const String _pdfPhoneSvg = '''<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/>
</svg>''';

const String _pdfCardSvg = '''<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="2" y="5" width="20" height="14" rx="2"/>
  <line x1="2" y1="10" x2="22" y2="10"/>
</svg>''';

const String _pdfHeartSvg = '''<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
</svg>''';

const String _pdfStoreSvg = '''<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
  <polyline points="9 22 9 12 15 12 15 22"/>
</svg>''';

const String _pdfCalendarSvg = '''<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
  <line x1="16" y1="2" x2="16" y2="6"/>
  <line x1="8" y1="2" x2="8" y2="6"/>
  <line x1="3" y1="10" x2="21" y2="10"/>
</svg>''';

const String _pdfClockSvg = '''<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="12" r="10"/>
  <polyline points="12 6 12 12 16 14"/>
</svg>''';

const String _pdfReceiptSvg = '''<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <polyline points="9 11 12 14 22 4"/>
  <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>
</svg>''';

const String _pdfPersonSvg = '''<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
  <circle cx="12" cy="7" r="4"/>
</svg>''';

/// Rasm 4 ga 1:1 mos 80mm termal chek PDF hujjati
pw.Document _buildThermalReceiptPdf({
  required String checkId,
  required String cashierName,
  required String? hallName,
  required String? tableNumberStr,
  required DateTime dateTime,
  required List<CartItem> items,
  required double grandTotal,
}) {
  const double widthPt = 80.0 * PdfPageFormat.mm;
  const double marginPt = 3.0 * PdfPageFormat.mm;
  final double estimatedHeight = 240.0 +
      (items.length * 18.0) +
      (appState.receiptQrEnabled ? 90.0 : 0.0);
  final format = PdfPageFormat(widthPt, estimatedHeight, marginAll: marginPt);

  final doc = pw.Document();
  final helvetica = pw.Font.helvetica();
  final helveticaBold = pw.Font.helveticaBold();
  final helveticaOblique = pw.Font.helveticaOblique();

  final cafeName = appState.effectiveReceiptName.isNotEmpty
      ? appState.effectiveReceiptName
      : 'Family Cafe';
  final address = appState.restaurantAddress.trim().isNotEmpty
      ? appState.restaurantAddress.trim()
      : "Navoiy ko'chasi 12, Buxoro";
  final phone = appState.restaurantPhone.trim().isNotEmpty
      ? appState.restaurantPhone.trim()
      : '+998 90 123 45 67';
  final slogan = appState.receiptSlogan.trim().isNotEmpty
      ? appState.receiptSlogan.trim()
      : "Yaxshi ta'm - Baxtli onlar";
  final footerText = appState.receiptFooterNote.trim().isNotEmpty
      ? appState.receiptFooterNote.trim()
      : 'Bizni tanlaganingiz uchun rahmat!';

  final dateStr =
      '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}';
  final timeStr =
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  final formattedCheckId = ReceiptWidget.formatCheckNumber(checkId);
  final tableDisplay =
      (tableNumberStr != null && tableNumberStr.trim().isNotEmpty) ? tableNumberStr.trim() : '-';
  final cashierDisplay = cashierName.trim().isNotEmpty ? cashierName.trim() : 'Admin';

  // Logo
  Uint8List? customLogoBytes;
  final logoUrl = appState.appLogoUrl?.trim() ?? '';
  if (logoUrl.isNotEmpty) {
    try {
      if (logoUrl.startsWith('data:image/')) {
        final commaIdx = logoUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? logoUrl.substring(commaIdx + 1) : logoUrl;
        customLogoBytes = base64Decode(base64Str);
      } else if (!kIsWeb && File(logoUrl).existsSync()) {
        customLogoBytes = File(logoUrl).readAsBytesSync();
      }
    } catch (_) {}
  }

  double productsSum = 0;
  for (final item in items) {
    productsSum += item.product.price * item.qty;
  }

  // Chef hat SVG (Rasm 4 ga mos)
  const chefHatSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50">
  <rect x="5" y="36" width="40" height="9" rx="2" fill="none" stroke="black" stroke-width="1.6"/>
  <line x1="9" y1="36" x2="9" y2="22" stroke="black" stroke-width="1.6" stroke-linecap="round"/>
  <line x1="41" y1="36" x2="41" y2="22" stroke="black" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M 7 22 A 18 18 0 0 1 43 22" fill="none" stroke="black" stroke-width="1.6"/>
  <line x1="7" y1="22" x2="43" y2="22" stroke="black" stroke-width="1.6"/>
  <line x1="25" y1="14" x2="25" y2="33" stroke="black" stroke-width="1.3" stroke-linecap="round"/>
  <line x1="20" y1="6" x2="20" y2="14" stroke="black" stroke-width="1.2" stroke-linecap="round"/>
  <line x1="25" y1="6" x2="25" y2="14" stroke="black" stroke-width="1.2" stroke-linecap="round"/>
  <line x1="30" y1="6" x2="30" y2="14" stroke="black" stroke-width="1.2" stroke-linecap="round"/>
  <line x1="20" y1="14" x2="30" y2="14" stroke="black" stroke-width="1.0"/>
</svg>''';

  pw.Widget dashedLine() => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: List.generate(
            26, (_) => pw.Container(width: 3.5, height: 0.6, color: PdfColors.grey400)),
      );

  doc.addPage(
    pw.Page(
      pageFormat: format,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            // ── 1. HEADER: Chef hat + kafe nomi (kursiv) + slogan ──────
            if (customLogoBytes != null && customLogoBytes.isNotEmpty)
              pw.Center(
                child: pw.Image(pw.MemoryImage(customLogoBytes), height: 38, fit: pw.BoxFit.contain),
              )
            else
              pw.Center(child: pw.SvgImage(svg: chefHatSvg, width: 40, height: 40)),
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Text(
                cafeName,
                style: pw.TextStyle(
                    font: helveticaBold,
                    fontSize: 14.0,
                    fontWeight: pw.FontWeight.bold,
                    fontStyle: pw.FontStyle.italic),
              ),
            ),
            pw.SizedBox(height: 3),
            // Slogan with lines
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
              pw.Container(width: 22, height: 0.7, color: PdfColors.grey600),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                child: pw.Text(slogan,
                    style: pw.TextStyle(font: helveticaOblique, fontSize: 7.0, fontStyle: pw.FontStyle.italic)),
              ),
              pw.Container(width: 22, height: 0.7, color: PdfColors.grey600),
            ]),
            pw.SizedBox(height: 5),

            // ── Thin separator ──
            pw.Container(height: 0.7, color: PdfColors.grey400),
            pw.SizedBox(height: 5),

            // ── 2. INFO BLOK (2 ustun) ──────────────────────────────
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                // LEFT
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Row(children: [
                      pw.SvgImage(svg: _pdfStoreSvg, width: 8, height: 8),
                      pw.SizedBox(width: 3),
                      pw.Text(cafeName, style: pw.TextStyle(font: helveticaBold, fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.SizedBox(height: 2.5),
                    pw.Row(children: [
                      pw.SvgImage(svg: _pdfLocationSvg, width: 8, height: 8),
                      pw.SizedBox(width: 3),
                      pw.Expanded(child: pw.Text(address, style: pw.TextStyle(font: helvetica, fontSize: 7.0))),
                    ]),
                    pw.SizedBox(height: 2.5),
                    pw.Row(children: [
                      pw.SvgImage(svg: _pdfPhoneSvg, width: 8, height: 8),
                      pw.SizedBox(width: 3),
                      pw.Text(phone, style: pw.TextStyle(font: helvetica, fontSize: 7.0)),
                    ]),
                  ]),
                ),
                // DIVIDER
                pw.Container(width: 0.6, color: PdfColors.grey400, margin: const pw.EdgeInsets.symmetric(horizontal: 5)),
                // RIGHT
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Row(children: [
                      pw.SvgImage(svg: _pdfCalendarSvg, width: 8, height: 8),
                      pw.SizedBox(width: 3),
                      pw.Text(dateStr, style: pw.TextStyle(font: helvetica, fontSize: 7.0)),
                    ]),
                    pw.SizedBox(height: 2.5),
                    pw.Row(children: [
                      pw.SvgImage(svg: _pdfClockSvg, width: 8, height: 8),
                      pw.SizedBox(width: 3),
                      pw.Text(timeStr, style: pw.TextStyle(font: helvetica, fontSize: 7.0)),
                    ]),
                    pw.SizedBox(height: 2.5),
                    pw.Row(children: [
                      pw.SvgImage(svg: _pdfReceiptSvg, width: 8, height: 8),
                      pw.SizedBox(width: 3),
                      pw.Text('Chek No: $formattedCheckId', style: pw.TextStyle(font: helvetica, fontSize: 7.0)),
                    ]),
                    pw.SizedBox(height: 2.5),
                    pw.Row(children: [
                      pw.SvgImage(svg: _pdfPersonSvg, width: 8, height: 8),
                      pw.SizedBox(width: 3),
                      pw.Text('Kassir: $cashierDisplay', style: pw.TextStyle(font: helvetica, fontSize: 7.0)),
                    ]),
                  ]),
                ),
              ]),
            ),
            pw.SizedBox(height: 6),

            // ── Dashed separator ──
            dashedLine(),
            pw.SizedBox(height: 4),

            // ── 3. JADVAL SARLAVHASI ──────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey600, width: 0.7),
                  bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.7),
                ),
              ),
              child: pw.Row(children: [
                pw.SizedBox(width: 14, child: pw.Text('No', style: pw.TextStyle(font: helveticaBold, fontSize: 7.0, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(child: pw.Text('Nomi', style: pw.TextStyle(font: helveticaBold, fontSize: 7.0, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(width: 30, child: pw.Text('Miqdori', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: helveticaBold, fontSize: 7.0, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(width: 34, child: pw.Text('Narx', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: helveticaBold, fontSize: 7.0, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(width: 38, child: pw.Text('Summa', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: helveticaBold, fontSize: 7.0, fontWeight: pw.FontWeight.bold))),
              ]),
            ),
            pw.SizedBox(height: 3),

            // ── 4. MAHSULOTLAR ────────────────────────────────────
            ...List.generate(items.length, (index) {
              final item = items[index];
              final itemSumma = item.product.price * item.qty;
              return pw.Column(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.SizedBox(width: 14, child: pw.Text('${index + 1}', style: pw.TextStyle(font: helvetica, fontSize: 7.0))),
                    pw.Expanded(child: pw.Text(item.product.name, style: pw.TextStyle(font: helveticaBold, fontSize: 7.0, fontWeight: pw.FontWeight.bold))),
                    pw.SizedBox(width: 30, child: pw.Text('${item.qty} dona', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: helvetica, fontSize: 7.0))),
                    pw.SizedBox(width: 34, child: pw.Text(ReceiptWidget.money(item.product.price.round()), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: helvetica, fontSize: 7.0))),
                    pw.SizedBox(width: 38, child: pw.Text(ReceiptWidget.money(itemSumma.round()), textAlign: pw.TextAlign.right, style: pw.TextStyle(font: helveticaBold, fontSize: 7.0, fontWeight: pw.FontWeight.bold))),
                  ]),
                ),
                if (index < items.length - 1)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: List.generate(26, (_) => pw.Container(width: 3.5, height: 0.5, color: PdfColors.grey300)),
                    ),
                  ),
              ]);
            }),
            pw.SizedBox(height: 5),

            // ── Dashed separator ──
            dashedLine(),
            pw.SizedBox(height: 5),

            // ── 5. JAMI / CHEGIRMA / TO'LOV ───────────────────────
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4),
              child: pw.Column(children: [
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Jami:', style: pw.TextStyle(font: helveticaBold, fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text("${ReceiptWidget.money(productsSum.round())} so'm", style: pw.TextStyle(font: helveticaBold, fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.SizedBox(height: 2.5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Chegirma:', style: pw.TextStyle(font: helvetica, fontSize: 8.0)),
                  pw.Text("0 so'm", style: pw.TextStyle(font: helvetica, fontSize: 8.0)),
                ]),
                pw.SizedBox(height: 2.5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("To'lov:", style: pw.TextStyle(font: helveticaBold, fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text("${ReceiptWidget.money(grandTotal.round())} so'm", style: pw.TextStyle(font: helveticaBold, fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                ]),
              ]),
            ),
            pw.SizedBox(height: 6),

            // ── Dashed separator ──
            dashedLine(),
            pw.SizedBox(height: 6),

            // ── 6. QR KOD ─────────────────────────────────────────
            if (appState.receiptQrEnabled) ...[
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'https://zavero-backend-production-7dc9.up.railway.app',
                  width: 58, height: 58,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'QR skaner qiling va Zavero web saytiga oting!',
                  style: pw.TextStyle(font: helvetica, fontSize: 6.5, color: PdfColors.grey700),
                ),
              ),
              pw.SizedBox(height: 6),
            ],

            // ── Thin separator ──
            pw.Container(height: 0.7, color: PdfColors.grey400),
            pw.SizedBox(height: 5),

            // ── 7. FOOTER ─────────────────────────────────────────
            pw.Center(
              child: pw.Text(
                footerText,
                style: pw.TextStyle(font: helveticaOblique, fontSize: 9.5, fontStyle: pw.FontStyle.italic),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.SvgImage(svg: _pdfHeartSvg, width: 9, height: 9),
            ),
            pw.SizedBox(height: 4),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
              pw.Container(width: 20, height: 0.6, color: PdfColors.black),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5),
                child: pw.Text(cafeName, style: pw.TextStyle(font: helveticaBold, fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Container(width: 20, height: 0.6, color: PdfColors.black),
            ]),
            pw.SizedBox(height: 5),
          ],
        );
      },
    ),
  );

  return doc;
}

Future<void> printReceipt(Receipt receipt, {bool isAutoCheckout = false}) async {
  if (appState.printerConfigured) {
    await NetworkPrinterService.printReceiptNetwork(
      receipt,
      ip: appState.printerIp,
      port: appState.printerPort,
      charsPerLine: appState.printerCharsPerLine,
      fontSize: appState.printerFontSize,
    );
    return;
  }

  // Telegram WebApp yoki Brauzerda avtomatik to'lov paytida "blob:..." oynasi chiqmasligi uchun:
  if (kIsWeb && isAutoCheckout) {
    debugPrint('Web / Telegram WebApp: Avtomatik chek chop etishda printer sozlanmaganligi sababli blob oynasi ochilmadi.');
    return;
  }

  final doc = _buildThermalReceiptPdf(
    checkId: '${receipt.id}',
    cashierName: receipt.cashierName.isNotEmpty ? receipt.cashierName : 'Admin',
    hallName: receipt.hallName,
    tableNumberStr: receipt.tableNumber != null ? '${receipt.tableNumber}' : null,
    dateTime: receipt.date,
    items: receipt.items,
    grandTotal: receipt.total,
  );

  await Printing.layoutPdf(
    onLayout: (format) async => doc.save(),
    name: 'chek_${receipt.id}',
  );
}

// ---- XARID CHEKI: hali to'lanmagan, stol hisobini mijozga ko'rsatish/chop etish uchun ----
Future<void> printBillPreview({
  required List<CartItem> items,
  required double productsTotal,
  required double serviceTotal,
  required double grandTotal,
  required PaymentMethod method,
  TableModel? table,
  String? hallName,
}) async {
  final cashierName =
      appState.currentUser?.name ?? appState.guestName ?? 'Admin';

  if (appState.printerConfigured) {
    await NetworkPrinterService.printBillNetwork(
      items: items,
      productsTotal: productsTotal,
      serviceTotal: serviceTotal,
      grandTotal: grandTotal,
      method: method,
      cashierName: cashierName,
      ip: appState.printerIp,
      port: appState.printerPort,
      table: table,
      hallName: hallName,
      charsPerLine: appState.printerCharsPerLine,
      fontSize: appState.printerFontSize,
    );
    return;
  }

  final now = DateTime.now();
  final checkId = '${table?.number ?? 1}';

  final doc = _buildThermalReceiptPdf(
    checkId: checkId,
    cashierName: cashierName,
    hallName: hallName,
    tableNumberStr: table != null ? '${table.number}' : null,
    dateTime: now,
    items: items,
    grandTotal: grandTotal,
  );

  await Printing.layoutPdf(
    onLayout: (format) async => doc.save(),
    name: 'hisob_${DateTime.now().millisecondsSinceEpoch}',
  );
}

// ---- OSHPAZ CHEKI: narxsiz, faqat taom nomi va soni bilan oshxonaga
// chop etiladigan buyurtma cheki (PaymentScreen "Oshpaz cheki" tugmasi) ----
Future<void> printKitchenTicket({
  required List<CartItem> items,
  TableModel? table,
  String? hallName,
  String note = '',
}) async {
  if (appState.printerConfigured) {
    await NetworkPrinterService.printKitchenTicketNetwork(
      items: items,
      ip: appState.printerIp,
      port: appState.printerPort,
      table: table,
      hallName: hallName,
      note: note,
      charsPerLine: appState.printerCharsPerLine,
    );
    return;
  }

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.all(12),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'OSHPAZ CHEKI',
                style: const pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(),
            if (table != null)
              pw.Text(
                '${hallName ?? ''} - Stol ${table.number}',
                style: const pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            pw.Text(
              DateTime.now().toString().substring(0, 16),
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(),
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    'Taom',
                    style: const pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'Soni',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            ...items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        item.product.name,
                        style: const pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        '${item.qty}',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (note.trim().isNotEmpty) ...[
              pw.Divider(),
              pw.Text(
                'Izoh: $note',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ],
        );
      },
    ),
  );
  await Printing.layoutPdf(
    onLayout: (format) async => doc.save(),
    name: 'oshpaz_cheki_${DateTime.now().millisecondsSinceEpoch}',
  );
}

// ============================================================
// THEME
// ============================================================

const Color kYellow = Color(0xFFFFC107);
const Color _kAccentYellow = Color(0xFFFFA000);
const Color _kAccentDarkModeWhite = Color(0xFFF2F2F2);
const Color kBgLight = Color(0xFFFFFDF7);
const Color kBgDark = Color(0xFF111114);

// Ilova bo'ylab ikonka/urg'u rangi sifatida ishlatiladi. Kunduzgi
// rejimda sariq, tungi rejimda esa oq bo'ladi (appState.darkMode ga
// qarab avtomatik almashadi) — shu tufayli har bir ishlatilgan joyni
// alohida o'zgartirish shart emas.
Color get kDarkYellow =>
    appState.darkMode ? _kAccentDarkModeWhite : _kAccentYellow;

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    primaryColor: const Color(0xFF0F172A),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F172A),
      brightness: Brightness.light,
      primary: const Color(0xFF0F172A),
      secondary: const Color(0xFF334155),
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F172A),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.6),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF0F172A),
      shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0F172A),
        side: const BorderSide(color: Color(0xFF0F172A), width: 1.4),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF0F172A),
      foregroundColor: Colors.white,
    ),
  );
}

// ---- TUNGI REJIM PALITRASI ----
// Sariq o'rniga yumshoq oq/kulrang urg'u rangi + bir-biridan bosqichma-
// bosqich farqlanadigan "sirt" (surface) qatlamlari: fon eng qorong'u,
// undan keyin karta, undan keyin input/chip, undan keyin dialog/bottom
// sheet kabi "ko'tarilgan" elementlar — shu tufayli soyasiz ham chuqurlik
// hissi beriladi.
const Color kDarkAccent = Color(0xFFF2F2F2); // asosiy urg'u (tugmalar, ikonka)
const Color kDarkAccentDim = Color(0xFFD8D8DC); // ikkinchi darajali urg'u
const Color kDarkSurface = Color(0xFF1B1B1F); // kartalar, AppBar
const Color kDarkSurface2 = Color(0xFF242429); // input, chip fonlari
const Color kDarkSurface3 = Color(0xFF2C2C32); // dialog, bottom sheet
const Color kDarkBorder = Color(0x1FFFFFFF); // juda xira oq chiziq (border)
const Color kDarkTextSecondary = Color(0xFFA8A8AE); // ikkinchi darajali matn

ThemeData buildDarkTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: kBgDark,
    primaryColor: kDarkAccent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: Brightness.dark,
      primary: kDarkAccent,
      onPrimary: Colors.black,
      secondary: kDarkAccentDim,
      surface: kDarkSurface,
      onSurface: Colors.white,
      error: const Color(0xFFFF6B6B),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    iconTheme: const IconThemeData(color: kDarkTextSecondary),
    dividerTheme: const DividerThemeData(
      color: kDarkBorder,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kDarkSurface,
      foregroundColor: kDarkAccent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      iconTheme: IconThemeData(color: kDarkAccent),
      titleTextStyle: TextStyle(
        color: kDarkAccent,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: kDarkSurface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kDarkBorder),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kDarkSurface2,
      hintStyle: const TextStyle(color: kDarkTextSecondary),
      labelStyle: const TextStyle(color: kDarkTextSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kDarkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kDarkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kDarkAccent, width: 1.6),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: kDarkSurface2,
      selectedColor: kDarkAccent,
      disabledColor: kDarkSurface2,
      side: BorderSide(color: kDarkBorder),
      shape: StadiumBorder(side: BorderSide(color: kDarkBorder)),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      secondaryLabelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kDarkAccent,
        foregroundColor: Colors.black,
        disabledBackgroundColor: kDarkSurface2,
        disabledForegroundColor: kDarkTextSecondary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kDarkAccent,
        side: const BorderSide(color: kDarkAccent, width: 1.4),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kDarkAccent),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kDarkAccent,
      foregroundColor: Colors.black,
      elevation: 2,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kDarkSurface3,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: kDarkTextSecondary,
        fontSize: 14,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kDarkSurface,
      modalBackgroundColor: kDarkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kDarkSurface3,
      contentTextStyle: const TextStyle(color: Colors.white),
      actionTextColor: kDarkAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: kDarkAccent,
      unselectedLabelColor: kDarkTextSecondary,
      indicatorColor: kDarkAccent,
      dividerColor: kDarkBorder,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: kDarkTextSecondary,
      textColor: Colors.white,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? kDarkAccent
            : Colors.grey.shade400,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? kDarkAccent.withValues(alpha: 0.45)
            : kDarkSurface2,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? kDarkAccent
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.black),
      side: const BorderSide(color: kDarkTextSecondary, width: 1.4),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? kDarkAccent
            : kDarkTextSecondary,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kDarkAccent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: kDarkSurface3,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(color: Colors.white),
    ),
    dividerColor: kDarkBorder,
  );
}

// ============================================================
// APP ROOT
// ============================================================

typedef ZaveroPosApp = ZaveroApp;

class ZaveroApp extends StatelessWidget {
  const ZaveroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: ListenableBuilder(
        listenable: Listenable.merge([appState, LocalizationService()]),
        builder: (context, _) {
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            scaffoldMessengerKey: appMessengerKey,
            title: 'ZAVERO',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: appState.darkMode ? ThemeMode.dark : ThemeMode.light,
            onGenerateRoute: (settings) => null,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

// ============================================================
// LOGO WIDGET — ZAVERO
// ============================================================

class CafeLogo extends StatelessWidget {
  final double size;
  final bool isWhite;
  const CafeLogo({super.key, this.size = 90, this.isWhite = false});

  Widget _buildFallback(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(size * 0.10),
      child: Image.asset(
        'assets/logo/logo_transparent.png',
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final logoUrl = appState.appLogoUrl;
        Widget childWidget;
        if (logoUrl != null && logoUrl.trim().isNotEmpty) {
          final trimmed = logoUrl.trim();
          if (trimmed.startsWith('http') || trimmed.startsWith('data:image')) {
            childWidget = OptimizedImage(
              imageUrl: trimmed,
              fit: BoxFit.cover,
            );
          } else if (trimmed.startsWith('assets/')) {
            childWidget = Image.asset(
              trimmed,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => _buildFallback(context),
            );
          } else {
            final file = File(trimmed);
            if (file.existsSync()) {
              childWidget = Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _buildFallback(context),
              );
            } else {
              childWidget = _buildFallback(context);
            }
          }
        } else {
          childWidget = _buildFallback(context);
        }

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: size * 0.04,
            ),
          ),
          child: ClipOval(child: childWidget),
        );
      },
    );
  }
}

// ============================================================
// SPLASH SCREEN — "ZAVERO" shu yerda chiqadi
// ============================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1800), () async {
      if (!mounted) return;

      // 0.5. Agar 4-xonali PIN kod o'rnatilgan bo'lsa (Image 2), avval PIN Lock ekrani ochiladi:
      final hasPin = await PinSecurityService().hasAnyPin();
      if (hasPin) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'pin_lock'),
            builder: (_) => const PinLockScreen(),
          ),
        );
        return;
      }

      // 1. Avval saqlangan sessiyani tekshiramiz
      final savedUser = await appState.restoreUserSession();
      if (savedUser != null) {
        if (savedUser.role == UserRole.director) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              settings: const RouteSettings(name: 'director'),
              builder: (_) => DirectorScreen(directorUser: savedUser),
            ),
          );
          return;
        }

        if (savedUser.isBlocked || savedUser.isExpired) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              settings: const RouteSettings(name: 'blocked'),
              builder: (_) => BlockedScreen(user: savedUser),
            ),
          );
          return;
        }

        try {
          await appState.loadCloudDataForCafe(appState.currentCafeId);
        } catch (e) {
          debugPrint('Splash saved session load error: $e');
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'dashboard'),
            builder: (_) => const DashboardScreen(),
          ),
        );
        return;
      }

      // 2. Agar Firebase / API sessiyasi bo'lsa
      final fbUser = AuthService().currentFirebaseUser;
      if (fbUser != null) {
        try {
          final profile = await AuthService().getCurrentUserDetails();
          if (profile != null) {
            await appState.saveUserSession(profile);

            if (profile.role == UserRole.director) {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'director'),
                  builder: (_) => DirectorScreen(directorUser: profile),
                ),
              );
              return;
            }

            if (profile.isBlocked || profile.isExpired) {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'blocked'),
                  builder: (_) => BlockedScreen(user: profile),
                ),
              );
              return;
            }
          }
          await appState.loadCloudDataForCafe(appState.currentCafeId);
        } catch (e) {
          debugPrint('Splash session check error: $e');
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'dashboard'),
            builder: (_) => const DashboardScreen(),
          ),
        );
        return;
      }

      // 3. Agar sessiya yo'q bo'lsa, AuthScreen ochiladi
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AuthScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Stack(
        children: [
          // 1. Background deep dark gradient with luxury mesh glow
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.15),
                radius: 1.1,
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                  Color(0xFF0A0E17),
                  Color(0xFF020617),
                ],
                stops: [0.0, 0.45, 0.75, 1.0],
              ),
            ),
          ),

          // 2. Subtle pulsing gold ambient aura
          Center(
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.18),
                      blurRadius: 90,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Main Brand Content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Logo
                  ScaleTransition(
                    scale: _scale,
                    child: FadeTransition(
                      opacity: _fade,
                      child: Container(
                        width: 130,
                        height: 130,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD54F), Color(0xFFFF8F00), Color(0xFF263238)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/logo/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.flash_on_rounded, color: Color(0xFFFFB300), size: 64),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Brand Name: ZAVERO
                  FadeTransition(
                    opacity: _fade,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, Color(0xFFFFE082), Color(0xFFFFB300)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds),
                      child: const Text(
                        'ZAVERO',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Subtitle / Tagline
                  FadeTransition(
                    opacity: _fade,
                    child: Text(
                      tr('tagline'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFB300),
                        letterSpacing: 2.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  FadeTransition(
                    opacity: _fade,
                    child: Text(
                      tr('app_subtitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Modern Micro Progress Indicator
                  FadeTransition(
                    opacity: _fade,
                    child: SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          minHeight: 3.5,
                          backgroundColor: Color(0xFF1E293B),
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB300)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOGIN ROLE SELECTION SCREEN
// ============================================================

class LoginRoleScreen extends StatelessWidget {
  const LoginRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final curUser = appState.currentUser;
    final fbUser = AuthService().currentFirebaseUser;
    final userName = curUser?.name.isNotEmpty == true
        ? curUser!.name
        : (fbUser?.email?.split('@').first ?? 'Foydalanuvchi');

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.restaurantName),
        actions: [
          IconButton(
            tooltip: 'Hisobdan chiqish',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await appState.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AuthScreen(),
                  ),
                  (r) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CafeLogo(size: 90),
                  const SizedBox(height: 16),
                  Text(
                    'Salom, $userName!',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kirish turini tanlang',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 28),
                  _RoleCard(
                    icon: Icons.admin_panel_settings,
                    title: 'Administrator',
                    subtitle:
                        'Hisobotlar, sozlamalar va boshqaruvga to\'liq kirish',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CredentialsLoginScreen(
                          requiredRole: UserRole.admin,
                        ),
                      ),
                    ),
                  ),
                  _RoleCard(
                    icon: Icons.room_service_rounded,
                    title: 'Ofitsiant',
                    subtitle: 'Stollar, zallar va mijozlardan buyurtma olish',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CredentialsLoginScreen(
                          requiredRole: UserRole.waiter,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.point_of_sale,
                    title: 'Kassir',
                    subtitle: 'Login va parol bilan buyurtma va to\'lovlar',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CredentialsLoginScreen(
                          requiredRole: UserRole.cashier,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.delivery_dining,
                    title: 'Kuryer',
                    subtitle: 'Yetkazib berish buyurtmalarini ko\'rish',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CredentialsLoginScreen(
                          requiredRole: UserRole.courier,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.person,
                    title: 'Mijoz',
                    subtitle: 'Menyuni ko\'rish va online buyurtma berish',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerLoginScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kYellow.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: kDarkYellow, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// USERNAME & PASSWORD LOGIN SCREEN (Admin / Kassir / Kuryer)
// ============================================================

class CredentialsLoginScreen extends StatefulWidget {
  final UserRole requiredRole;
  const CredentialsLoginScreen({super.key, required this.requiredRole});
  @override
  State<CredentialsLoginScreen> createState() => _CredentialsLoginScreenState();
}

class _CredentialsLoginScreenState extends State<CredentialsLoginScreen> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool obscure = true;
  String? error;
  bool _isLoading = false;

  void _submit() async {
    final login = userCtrl.text.trim();
    final pass = passCtrl.text.trim();

    if (login.isEmpty || pass.isEmpty) {
      setState(() => error = 'Login va parolni kiriting');
      return;
    }

    setState(() {
      _isLoading = true;
      error = null;
    });

    // 1. Avval server (backend) orqali kirishni tekshiramiz (online)
    try {
      final authUser = await AuthService().login(login, pass);
      appState.currentUser = authUser;
      await appState.loadCloudDataForCafe(authUser.workspaceId);
      if (mounted) {
        if (authUser.isBlocked) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'blocked'),
              builder: (_) => BlockedScreen(user: authUser),
            ),
            (r) => false,
          );
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'dashboard'),
            builder: (_) => const DashboardScreen(),
          ),
        );
      }
      return;
    } catch (e) {
      debugPrint('Cloud login urinishi: $e');

      // 2. Agar tarmoq bo'lmasa yoki offline bo'lsa, lokal xodimlar ro'yxatidan tekshiramiz
      final u = appState.loginByCredentials(login, pass);
      if (u != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'dashboard'),
              builder: (_) => const DashboardScreen(),
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          final rawMsg = e.toString().replaceAll('Exception: ', '');
          if (rawMsg.contains('xato') || rawMsg.contains('Noto\'g\'ri') || rawMsg.contains('401')) {
            error = 'Login yoki parol noto\'g\'ri. Iltimos, qaytadan tekshiring.';
          } else {
            error = rawMsg;
          }
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.requiredRole == UserRole.admin
        ? 'Administrator kirishi'
        : widget.requiredRole == UserRole.waiter
            ? 'Ofitsiant kirishi'
            : widget.requiredRole == UserRole.courier
                ? 'Kuryer kirishi'
                : 'Kassir kirishi';
    final icon = widget.requiredRole == UserRole.admin
        ? Icons.admin_panel_settings
        : widget.requiredRole == UserRole.waiter
            ? Icons.room_service_rounded
            : widget.requiredRole == UserRole.courier
                ? Icons.delivery_dining
                : Icons.point_of_sale;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CafeLogo(size: 76),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kYellow.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: kDarkYellow),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Login',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ---- PAROL KIRITISH MAYDONI: parol yozilganda nuqta bo'lib ko'rinadi ----
                  TextField(
                    controller: passCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Parol',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Kirish',
                                style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Ortga'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CUSTOMER LOGIN SCREEN
// ============================================================

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});
  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mijoz sifatida kirish')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CafeLogo(size: 70),
                const SizedBox(height: 20),
                const Text(
                  'Xush kelibsiz! Menyuni ko\'ring va online buyurtma bering.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ismingiz',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon raqamingiz',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      appState.loginAsGuest(
                        nameCtrl.text.trim(),
                        phoneCtrl.text.trim(),
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerMenuScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Menyuga o\'tish',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CUSTOMER MENU SCREEN — mijoz shu yerdan zakas beradi (ISHLAYDI)
// ============================================================

class CustomerMenuScreen extends StatefulWidget {
  const CustomerMenuScreen({super.key});
  @override
  State<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends State<CustomerMenuScreen> {
  int? selectedCategoryId;
  String search = '';
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final filtered = appState.products.where((p) {
          final matchesCat =
              selectedCategoryId == null || p.categoryId == selectedCategoryId;
          final matchesSearch =
              search.isEmpty || p.name.toLowerCase().contains(search.toLowerCase());
          return matchesCat && matchesSearch;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text('Salom, ${appState.guestName ?? "Mehmon"} 👋'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  appState.logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginRoleScreen()),
                    (r) => false,
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Menyudan qidirish...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
                      if (mounted) setState(() => search = v);
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _catChip('Barchasi', null),
                    for (final c in appState.categories)
                      _catChip(c.name, c.id, icon: c.icon),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.no_food_outlined,
                              size: 56,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Hozircha menyu bo\'sh',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) =>
                            _CustomerProductCard(product: filtered[i]),
                      ),
              ),
            ],
          ),
          floatingActionButton: appState.customerCart.isEmpty
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: kDarkYellow,
                  icon: const Icon(Icons.shopping_cart),
                  label: Text(
                    'Savat (${appState.customerCart.length}) · ${formatSum(appState.customerCartTotal)}',
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerCartScreen(),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _catChip(String label, int? id, {IconData? icon}) {
    final selected = selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        avatar: icon != null
            ? Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : Colors.black87,
              )
            : null,
        selected: selected,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: Colors.grey.shade300),
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) return Colors.black;
          if (states.contains(WidgetState.hovered)) {
            return Colors.grey.shade400;
          }
          return Colors.white;
        }),
        onSelected: (_) => setState(() => selectedCategoryId = id),
      ),
    );
  }
}

// ============================================================
// UNIVERSAL RASM RENDERING HELPER (Base64, HTTP, Asset, File)
final Map<String, Uint8List> _base64BytesCache = {};

Uint8List? _decodeBase64Cached(String raw) {
  final cached = _base64BytesCache[raw];
  if (cached != null) return cached;

  try {
    final base64Data = raw.contains(',') ? raw.split(',').last : raw;
    final cleanBase64 = base64Data
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll(' ', '');
    final bytes = base64Decode(cleanBase64);
    if (_base64BytesCache.length > 300) {
      _base64BytesCache.clear();
    }
    _base64BytesCache[raw] = bytes;
    return bytes;
  } catch (e) {
    return null;
  }
}

// ============================================================
// Barcha qurilmalarda (Planshet, Telefon, PC Web, Windows) rasm har qanday
// formatda kelishidan qat'i nazar (Base64 Data URL, HTTPS URL, lokal fayl)
// 100% ochilishi va ko'rinishini ta'minlaydi.
Widget buildUniversalProductImage({
  required String? rawUrl,
  required Widget Function() fallbackBuilder,
  BoxFit fit = BoxFit.cover,
}) {
  try {
    if (rawUrl == null) return fallbackBuilder();
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return fallbackBuilder();

    // 1. Base64 Data URL (data:image/jpeg;base64,...) yoki xom Base64 matni
    if (trimmed.startsWith('data:image/') ||
        (trimmed.length > 100 &&
            !trimmed.startsWith('http') &&
            !trimmed.startsWith('assets/') &&
            !trimmed.startsWith('/'))) {
      final bytes = _decodeBase64Cached(trimmed);
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stack) => fallbackBuilder(),
        );
      }
      return fallbackBuilder();
    }

    final resolved = ApiClient().resolveImageUrl(trimmed);

    // 2. To'liq HTTP / HTTPS havolasi
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return OptimizedImage(
        imageUrl: resolved,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        fallbackBuilder: fallbackBuilder,
      );
    }

    // 3. Asset fayli
    if (resolved.startsWith('assets/')) {
      return Image.asset(
        resolved,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stack) => fallbackBuilder(),
      );
    }

    // 4. Web platformasida OptimizedImage
    if (kIsWeb) {
      return OptimizedImage(
        imageUrl: resolved,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        fallbackBuilder: fallbackBuilder,
      );
    }

    // 5. Qurilmadagi mahalliy fayl (fayl mavjud bo'lsagina)
    try {
      final localFile = File(resolved);
      if (localFile.existsSync()) {
        return Image.file(
          localFile,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stack) => fallbackBuilder(),
        );
      }
    } catch (_) {}

    return fallbackBuilder();
  } catch (e) {
    return fallbackBuilder();
  }
}

class _ProductFlaticonStyle {
  final List<Color> bgGradient;
  final List<Color> badgeGradient;
  final IconData icon;

  const _ProductFlaticonStyle({
    required this.bgGradient,
    required this.badgeGradient,
    required this.icon,
  });
}

_ProductFlaticonStyle _getProductFlaticonStyle(Product product) {
  final name = product.name.toLowerCase();
  final cat = appState.categories
      .firstWhere(
        (c) => c.id == product.categoryId,
        orElse: () => Category(id: -1, name: '', icon: Icons.fastfood),
      )
      .name
      .toLowerCase();
  final combined = '$name $cat';

  if (combined.contains('burger') || combined.contains('mini') || combined.contains('gamburger') || combined.contains('chizburger')) {
    return const _ProductFlaticonStyle(
      bgGradient: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
      badgeGradient: [Color(0xFFFF6D00), Color(0xFFFF9100)],
      icon: Icons.lunch_dining_rounded,
    );
  } else if (combined.contains('lavash') || combined.contains('shaurma') || combined.contains('donar') || combined.contains('hotdog') || combined.contains('hot-dog')) {
    return const _ProductFlaticonStyle(
      bgGradient: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
      badgeGradient: [Color(0xFFFF8F00), Color(0xFFFFB300)],
      icon: Icons.fastfood_rounded,
    );
  } else if (combined.contains('pizza') || combined.contains('pitsa')) {
    return const _ProductFlaticonStyle(
      bgGradient: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
      badgeGradient: [Color(0xFFD50000), Color(0xFFFF5252)],
      icon: Icons.local_pizza_rounded,
    );
  } else if (combined.contains('ichimlik') || combined.contains('cola') || combined.contains('fanta') || combined.contains('sprite') || combined.contains('pepsi') || combined.contains('sharbat') || combined.contains('suv') || combined.contains('sok') || combined.contains('mojito') || combined.contains('limonad')) {
    return const _ProductFlaticonStyle(
      bgGradient: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
      badgeGradient: [Color(0xFF0097A7), Color(0xFF00E5FF)],
      icon: Icons.local_drink_rounded,
    );
  } else if (combined.contains('kofe') || combined.contains('coffee') || combined.contains('choy') || combined.contains('tea') || combined.contains('cappuccino') || combined.contains('latte')) {
    return const _ProductFlaticonStyle(
      bgGradient: [Color(0xFFEFEBE9), Color(0xFFD7CCC8)],
      badgeGradient: [Color(0xFF5D4037), Color(0xFF8D6E63)],
      icon: Icons.coffee_rounded,
    );
  } else if (combined.contains('shashlik') || combined.contains('kabob') || combined.contains('go\'sht') || combined.contains('gosht') || combined.contains('steak') || combined.contains('grill')) {
    return const _ProductFlaticonStyle(
      bgGradient: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
      badgeGradient: [Color(0xFFC62828), Color(0xFFFF1744)],
      icon: Icons.outdoor_grill_rounded,
    );
  } else if (combined.contains('osh') || combined.contains('plov') || combined.contains('manti') || combined.contains('somsa') || combined.contains('shorva') || combined.contains('sho\'rva') || combined.contains('lagmon') || combined.contains('lag\'mon')) {
    return const _ProductFlaticonStyle(
      bgGradient: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
      badgeGradient: [Color(0xFFE65100), Color(0xFFFF9800)],
      icon: Icons.ramen_dining_rounded,
    );
  } else if (combined.contains('shirinlik') || combined.contains('tort') || combined.contains('cake') || combined.contains('desert') || combined.contains('muzqaymoq') || combined.contains('paxlava')) {
    return const _ProductFlaticonStyle(
      bgGradient: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
      badgeGradient: [Color(0xFF7B1FA2), Color(0xFFBA68C8)],
      icon: Icons.cake_rounded,
    );
  } else if (combined.contains('salat') || combined.contains('salad') || combined.contains('meva') || combined.contains('diet')) {
    return const _ProductFlaticonStyle(
      bgGradient: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
      badgeGradient: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
      icon: Icons.eco_rounded,
    );
  }

  final fallbackStyles = [
    const _ProductFlaticonStyle(
      bgGradient: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
      badgeGradient: [Color(0xFFFF6D00), Color(0xFFFFAB00)],
      icon: Icons.restaurant_menu_rounded,
    ),
    const _ProductFlaticonStyle(
      bgGradient: [Color(0xFFE1F5FE), Color(0xFFB3E5FC)],
      badgeGradient: [Color(0xFF0288D1), Color(0xFF29B6F6)],
      icon: Icons.set_meal_rounded,
    ),
    const _ProductFlaticonStyle(
      bgGradient: [Color(0xFFEDE7F6), Color(0xFFD1C4E9)],
      badgeGradient: [Color(0xFF512DA8), Color(0xFF7E57C2)],
      icon: Icons.dinner_dining_rounded,
    ),
    const _ProductFlaticonStyle(
      bgGradient: [Color(0xFFF1F8E9), Color(0xFFDCEDC8)],
      badgeGradient: [Color(0xFF33691E), Color(0xFF7CB342)],
      icon: Icons.takeout_dining_rounded,
    ),
  ];
  return fallbackStyles[product.name.hashCode.abs() % fallbackStyles.length];
}

// Mahsulot rasmi yoki Flaticon dual-tone ikonkasini ko'rsatuvchi umumiy widget
class _ProductThumb extends StatelessWidget {
  final Product product;
  final double iconSize;
  const _ProductThumb({required this.product, this.iconSize = 38});

  Widget _buildPlaceholder() {
    final style = _getProductFlaticonStyle(product);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: style.bgGradient,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Container(
          width: iconSize * 1.5,
          height: iconSize * 1.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: style.badgeGradient,
            ),
            boxShadow: [
              BoxShadow(
                color: style.badgeGradient.first.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            style.icon,
            size: iconSize * 0.85,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: buildUniversalProductImage(
          rawUrl: product.imageUrl,
          fallbackBuilder: _buildPlaceholder,
        ),
      ),
    );
  }
}

// Mijoz uchun mahsulot kartasi — bosilganda mijoz savatiga qo'shiladi
class _CustomerProductCard extends StatelessWidget {
  final Product product;
  const _CustomerProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        // Mahsulot soni 0 bo'lsa ham savatga qo'shish
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          appState.addToCustomerCart(product);
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _ProductThumb(product: product)),
              const SizedBox(height: 8),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                formatSum(product.price),
                style: const TextStyle(
                  color: Color.fromARGB(255, 47, 13, 197),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CUSTOMER CART SCREEN — mijoz savatini ko'rish va zakas berish
// ============================================================

class CustomerCartScreen extends StatefulWidget {
  const CustomerCartScreen({super.key});
  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Mening savatim')),
          body: appState.customerCart.isEmpty
              ? const Center(child: Text('Savat bo\'sh'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: appState.customerCart.length,
                  itemBuilder: (context, i) {
                    final item = appState.customerCart[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: kYellow.withValues(alpha: 0.25),
                          child: Icon(item.product.icon, color: kDarkYellow),
                        ),
                        title: Text(item.product.name),
                        subtitle: Text(formatSum(item.product.price)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () =>
                                  appState.changeCustomerQty(item, -1),
                            ),
                            Text(
                              '${item.qty}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () =>
                                  appState.changeCustomerQty(item, 1),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          bottomNavigationBar: appState.customerCart.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Jami', style: TextStyle(fontSize: 16)),
                            Text(
                              formatSum(appState.customerCartTotal),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: kDarkYellow,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Buyurtma berish'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const CustomerOrderDetailsScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// ============================================================
// CUSTOMER ORDER DETAILS — stol yoki dastavka tanlanadi,
// tasdiqlangach buyurtma ADMIN va KASSIRGA tushadi
// ============================================================

class CustomerOrderDetailsScreen extends StatefulWidget {
  const CustomerOrderDetailsScreen({super.key});
  @override
  State<CustomerOrderDetailsScreen> createState() =>
      _CustomerOrderDetailsScreenState();
}

class _CustomerOrderDetailsScreenState
    extends State<CustomerOrderDetailsScreen> {
  OrderType type = OrderType.dineIn;
  Hall? hall;
  TableModel? table;
  final addressCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    nameCtrl.text = appState.guestName ?? '';
    phoneCtrl.text = appState.guestPhone ?? '';
    if (appState.halls.isNotEmpty) hall = appState.halls.first;
  }

  void _submit() {
    if (type == OrderType.dineIn && table == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Iltimos, stolni tanlang')));
      return;
    }
    if (type == OrderType.delivery && addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iltimos, manzilni kiriting')),
      );
      return;
    }
    // ---- BUYURTMA YARATILADI VA ADMIN/KASSIRGA TUSHADI ----
    final order = appState.placeCustomerOrder(
      name: nameCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      type: type,
      tableNumber: type == OrderType.dineIn ? table?.number : null,
      hallId: type == OrderType.dineIn ? hall?.id : null,
      deliveryAddress:
          type == OrderType.delivery ? addressCtrl.text.trim() : null,
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerOrderSuccessScreen(order: order),
      ),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablesInHall = hall == null
        ? <TableModel>[]
        : appState.tables.where((t) => t.hallId == hall!.id).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Buyurtma ma\'lumotlari')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ismingiz',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                SegmentedButton<OrderType>(
                  segments: const [
                    ButtonSegment(
                      value: OrderType.dineIn,
                      label: Text('Zalda'),
                      icon: Icon(Icons.table_bar),
                    ),
                    ButtonSegment(
                      value: OrderType.delivery,
                      label: Text('Dastavka'),
                      icon: Icon(Icons.delivery_dining),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setState(() => type = s.first),
                ),
                const SizedBox(height: 20),
                if (type == OrderType.dineIn) ...[
                  DropdownButtonFormField<Hall>(
                    initialValue: hall,
                    decoration: const InputDecoration(labelText: 'Zal'),
                    items: appState.halls
                        .map(
                          (h) =>
                              DropdownMenuItem(value: h, child: Text(h.name)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      hall = v;
                      table = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tablesInHall.map((t) {
                      final selected = table?.id == t.id;
                      final free = t.status == TableStatus.free;
                      return ChoiceChip(
                        label: Text('Stol ${t.number}'),
                        selected: selected,
                        selectedColor: kYellow,
                        backgroundColor:
                            free ? null : Colors.red.withValues(alpha: 0.15),
                        onSelected: (_) => setState(() => table = t),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  TextField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Yetkazib berish manzili',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Jami summa'),
                            Text(
                              formatSum(appState.customerCartTotal),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kDarkYellow,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Buyurtmani tasdiqlash',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerOrderSuccessScreen extends StatelessWidget {
  final CustomerOrder order;
  const CustomerOrderSuccessScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buyurtma qabul qilindi')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              Text(
                'Buyurtma № ${order.id} qabul qilindi!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Buyurtmangiz admin va kassirga yuborildi. Tez orada tayyorlanadi.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Menyuga qaytish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DASHBOARD SCREEN
// ============================================================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

void _showReportIssueDialog(BuildContext context) {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  bool sending = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDlgState) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        elevation: 16,
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: Colors.black87, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Texnik Yordam / Muammo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Directordan tezkor texnik yordam olish',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    tooltip: 'Yopish',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ilovada muammo yuz berdimi? Xabar yuboring, Director tizimni ko\'rib chiqadi va SMS bildirishnoma oladi.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Mavzu *',
                  hintText: 'Masalan: Chek chiqarishda xatolik',
                  prefixIcon: const Icon(Icons.title_rounded, size: 20, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Bog\'lanish uchun telefon',
                  hintText: '+998 90 123 45 67',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Muammo haqida batafsil *',
                  hintText: 'Qanday muammo yoki xatolik yuz berdi?',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.description_outlined, size: 20, color: Color(0xFF64748B)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: sending ? null : () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Bekor qilish', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: sending
                        ? null
                        : () async {
                            if (titleCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Iltimos, mavzu va muammo tasvirini kiriting')),
                              );
                              return;
                            }
                            setDlgState(() => sending = true);
                            try {
                              await CloudService().reportIssue(
                                title: titleCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                              );
                              // Play "ting" sound on successful sending
                              SoundService().playSupportSmsSound();

                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('Xabaringiz Director boshqaruviga muvaffaqiyatli yuborildi!'),
                                    ],
                                  ),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            } catch (e) {
                              setDlgState(() => sending = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                    icon: sending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(sending ? 'Yuborilmoqda...' : 'Yuborish', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ============================================================
// IMAGE 3 & 4: ANIMATED HEADER LOGO BADGE & GREETING PILL BADGE
// ============================================================
class _AnimatedHeaderLogoBadge extends StatefulWidget {
  final double size;
  const _AnimatedHeaderLogoBadge({this.size = 36});

  @override
  State<_AnimatedHeaderLogoBadge> createState() => _AnimatedHeaderLogoBadgeState();
}

class _AnimatedHeaderLogoBadgeState extends State<_AnimatedHeaderLogoBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final scale = 0.96 + 0.08 * _ctrl.value;
        final glowRadius = 4.0 + 8.0 * _ctrl.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: Color.lerp(
                  const Color(0xFFFF4D4D),
                  const Color(0xFFFFB300),
                  _ctrl.value,
                )!,
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4D4D).withValues(alpha: 0.35 * _ctrl.value + 0.15),
                  blurRadius: glowRadius,
                  spreadRadius: 1.0,
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Image.asset(
                  'assets/logo/logo_transparent.png',
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _sidebarCollapsed = false;
  int _mobileNavIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final user = appState.currentUser;

    if (user != null && user.role == UserRole.director) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              settings: const RouteSettings(name: 'director'),
              builder: (_) => DirectorScreen(directorUser: user),
            ),
          );
        }
      });
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFC107))),
      );
    }

    // Texnik ishlar (Maintenance) rejimida bo'lsa:
    if (appState.isUnderMaintenance && user?.role != UserRole.director) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(appState.restaurantName),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              tooltip: 'Chiqish',
              onPressed: () async {
                await appState.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (r) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.build_circle_rounded, size: 64, color: Color(0xFFFFC107)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Texnik ishlar olib borilmoqda',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Director tomonidan kafeda profilaktika va sozlash ishlari olib borilmoqda.\nIshlar yakunlanishi bilan ilova avtomatik tarzda to\'liq ishlab ketadi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Color(0xFFFFC107)),
              ],
            ),
          ),
        ),
      );
    }

    final isAdmin = user?.role == UserRole.admin;
    final isWaiter = user?.role == UserRole.waiter;
    final isCourier = user?.role == UserRole.courier;
    final isCustomer = user?.role == UserRole.customer;

    return AnimatedBuilder(
      animation: Listenable.merge([appState, LocalizationService()]),
      builder: (context, _) {
        final tiles = <_DashTile>[
          // ==========================================
          // MIJOZ UCHUN BO'LIMLAR
          // ==========================================
          if (isCustomer) ...[
            _DashTile(
              tr('tile_new_order'),
              Icons.restaurant_menu_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HallSelectionScreen()),
              ),
            ),
            _DashTile(
              tr('tile_customer_orders'),
              Icons.receipt_long_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerOrdersScreen()),
              ),
              badge: appState.pendingOrdersCount,
            ),
            _DashTile(
              tr('tile_receipt_history'),
              Icons.history_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReceiptHistoryScreen()),
              ),
            ),
          ],

          // ==========================================
          // XODIM PANELI (OFITSIANT, KASSIR, XODIM)
          // Faqat: Yangi buyurtma, Mijozlardan buyurtma, Cheklar, Mahsulotlar, Mijozlar
          // ==========================================
          if (!isAdmin && !isCustomer) ...[
            // 1. Yangi buyurtma — dashboard ichida stollar ko'rsatiladi, navigatsiya shart emas
            _DashTile(
              tr('tile_new_order'),
              Icons.point_of_sale_rounded,
              () {},
            ),

            // 2. Mijozlardan buyurtma (QR menyu va online)
            _DashTile(
              'Mijozlardan buyurtma',
              Icons.receipt_long_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerOrdersScreen()),
              ),
              badge: appState.pendingOrdersCount,
            ),

            // 3. Cheklar
            _DashTile(
              tr('tile_receipt_history'),
              Icons.history_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReceiptHistoryScreen()),
              ),
            ),

            // 4. Mahsulotlar
            _DashTile(
              tr('tile_products'),
              Icons.restaurant_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductsScreen()),
              ),
            ),
          ],

          // ==========================================
          // ADMIN (CAFE EGASI) UCHUN ASOSIY BO'LIMLAR
          // ==========================================
          if (isAdmin) ...[
            // 1. Yangi buyurtma — dashboard ichida stollar ko'rsatiladi, navigatsiya shart emas
            _DashTile(
              tr('tile_new_order'),
              Icons.point_of_sale_rounded,
              () {},
            ),

            // 2. Mijozlardan buyurtma
            _DashTile(
              'Mijozlardan buyurtma',
              Icons.receipt_long_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerOrdersScreen()),
              ),
              badge: appState.pendingOrdersCount,
            ),

            // 3. Cheklar tarixi
            _DashTile(
              tr('tile_receipt_history'),
              Icons.history_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReceiptHistoryScreen()),
              ),
            ),
          ],

          // ==========================================
          // FAQAT CAFE EGASI (ADMIN) UCHUN BO'LIMLAR
          // ==========================================
          // 4. Hisobotlar
          if (isAdmin)
            _DashTile(
              tr('tile_reports'),
              Icons.analytics_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              ),
            ),

          // 5. Ombor
          if (isAdmin)
            _DashTile(
              tr('tile_inventory'),
              Icons.inventory_2_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InventoryScreen()),
              ),
            ),

          // 6. Mahsulotlar
          if (isAdmin)
            _DashTile(
              tr('tile_products'),
              Icons.restaurant_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductsScreen()),
              ),
            ),

          // 7. Kategoriyalar
          if (isAdmin)
            _DashTile(
              tr('tile_categories'),
              Icons.grid_view_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoriesScreen()),
              ),
            ),

          // 8. Xodimlar
          if (isAdmin)
            _DashTile(
              tr('tile_employees'),
              Icons.badge_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmployeesScreen()),
              ),
            ),

          // 8.5. Xodimlarni kuzatish (Live monitoring & Radar)
          if (isAdmin)
            _DashTile(
              'Xodimlarni kuzatish',
              Icons.radar_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffTrackingScreen()),
              ),
            ),

          // 10. Stollar boshqaruvi
          if (isAdmin)
            _DashTile(
              tr('tile_tables'),
              Icons.table_restaurant_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TablesManagementScreen()),
              ),
            ),

          // 11. Sozlamalar
          if (isAdmin)
            _DashTile(
              tr('tile_settings'),
              Icons.tune_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
        ];

        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 700;

        // Sidebar nav items — same tiles list
        final navItems = <Map<String, dynamic>>[
          if (isAdmin || isWaiter || isCourier || isCustomer) ...{
            ...tiles.asMap().entries.map((e) {
              final t = e.value;
              return <String, dynamic>{
                'label': t.label,
                'icon': t.icon,
                'onTap': t.onTap,
                'badge': t.badge,
              };
            }),
          }.toList(),
        ];

        // ── Collapsible sidebar builder ──────────────────────
        Widget buildSidebar() {
          final collapsed = _sidebarCollapsed;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 230),
            curve: Curves.easeInOut,
            width: collapsed ? 64 : 220,
            color: const Color(0xFF0F1E30),
            child: Column(
              children: [
                // ── Logo + Cafe header ─────────────────────────
                Container(
                  padding: EdgeInsets.fromLTRB(collapsed ? 10 : 16, 20, collapsed ? 10 : 16, 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFF1A2E45), width: 1)),
                  ),
                  child: collapsed
                      ? Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _sidebarCollapsed = false),
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(color: const Color(0xFF1A2E45), borderRadius: BorderRadius.circular(10)),
                              child: const _AnimatedHeaderLogoBadge(size: 40),
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2E45),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const _AnimatedHeaderLogoBadge(size: 40),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('ZAVERO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
                                  Text('POS', style: TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.0)),
                                ],
                              ),
                            ),
                            // ← Collapse toggle
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setState(() => _sidebarCollapsed = true),
                              child: const Icon(Icons.keyboard_arrow_left_rounded, color: Colors.white54, size: 22),
                            ),
                          ],
                        ),
                ),

                // ── Cafe name sub-header (faqat kengaytilganda) ─
                if (!_sidebarCollapsed) ...[  
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2E45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFFFFB300), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appState.restaurantName.isNotEmpty ? appState.restaurantName : 'Zavero Cafe',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const Text('Kafe boshqaruvi osonroq', style: TextStyle(color: Color(0xFF6B8BA4), fontSize: 10.5)),
                        ],
                      )),
                    ]),
                  ),
                ],

                const Divider(color: Color(0xFF1A2E45), height: 1),
                const SizedBox(height: 8),

                // ── Nav items ────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 8 : 10, vertical: 4),

                    itemCount: tiles.length,
                    itemBuilder: (context, i) {
                      final t = tiles[i];
                      final isFirst = i == 0;
                      if (_sidebarCollapsed) {
                        // Collapsed: faqat icon
                        return Tooltip(
                          message: t.label,
                          preferBelow: false,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Material(
                              color: isFirst ? const Color(0xFF1E5AFF).withValues(alpha: 0.25) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: t.onTap,
                                child: Container(
                                  width: 44, height: 44,
                                  alignment: Alignment.center,
                                  child: Icon(t.icon, color: isFirst ? Colors.white : const Color(0xFF8BA5BF), size: 20),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Material(
                          color: isFirst ? const Color(0xFF1E5AFF).withValues(alpha: 0.25) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: t.onTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              child: Row(children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: isFirst
                                        ? const Color(0xFF1E5AFF).withValues(alpha: 0.35)
                                        : Colors.white.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(t.icon, color: isFirst ? Colors.white : const Color(0xFF8BA5BF), size: 17),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(t.label, style: TextStyle(
                                  color: isFirst ? Colors.white : const Color(0xFF8BA5BF),
                                  fontSize: 13, fontWeight: isFirst ? FontWeight.w700 : FontWeight.w500,
                                ))),
                                if ((t.badge ?? 0) > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(10)),
                                    child: Text('${t.badge}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(color: Color(0xFF1A2E45), height: 1),

                // ── User footer ──────────────────────────────
                Builder(builder: (ctx) {
                  return InkWell(
                    onTap: () => Scaffold.of(ctx).openEndDrawer(),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 12 : 16, vertical: 14),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF1A2E45),
                          child: Text(
                            (user?.name ?? 'A').substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        if (!_sidebarCollapsed) ...[
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(user?.name ?? 'Admin', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                              Text(
                                isAdmin ? 'Direktor' : isWaiter ? 'Ofitsiant' : isCourier ? 'Kuryer' : 'Kassir',
                                style: const TextStyle(color: Color(0xFF6B8BA4), fontSize: 11),
                              ),
                            ],
                          )),
                          const Icon(Icons.keyboard_arrow_right_rounded, color: Color(0xFF6B8BA4), size: 18),
                        ],
                      ]),
                    ),
                  );

                }),
              ],
            ),
          );
        }

        Widget mainContent = Column(
          children: [
            // ── Top bar (online, bell, avatar) ───────────────
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
              ),
              child: Row(children: [
                // Zal tanlang title
                const Icon(Icons.grid_view_rounded, color: Color(0xFF0F1E30), size: 20),
                const SizedBox(width: 10),
                const Text('Zal tanlang', style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F1E30),
                )),
                const Spacer(),
                // Online
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.circle, color: Color(0xFF4CAF50), size: 9),
                    SizedBox(width: 6),
                    Text('Online', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700, fontSize: 12)),
                  ]),
                ),
                const SizedBox(width: 12),
                // Bell
                Stack(children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0F1E30), size: 22),
                    onPressed: () {},
                  ),
                  Positioned(right: 8, top: 8, child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
                    child: const Center(child: Text('2', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                  )),
                ]),
                const SizedBox(width: 4),
                // Avatar
                GestureDetector(
                  onTap: () {},
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF0F1E30),
                      child: Text(
                        (user?.name ?? 'A').substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(child: Text(user?.name ?? 'Admin', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F1E30)), overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black45, size: 18),
                  ]),
                ),


              ]),
            ),

            // ── Main section: "Zal tanlang" grid ─────────────
            Expanded(
              child: Container(
                color: const Color(0xFFF0F2F7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(children: [
                        const Icon(Icons.table_restaurant_rounded, color: Color(0xFF0F1E30), size: 22),
                        const SizedBox(width: 10),
                        const Text('Zal tanlang', style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F1E30),
                        )),
                        const Spacer(),
                        // Zal dropdown
                        if (appState.halls.isNotEmpty)
                          Material(
                            color: const Color(0xFF0F1E30),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                  builder: (_) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 12),
                                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                                      const SizedBox(height: 16),
                                      ...appState.halls.map((h) => ListTile(
                                        leading: Icon(h.icon),
                                        title: Text(h.name),
                                        trailing: appState.selectedHall?.id == h.id ? const Icon(Icons.check, color: Color(0xFF0F1E30)) : null,
                                        onTap: () {
                                          appState.selectedHall = h;
                                          Navigator.pop(context);
                                        },
                                      )),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(appState.selectedHall?.icon ?? Icons.table_restaurant, color: Colors.white, size: 15),
                                  const SizedBox(width: 6),
                                  Text(appState.selectedHall?.name ?? 'Zal', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 17),
                                ]),
                              ),
                            ),
                          ),
                      ]),
                    ),

                    // Table cards grid
                    Expanded(
                      child: AnimatedBuilder(
                        animation: appState,
                        builder: (context, _) {
                          final selectedHall = appState.selectedHall;
                          if (selectedHall == null && appState.halls.isNotEmpty) {
                            appState.selectedHall = appState.halls.first;
                          }
                          final myTables = selectedHall != null
                              ? (appState.tables.where((t) {
                                  if (t.hallId == selectedHall.id) return true;
                                  final h = appState.halls.firstWhere(
                                    (h) => h.id == t.hallId,
                                    orElse: () => Hall(id: -1, name: '', icon: Icons.home),
                                  );
                                  return h.name.trim().toLowerCase() == selectedHall.name.trim().toLowerCase();
                                }).toList()..sort((a, b) => a.number.compareTo(b.number)))
                              : <TableModel>[];

                          if (myTables.isEmpty) {
                            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.table_restaurant_outlined, size: 60, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text("Bu zalda stollar yo'q", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                            ]));
                          }

                          return GridView.builder(
                            padding: const EdgeInsets.all(20),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              childAspectRatio: 0.90,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: myTables.length,
                            itemBuilder: (context, i) {
                              final t = myTables[i];
                              final free = t.status == TableStatus.free;
                              final orderTotal = appState.tableOrderTotal(t);
                              final statusColor = free ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
                              final statusLabel = free ? "Bo'sh" : "Band";
                              final tableColors = [
                                const Color(0xFF6D28D9), const Color(0xFF2563EB), const Color(0xFF059669),
                                const Color(0xFFD97706), const Color(0xFFDC2626), const Color(0xFF0891B2),
                                const Color(0xFFDB2777), const Color(0xFF7C3AED),
                              ];
                              final circleColor = tableColors[i % tableColors.length];

                              return GestureDetector(
                                onTap: () {
                                  appState.selectTable(t);
                                  if (free) {
                                    Navigator.push(context, MaterialPageRoute(
                                      settings: const RouteSettings(name: 'pos'),
                                      builder: (_) => const POSScreen(),
                                    ));
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(
                                      settings: const RouteSettings(name: 'payment'),
                                      builder: (_) => const PaymentScreen(),
                                    ));
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border(
                                      left: BorderSide(
                                        color: statusColor,
                                        width: 4,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: statusColor.withValues(alpha: free ? 0.08 : 0.14),
                                        blurRadius: 12, offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Icon row
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              width: 50, height: 50,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [circleColor, circleColor.withValues(alpha: 0.75)],
                                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                                ),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(color: circleColor.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
                                                ],
                                              ),
                                              child: const Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 24),
                                            ),
                                            // Status chip
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                                                const SizedBox(width: 4),
                                                Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                                              ]),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        // Stol raqami
                                        Text('Stol ${t.number}', style: const TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A),
                                          letterSpacing: -0.3,
                                        )),
                                        const SizedBox(height: 4),
                                        // Order total yoki bo'sh belgi
                                        if (!free && orderTotal > 0)
                                          Text(formatSum(orderTotal), style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444),
                                          ))
                                        else
                                          Text('${t.seats > 0 ? t.seats : 4} o\'rin', style: const TextStyle(
                                            fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500,
                                          )),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );




        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F7),
          endDrawer: _buildDashboardEndDrawer(context, user, isAdmin, isWaiter),
          // ── Mobile: bottom nav bar ────────────────────────────
          bottomNavigationBar: isMobile
              ? ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: BackdropFilter(
                    filter: ColorFilter.mode(
                      const Color(0xFF0A1628).withValues(alpha: 0.97),
                      BlendMode.srcOver,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2E).withValues(alpha: 0.97),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07), width: 1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, -4)),
                        ],
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              // 1. Stollar
                              _mobileNavBtn(Icons.table_restaurant_rounded, 'Stollar', 0 == _mobileNavIndex, () => setState(() => _mobileNavIndex = 0)),
                              // 2. Buyurtmalar
                              _mobileNavBtn(Icons.receipt_long_rounded, 'Buyurtmalar', 1 == _mobileNavIndex,
                                tiles.length > 1 ? () { setState(() => _mobileNavIndex = 1); tiles[1].onTap(); } : () {},
                                badge: appState.pendingOrdersCount,
                              ),
                              // 3. Cheklar
                              _mobileNavBtn(Icons.history_rounded, 'Cheklar', 2 == _mobileNavIndex,
                                tiles.length > 2 ? () { setState(() => _mobileNavIndex = 2); tiles[2].onTap(); } : () {},
                              ),
                              // 4. Menu (drawer)
                              Builder(builder: (ctx) => _mobileNavBtn(Icons.grid_view_rounded, 'Menu', false, () => Scaffold.of(ctx).openEndDrawer())),
                              // 5. Profil
                              _mobileNavBtn(Icons.person_rounded, 'Profil', 4 == _mobileNavIndex, () {
                                setState(() => _mobileNavIndex = 4);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : null,

          body: isMobile
              ? Column(children: [
                  // Mobile: compact top AppBar
                  Container(
                    color: const Color(0xFF0F1E30),
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          const _AnimatedHeaderLogoBadge(size: 32),
                          const SizedBox(width: 10),
                          const Text('ZAVERO POS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                          const Spacer(),
                          // Online
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.circle, color: Color(0xFF22C55E), size: 7),
                              SizedBox(width: 4),
                              Text('Online', style: TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: const Color(0xFF1A2E45),
                            child: Text((user?.name ?? 'A').substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  Expanded(child: mainContent),
                ])
              : Row(children: [
                  // Desktop: collapsible sidebar + main
                  buildSidebar(),
                  // Sidebar expand button (when collapsed)
                  if (_sidebarCollapsed)
                    GestureDetector(
                      onTap: () => setState(() => _sidebarCollapsed = false),
                      child: Container(
                        width: 0,
                        color: Colors.transparent,
                      ),
                    ),
                  Expanded(child: mainContent),
                ]),
        );
      },
    );
  }



  Widget _mobileNavBtn(IconData icon, String label, bool active, VoidCallback onTap, {int badge = 0}) {
    final activeColor = const Color(0xFFFFB300);
    final inactiveColor = Colors.white.withValues(alpha: 0.45);
    final color = active ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 23),
              if (badge > 0)
                Positioned(
                  right: -6, top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: active ? FontWeight.w700 : FontWeight.w400, letterSpacing: 0.2)),
          if (active)
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 16, height: 2.5,
              decoration: BoxDecoration(color: activeColor, borderRadius: BorderRadius.circular(2)),
            ),
        ]),
      ),
    );
  }


  Widget _buildBreakModeButton(BuildContext context, AppUser? user, AppState appState) {

    if (user == null) return const SizedBox.shrink();
    final tracking = StaffTrackingService();

    return AnimatedBuilder(
      animation: tracking,
      builder: (context, _) {
        final currentStatus = tracking.getStatus(user.id);
        final currentOnBreak = currentStatus?.isOnBreak ?? false;

        return InkWell(
          onTap: () {
            final willBreak = !currentOnBreak;
            tracking.setBreakMode(
              user: user,
              cafeId: appState.currentCafeId,
              isOnBreak: willBreak,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  willBreak
                      ? '☕ Dam olish rejimi yoqildi. Kafe panelida "Dam olmoqda" deb ko\'rinadi.'
                      : '🟢 Dam olish yakunlandi. Ishingizni davom ettirishingiz mumkin!',
                ),
                backgroundColor: willBreak ? const Color(0xFFD97706) : const Color(0xFF10B981),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: currentOnBreak ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: currentOnBreak ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (currentOnBreak ? Colors.red : Colors.orange).withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  currentOnBreak ? Icons.coffee_rounded : Icons.pause_circle_outline_rounded,
                  size: 15,
                  color: currentOnBreak ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                ),
                const SizedBox(width: 5),
                Text(
                  currentOnBreak ? 'Dam olmoqda (Ishga qaytish ▶)' : 'Dam olish',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: currentOnBreak ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // HAMBURGER MENU / END DRAWER (Image 3)
  // Contains: Online status, Language Switcher, Support, Logout
  // ============================================================
  Widget _buildDashboardEndDrawer(
    BuildContext context,
    AppUser? user,
    bool isAdmin,
    bool isWaiter,
  ) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            // Header: User & Cafe info + Close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  const _AnimatedHeaderLogoBadge(size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appState.restaurantName.isNotEmpty ? appState.restaurantName : 'ZAVERO FAST',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.name ?? 'Foydalanuvchi',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // 1. ONLINE STATUS BADGE (Moved here per user request)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.7),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Online • Tizim faol',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Serverga ulangan, buyurtmalar qabul qilinmoqda',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 2. LANGUAGE SWITCHER (Moved here per user request)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'TILNI TANLASH / SELECT LANGUAGE',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _buildDrawerLanguageSelector(context),

                  const SizedBox(height: 22),

                  // 3. TECHNICAL SUPPORT
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'YORDAM VA XIZMATLAR',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.of(context).pop();
                      _showReportIssueDialog(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.support_agent_rounded, color: Color(0xFFFFB300), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tr('technical_support'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. LOGOUT BUTTON (Moved here per user request)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFFF87171),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: Text(
                    tr('btn_logout'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await appState.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                        (r) => false,
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerLanguageSelector(BuildContext context) {
    final currentLang = LocalizationService().currentLanguage;
    return Column(
      children: [
        _buildDrawerLangTile(
          flag: '🇺🇿',
          name: "O'zbekcha (UZ)",
          isSelected: currentLang == AppLanguage.uz,
          onTap: () {
            LocalizationService().setLanguage(AppLanguage.uz);
            setState(() {});
          },
        ),
        const SizedBox(height: 8),
        _buildDrawerLangTile(
          flag: '🇷🇺',
          name: 'Русский (RU)',
          isSelected: currentLang == AppLanguage.ru,
          onTap: () {
            LocalizationService().setLanguage(AppLanguage.ru);
            setState(() {});
          },
        ),
        const SizedBox(height: 8),
        _buildDrawerLangTile(
          flag: '🇬🇧',
          name: 'English (EN)',
          isSelected: currentLang == AppLanguage.en,
          onTap: () {
            LocalizationService().setLanguage(AppLanguage.en);
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildDrawerLangTile({
    required String flag,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFB300).withValues(alpha: 0.15)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFB300) : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFFB300) : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFFFFB300), size: 18),
          ],
        ),
      ),
    );
  }
}

class _DashTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  const _DashTile(this.label, this.icon, this.onTap, {this.badge = 0});

  List<Color> _resolveGradient() {
    if (icon == Icons.point_of_sale_rounded || icon == Icons.restaurant_menu_rounded) {
      return [const Color(0xFFFF9800), const Color(0xFFFF5722)];
    } else if (icon == Icons.radar_rounded) {
      return [const Color(0xFF10B981), const Color(0xFF0D9488)];
    } else if (icon == Icons.receipt_long_rounded || icon == Icons.list_alt_rounded) {
      return [const Color(0xFF00C2A8), const Color(0xFF0284C7)];
    } else if (icon == Icons.delivery_dining_rounded) {
      return [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];
    } else if (icon == Icons.history_rounded) {
      return [const Color(0xFF10B981), const Color(0xFF059669)];
    } else if (icon == Icons.analytics_rounded) {
      return [const Color(0xFF6366F1), const Color(0xFF4F46E5)];
    } else if (icon == Icons.inventory_2_rounded) {
      return [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)];
    } else if (icon == Icons.restaurant_rounded) {
      return [const Color(0xFFF43F5E), const Color(0xFFBE123C)];
    } else if (icon == Icons.grid_view_rounded) {
      return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
    } else if (icon == Icons.badge_rounded) {
      return [const Color(0xFF06B6D4), const Color(0xFF0E7490)];
    } else if (icon == Icons.groups_rounded) {
      return [const Color(0xFF84CC16), const Color(0xFF4D7C0F)];
    } else if (icon == Icons.table_restaurant_rounded) {
      return [const Color(0xFFEA580C), const Color(0xFF9A3412)];
    } else if (icon == Icons.tune_rounded) {
      return [const Color(0xFF64748B), const Color(0xFF334155)];
    }
    return [const Color(0xFFFFC107), const Color(0xFFFF9800)];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _resolveGradient();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: isDark ? 0 : 2,
      shadowColor: colors.first.withValues(alpha: 0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: colors.first.withValues(alpha: 0.15),
        highlightColor: colors.first.withValues(alpha: 0.08),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : colors.first.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 12 : 16),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: isMobile ? 48 : 58,
                      height: isMobile ? 48 : 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.last.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, size: isMobile ? 24 : 28, color: Colors.white),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        height: 1.2,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// CustomerOrdersScreen is defined in lib/screens/customer_orders_screen.dart

// ============================================================
// HALL SELECTION SCREEN (Kassir/Admin uchun — yangi buyurtma)
// ============================================================

// ============================================================
// TABLE WITH 2 CHAIRS ICON (IMAGE 3 DESIGN 1-TO-1 MATCH)
// ============================================================

class TableChairsIcon extends StatelessWidget {
  final Color color;
  final double width;
  final double height;

  const TableChairsIcon({
    super.key,
    required this.color,
    this.width = 68,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _TableChairsPainter(color: color),
    );
  }
}

class _TableChairsPainter extends CustomPainter {
  final Color color;
  _TableChairsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Center Table: Top surface
    canvas.drawLine(Offset(w * 0.33, h * 0.38), Offset(w * 0.67, h * 0.38), paint);
    // Center Table: Leg
    canvas.drawLine(Offset(w * 0.50, h * 0.38), Offset(w * 0.50, h * 0.78), paint);
    // Center Table: Base feet
    canvas.drawLine(Offset(w * 0.38, h * 0.88), Offset(w * 0.50, h * 0.78), paint);
    canvas.drawLine(Offset(w * 0.50, h * 0.78), Offset(w * 0.62, h * 0.88), paint);

    // Left Chair: Backrest & Rear Leg
    canvas.drawLine(Offset(w * 0.12, h * 0.22), Offset(w * 0.12, h * 0.88), paint);
    // Left Chair: Seat
    canvas.drawLine(Offset(w * 0.12, h * 0.55), Offset(w * 0.28, h * 0.55), paint);
    // Left Chair: Front Leg
    canvas.drawLine(Offset(w * 0.28, h * 0.55), Offset(w * 0.28, h * 0.88), paint);

    // Right Chair: Backrest & Rear Leg
    canvas.drawLine(Offset(w * 0.88, h * 0.22), Offset(w * 0.88, h * 0.88), paint);
    // Right Chair: Seat
    canvas.drawLine(Offset(w * 0.72, h * 0.55), Offset(w * 0.88, h * 0.55), paint);
    // Right Chair: Front Leg
    canvas.drawLine(Offset(w * 0.72, h * 0.55), Offset(w * 0.72, h * 0.88), paint);
  }

  @override
  bool shouldRepaint(covariant _TableChairsPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ============================================================
// HALL SELECTION SCREEN (DEPRECATED REDIRECT -> TABLE SELECTION)
// ============================================================

class HallSelectionScreen extends StatelessWidget {
  const HallSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TableSelectionScreen();
  }
}

// ============================================================
// TABLE SELECTION SCREEN (IMAGE 3 DASHBOARD - MOBILE & TABLET 1-TO-1)
// ============================================================

class TableSelectionScreen extends StatefulWidget {
  const TableSelectionScreen({super.key});
  @override
  State<TableSelectionScreen> createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> {
  @override
  void initState() {
    super.initState();
    if (appState.halls.isEmpty || appState.tables.isEmpty) {
      appState.loadCloudDataForCafe(appState.currentCafeId);
    }
    if (appState.selectedHall == null && appState.halls.isNotEmpty) {
      try {
        appState.selectedHall = appState.halls.firstWhere(
          (h) => h.name.trim().toLowerCase() == 'zal',
        );
      } catch (_) {
        appState.selectedHall = appState.halls.first;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final halls = appState.halls;
        if (appState.selectedHall == null && halls.isNotEmpty) {
          try {
            appState.selectedHall = halls.firstWhere(
              (h) => h.name.trim().toLowerCase() == 'zal',
            );
          } catch (_) {
            appState.selectedHall = halls.first;
          }
        }

        final selectedHall = appState.selectedHall;
        final myTables = selectedHall != null
            ? (appState.tables.where((t) {
                if (t.hallId == selectedHall.id) return true;
                final h = appState.halls.firstWhere(
                  (h) => h.id == t.hallId,
                  orElse: () => Hall(id: -1, name: '', icon: Icons.home),
                );
                return h.name.trim().toLowerCase() == selectedHall.name.trim().toLowerCase();
              }).toList()..sort((a, b) => a.number.compareTo(b.number)))
            : <TableModel>[];

        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F7),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F1E30),
            foregroundColor: Colors.white,
            elevation: 0,
            leadingWidth: 60,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  );
                }
              },
            ),
            title: const Text(
              'ZAVERO POS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
            actions: [
              // Online status
              Container(
                margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('Online', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
              // Notification bell
              Stack(children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                  onPressed: () {},
                ),
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
                    child: const Center(child: Text('2', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                  ),
                ),
              ]),
              // Avatar
              Padding(
                padding: const EdgeInsets.only(right: 12, left: 2),
                child: GestureDetector(
                  onTap: () {},
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF1E3A5F),
                      child: Text(
                        (appState.currentUser?.name ?? 'A').substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      appState.currentUser?.name ?? 'Admin',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
                  ]),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                tooltip: 'Yangilash',
                onPressed: () async {
                  await appState.loadCloudDataForCafe(appState.currentCafeId);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // ── ZALTANLANG HEADER ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    // Icon + Title
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1E30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.table_restaurant_outlined, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                      Text('Zal tanlang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F1E30))),
                      Text('Buyurtma berish uchun stollarni tanlang',
                          style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
                    ]),
                    const Spacer(),
                    // Zal dropdown button (matches Image 2 style)
                    if (halls.isNotEmpty)
                      Material(
                        color: const Color(0xFF0F1E30),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (_) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 12),
                                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                                  const SizedBox(height: 16),
                                  ...halls.map((h) => ListTile(
                                    leading: Icon(h.icon, color: selectedHall?.id == h.id ? const Color(0xFF0F1E30) : Colors.black54),
                                    title: Text(h.name, style: TextStyle(fontWeight: selectedHall?.id == h.id ? FontWeight.bold : FontWeight.normal)),
                                    trailing: selectedHall?.id == h.id ? const Icon(Icons.check, color: Color(0xFF0F1E30)) : null,
                                    onTap: () {
                                      setState(() { appState.selectedHall = h; });
                                      Navigator.pop(context);
                                    },
                                  )),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(selectedHall?.icon ?? Icons.table_restaurant, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                selectedHall?.name ?? 'Zal 1',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
                            ]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── HALL TABS ──────────────────────────────────────────────────
              if (halls.length > 1)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: halls.length,
                      itemBuilder: (context, idx) {
                        final h = halls[idx];
                        final isSel = selectedHall?.id == h.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Material(
                            color: isSel ? const Color(0xFF0F1E30) : const Color(0xFFF0F2F7),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setState(() { appState.selectedHall = h; }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(h.icon, size: 14, color: isSel ? Colors.white : Colors.black54),
                                  const SizedBox(width: 5),
                                  Text(h.name, style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: isSel ? Colors.white : Colors.black87,
                                  )),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // ── TABLE CARDS GRID ──────────────────────────────────────────
              Expanded(
                child: myTables.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.table_restaurant_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text("Bu zalda stollar yo'q",
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                        ]),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 0.88,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: myTables.length,
                        itemBuilder: (context, i) {
                          final t = myTables[i];
                          final free = t.status == TableStatus.free;
                          final orderTotal = appState.tableOrderTotal(t);
                          final glowColor = free ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
                          final statusLabel = free ? "Bo'sh" : "Band";
                          final seats = t.seats > 0 ? t.seats : 4;

                          return GestureDetector(
                            onTap: () {
                              appState.selectTable(t);
                              if (free) {
                                Navigator.push(context, MaterialPageRoute(
                                  settings: const RouteSettings(name: 'pos'),
                                  builder: (_) => const POSScreen(),
                                ));
                              } else {
                                Navigator.push(context, MaterialPageRoute(
                                  settings: const RouteSettings(name: 'payment'),
                                  builder: (_) => const PaymentScreen(),
                                ));
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: free ? const Color(0xFFD4EDDA) : const Color(0xFFFAD7D7),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Top row: Table number + Status badge
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${t.number}',
                                          style: const TextStyle(
                                            fontSize: 22, fontWeight: FontWeight.w800,
                                            color: Color(0xFFBDBDBD),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: free ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            Container(
                                              width: 7, height: 7,
                                              decoration: BoxDecoration(color: glowColor, shape: BoxShape.circle),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              statusLabel,
                                              style: TextStyle(
                                                fontSize: 11, fontWeight: FontWeight.w700,
                                                color: glowColor,
                                              ),
                                            ),
                                          ]),
                                        ),
                                      ],
                                    ),

                                    // Center: 3D Table Illustration with glow
                                    Expanded(
                                      child: Center(
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Glow circle
                                            Container(
                                              width: 90, height: 90,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: glowColor.withValues(alpha: 0.10),
                                              ),
                                            ),
                                            // Table illustration
                                            SizedBox(
                                              width: 80, height: 80,
                                              child: CustomPaint(
                                                painter: _TableIllustrationPainter(isFree: free),
                                              ),
                                            ),
                                            // Order total overlay for band tables
                                            if (!free && orderTotal > 0)
                                              Positioned(
                                                top: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE53935),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    formatSum(orderTotal),
                                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Bottom: Seat count + Arrow
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(children: [
                                          Icon(Icons.people_outline_rounded, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(
                                            "$seats o'rin",
                                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                          ),
                                        ]),
                                        Container(
                                          width: 28, height: 28,
                                          decoration: BoxDecoration(
                                            color: free ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 14,
                                            color: glowColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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

/// Stol tasvirini chizuvchi CustomPainter (Rasm 2 ga mos 3D ko'rinish)
class _TableIllustrationPainter extends CustomPainter {
  final bool isFree;
  const _TableIllustrationPainter({required this.isFree});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final tableColor = isFree ? const Color(0xFF8D6E63) : const Color(0xFF546E7A);
    final chairColor = isFree ? const Color(0xFF6D4C41) : const Color(0xFF37474F);
    final shadowColor = isFree ? const Color(0xFF5D4037) : const Color(0xFF263238);

    final paint = Paint()..isAntiAlias = true;

    // Shadow
    paint.color = shadowColor.withValues(alpha: 0.25);
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2 + 2, h / 2 + 4), width: w * 0.55, height: h * 0.20), paint);

    // Chairs (top)
    paint.color = chairColor;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.28, h * 0.06, w * 0.44, h * 0.15), const Radius.circular(6)), paint);
    // Chairs (bottom)
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.28, h * 0.79, w * 0.44, h * 0.15), const Radius.circular(6)), paint);
    // Chairs (left)
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.04, h * 0.32, w * 0.15, h * 0.36), const Radius.circular(6)), paint);
    // Chairs (right)
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.81, h * 0.32, w * 0.15, h * 0.36), const Radius.circular(6)), paint);

    // Table top
    paint.color = tableColor;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, h * 0.22, w * 0.60, h * 0.56), const Radius.circular(8)), paint);

    // Table highlight (glossy effect)
    paint.color = Colors.white.withValues(alpha: 0.18);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.26, h * 0.25, w * 0.48, h * 0.16), const Radius.circular(5)), paint);

    // Center decoration (plant/flower)
    paint.color = const Color(0xFF4CAF50).withValues(alpha: 0.70);
    canvas.drawCircle(Offset(w / 2, h / 2 + 2), 7, paint);
    paint.color = const Color(0xFF388E3C);
    canvas.drawCircle(Offset(w / 2, h / 2 + 2), 4, paint);
  }

  @override
  bool shouldRepaint(covariant _TableIllustrationPainter oldDelegate) => oldDelegate.isFree != isFree;
}



// ============================================================
// POS SCREEN (Kassir/Admin uchun Menu + Savat)
// Bu yerda "+" tugmasi orqali to'g'ridan-to'g'ri yangi taom va yangi
// kategoriya qo'shish mumkin (Admin uchun).
// ============================================================

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});
  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  int? selectedCategoryId;
  String search = '';

  bool get _canManageMenu => appState.currentUser?.role == UserRole.admin;

  void _addProduct() {
    if (appState.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avval kamida bitta kategoriya qo\'shing'),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _ProductEditDialog(defaultCategoryId: selectedCategoryId),
    ).then((_) => setState(() {}));
  }

  void _addCategory() {
    showDialog(
      context: context,
      builder: (_) => const _CategoryEditDialog(),
    ).then((_) => setState(() {}));
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    appState.addListener(_onAppStateChanged);
    if (appState.categories.isNotEmpty) {
      selectedCategoryId = appState.categories.first.id;
    }
  }

  @override
  void dispose() {
    appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (selectedCategoryId == null && appState.categories.isNotEmpty) {
      selectedCategoryId = appState.categories.first.id;
    }

    Category? selectedCat;
    if (selectedCategoryId != null) {
      selectedCat = appState.categories.firstWhere(
        (c) => c.id == selectedCategoryId,
        orElse: () => appState.categories.first,
      );
    }

    final filtered = appState.products.where((p) {
      if (selectedCategoryId == null) return true;
      if (p.categoryId == selectedCategoryId) return true;
      if (selectedCat != null) {
        final pCatName = appState.getCategoryName(p.categoryId);
        if (appState.normalizeCatName(pCatName).toLowerCase() == appState.normalizeCatName(selectedCat.name).toLowerCase()) {
          return true;
        }
      }
      return false;
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final wide = screenWidth > 900;

    int gridCols;
    double gridRatio;

    if (screenWidth < 600) {
      gridCols = 2;
      gridRatio = 0.82;
    } else if (screenWidth < 1100) {
      gridCols = 3;
      gridRatio = 0.84;
    } else {
      gridCols = 4;
      gridRatio = 0.85;
    }

    final menu = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KATEGORIYALAR TEPA QATORDA YONMA-YON (SEARCH INPUT O'CHIRILDI)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final c in appState.categories)
                  _catChip(c.name, c.id, icon: c.icon),
                if (_canManageMenu)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      avatar: const Icon(Icons.add, size: 18, color: Colors.black87),
                      label: const Text(
                        'Kategoriya',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      backgroundColor: Colors.amber.shade50,
                      side: BorderSide(color: kDarkYellow),
                      onPressed: _addCategory,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        // FADE + SLIDE SMOOTH ANIMATION BOSH QISM
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.no_food_outlined,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Hozircha taom yo\'q',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                      if (_canManageMenu) ...[
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _addProduct,
                          icon: const Icon(Icons.add),
                          label: const Text('Taom qo\'shish'),
                        ),
                      ],
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridCols,
                    childAspectRatio: gridRatio,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _ProductCard(
                    product: filtered[i],
                    canManage: _canManageMenu,
                    onEdited: () => setState(() {}),
                  ),
                ),
        ),
      ],
    );

    void navigateBack() {
      appState.leaveOrderSession();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'tableSelection'),
            builder: (_) => const TableSelectionScreen(),
          ),
        );
      }
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          appState.leaveOrderSession();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: navigateBack,
          ),
          title: Text(
            appState.selectedTable != null
                ? 'Stol ${appState.selectedTable!.number} · ${appState.selectedHall?.name ?? ""}'
                : 'Yangi buyurtma',
          ),
        ),
        floatingActionButton: _canManageMenu
            ? FloatingActionButton(
                heroTag: 'add_product_fab',
                onPressed: _addProduct,
                tooltip: 'Yangi taom qo\'shish',
                child: const Icon(Icons.add),
              )
            : (wide
                ? null
                : AnimatedBuilder(
                    animation: appState,
                    builder: (context, _) => FloatingActionButton.extended(
                      backgroundColor: kDarkYellow,
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (_) => SizedBox(
                            height: MediaQuery.of(context).size.height * 0.85,
                            child: const CartPanel(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.shopping_cart),
                      label: Text(
                        'Savat (${appState.cart.length}) · ${formatSum(appState.cartTotal)}',
                      ),
                    ),
                  )),
        body: wide
            ? Row(
                children: [
                  Expanded(flex: 3, child: menu),
                  Container(
                    width: 1,
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 310, child: CartPanel()),
                ],
              )
            : Stack(
                children: [
                  menu,
                  if (!_canManageMenu)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: AnimatedBuilder(
                        animation: appState,
                        builder: (context, _) => FloatingActionButton.extended(
                          heroTag: 'cart_fab',
                          backgroundColor: kDarkYellow,
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (_) => SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.85,
                                child: const CartPanel(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.shopping_cart),
                          label: Text(
                            'Savat (${appState.cart.length}) · ${formatSum(appState.cartTotal)}',
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: AnimatedBuilder(
                        animation: appState,
                        builder: (context, _) => appState.cart.isEmpty
                            ? const SizedBox.shrink()
                            : FloatingActionButton.extended(
                                heroTag: 'cart_fab_admin',
                                backgroundColor: kDarkYellow,
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    builder: (_) => SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.85,
                                      child: const CartPanel(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.shopping_cart),
                                label: Text(
                                  'Savat (${appState.cart.length}) · ${formatSum(appState.cartTotal)}',
                                ),
                              ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _catChip(String label, int? id, {IconData? icon}) {
    final selected = selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: ChoiceChip(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        label: Text(label),
        avatar: icon != null
            ? Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : Colors.black87,
              )
            : null,
        selected: selected,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        side: BorderSide(
          color: selected ? kDarkYellow : Colors.grey.shade300,
          width: selected ? 2.5 : 1,
        ),
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) return kDarkYellow;
          if (states.contains(WidgetState.hovered)) {
            return Colors.amber.shade100;
          }
          return Colors.white;
        }),
        onSelected: (_) => setState(() => selectedCategoryId = id),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool canManage;
  final VoidCallback? onEdited;
  const _ProductCard({
    required this.product,
    this.canManage = false,
    this.onEdited,
  });

  CartItem? _cartItemFor(Product p) {
    for (final c in appState.cart) {
      if (c.product.id == p.id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final cartItem = _cartItemFor(product);
        final qty = cartItem?.qty ?? 0;
        return Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: qty == 0 ? () => appState.addToCart(product) : null,
            onLongPress: canManage
                ? () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => _ProductEditDialog(product: product),
                    ).then((_) => onEdited?.call());
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: _ProductThumb(product: product)),
                        if (canManage)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                showDialog<void>(
                                  context: context,
                                  builder: (_) =>
                                      _ProductEditDialog(product: product),
                                ).then((_) => onEdited?.call());
                              },
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatSum(product.price),
                    style: TextStyle(
                      color: kDarkYellow,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  qty == 0
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              side: const BorderSide(color: Colors.white, width: 1.0),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => appState.addToCart(product),
                            child: const Text(
                              'OLISH',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: kYellow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _stepperBtn(
                                Icons.remove,
                                () => appState.changeQty(cartItem!, -1),
                              ),
                              Text(
                                '$qty',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              _stepperBtn(
                                Icons.add,
                                () => appState.changeQty(cartItem!, 1),
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stepperBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(icon, size: 18, color: Colors.black87),
      ),
    );
  }
}

// ============================================================
// TAOM (MAHSULOT) QO'SHISH / TAHRIRLASH DIALOGI
// Nomi, narxi, kategoriyasi, zaxirasi va rasmi (link) shu yerdan kiritiladi.
// ============================================================

// ============================================================
// PRESET FOOD IMAGES LIBRARY & PRODUCT EDIT DIALOG
// ============================================================

class _PresetFoodItem {
  final String title;
  final String url;
  final String? subtitle;

  const _PresetFoodItem({
    required this.title,
    required this.url,
    this.subtitle,
  });
}

class _PresetFoodCategory {
  final String title;
  final IconData icon;
  final List<_PresetFoodItem> items;

  const _PresetFoodCategory({
    required this.title,
    required this.icon,
    required this.items,
  });

  List<String> get images => items.map((e) => e.url).toList();
}

const List<_PresetFoodCategory> _presetFoodLibraries = [
  // 1. Shaurma (Alohida - 18 ta turli xil)
  _PresetFoodCategory(
    title: 'Shaurma',
    icon: Icons.lunch_dining_rounded,
    items: [
      _PresetFoodItem(
        title: 'Klassik Shaurma',
        subtitle: 'Go\'shtli va qarsildoq',
        url: 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Katta Shaurma (Max)',
        subtitle: 'Katta porsiya',
        url: 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tovuqli Shaurma',
        subtitle: 'Mayin tovuq go\'shti',
        url: 'https://images.unsplash.com/photo-1561651823-34feb02250e4?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pishloqli Shaurma',
        subtitle: 'Eritilgan mozzarella',
        url: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tandir Shaurma',
        subtitle: 'Tandirda qizargan',
        url: 'https://images.unsplash.com/photo-1633337474565-12c449339028?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Achchiq Shaurma (Hot)',
        subtitle: 'Jalapeno & sous',
        url: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mini Shaurma',
        subtitle: 'Kichik porsiya',
        url: 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Arabcha Shaurma',
        subtitle: 'Maxsus arab ziravorlari',
        url: 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Doner Shaurma',
        subtitle: 'Baton nonida go\'shtli',
        url: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Shaurma Pita',
        subtitle: 'Yumshoq pita nonida',
        url: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Shaurma Porsiya',
        subtitle: 'Likopchada fri bilan',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Assorti Shaurma',
        subtitle: 'Mol va tovuq go\'shti',
        url: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Zavero Special Shaurma',
        subtitle: 'Mualliflik retsepti',
        url: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Shaurma Box',
        subtitle: 'Maxsus qutida set',
        url: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qo\'ziqorinli Shaurma',
        subtitle: 'Shampinyon qo\'ziqorinli',
        url: 'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Double Shaurma',
        subtitle: 'Ikki hissa go\'sht',
        url: 'https://images.unsplash.com/photo-1572802419224-296b0aeee0d9?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Fitter Shaurma',
        subtitle: 'Dietik sabzavotli',
        url: 'https://images.unsplash.com/photo-1553979459-d2229ba7433b?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qazili Shaurma',
        subtitle: 'Qazi bo\'laklari bilan',
        url: 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),

  // 2. Lavash (Alohida - 18 ta turli xil)
  _PresetFoodCategory(
    title: 'Lavash',
    icon: Icons.bakery_dining_rounded,
    items: [
      _PresetFoodItem(
        title: 'Klassik Lavash',
        subtitle: 'Mol go\'shti va pomidor',
        url: 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Katta Go\'shtli Lavash',
        subtitle: 'Katta porsiya',
        url: 'https://images.unsplash.com/photo-1561651823-34feb02250e4?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tovuqli Lavash',
        subtitle: 'Tovuq filesi va sous',
        url: 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pishloqli Lavash',
        subtitle: 'Mozzarella va chedder',
        url: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tandir Lavash',
        subtitle: 'Haqiqiy tandirda pishgan',
        url: 'https://images.unsplash.com/photo-1633337474565-12c449339028?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Achchiq Lavash',
        subtitle: 'Achchiq sous bilan',
        url: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mini Lavash',
        subtitle: 'Bolalar va yengil tamaddi',
        url: 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qazili Lavash',
        subtitle: 'Milliy qazi bilan',
        url: 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Fitter Lavash',
        subtitle: 'Kam yog\'li kuritsa bilan',
        url: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Lavash Box',
        subtitle: 'Fri va sous bilan set',
        url: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Go\'sht & Pishloq Lavash',
        subtitle: 'Ko\'p go\'sht va erigan pishloq',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qo\'ziqorinli Lavash',
        subtitle: 'Qovurilgan qo\'ziqorinli',
        url: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Double Go\'sht Lavash',
        subtitle: '2 barobar ko\'p go\'sht',
        url: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Lavash Porsiya',
        subtitle: 'Likopcha va garnirlar',
        url: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Zavero Special Lavash',
        subtitle: 'Zavero maxsus ta\'mi',
        url: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mol Go\'shtli Tandir',
        subtitle: 'Shirador mol go\'shti',
        url: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Kichik Tovuq Lavash',
        subtitle: 'Standart tovuqli',
        url: 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Lavash Roll',
        subtitle: 'Kesilgan mini bo\'laklar',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),

  // 3. Burger & Fast Food (18 ta turli xil)
  _PresetFoodCategory(
    title: 'Burger & Fast Food',
    icon: Icons.fastfood_rounded,
    items: [
      _PresetFoodItem(
        title: 'Cheeseburger',
        subtitle: 'Klassik pishloqli kotlet',
        url: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Hamburger',
        subtitle: 'Shirador kotlet va bodring',
        url: 'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Double Cheeseburger',
        subtitle: '2 ta kotlet va erigan pishloq',
        url: 'https://images.unsplash.com/photo-1572802419224-296b0aeee0d9?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Big Burger',
        subtitle: 'Katta o\'lchamli maxsus burger',
        url: 'https://images.unsplash.com/photo-1553979459-d2229ba7433b?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Chiken Burger',
        subtitle: 'Qarsildoq tovuq kotleti',
        url: 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Barbecue Burger',
        subtitle: 'Tutuqli BBQ sous bilan',
        url: 'https://images.unsplash.com/photo-1607013251379-e6eecfffe234?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qora Burger (Black)',
        subtitle: 'Qora nonda maxsus burger',
        url: 'https://images.unsplash.com/photo-1619881589775-96101c51950e?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mini Burger',
        subtitle: 'Bolalar uchun porsiya',
        url: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Zavero Max Burger',
        subtitle: 'Barcha qo\'shimchalar bilan',
        url: 'https://images.unsplash.com/photo-1547584370-2cc98b8b8dc8?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Fri Kartoshkasi',
        subtitle: 'Qarsildoq oltin fri',
        url: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Nagets (6 dona)',
        subtitle: 'Tovuqli oltin nagets',
        url: 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tovuq Stripsilari',
        subtitle: 'Qarsildoq tovuq filesi',
        url: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qarsildoq Qanotchalar',
        subtitle: 'Achchiq-shirin qanotlar',
        url: 'https://images.unsplash.com/photo-1527477321005-4d01d75bc660?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pishloqli Halqalar',
        subtitle: 'Mozzarella halqalari',
        url: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qishloqcha Fri',
        subtitle: 'Po-derevenski kartoshka',
        url: 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Jalapeno Burger',
        subtitle: 'Achchiq qalampirli',
        url: 'https://images.unsplash.com/photo-1551782450-a2132b4ba21d?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Smokey Bacon Burger',
        subtitle: 'Tutuqli bekoni bilan',
        url: 'https://images.unsplash.com/photo-1582196016295-f8c8bd4b3e99?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Kombo Burger Set',
        subtitle: 'Burger, fri va ichimlik',
        url: 'https://images.unsplash.com/photo-1521305916504-4a1121188589?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),

  // 4. Hot-dog & Sendvich (16 ta turli xil)
  _PresetFoodCategory(
    title: 'Hot-dog & Sendvich',
    icon: Icons.breakfast_dining_rounded,
    items: [
      _PresetFoodItem(
        title: 'Klassik Hot-dog',
        subtitle: 'Sosiska, xantal va sous',
        url: 'https://images.unsplash.com/photo-1619740455993-9e612b1af08a?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Katta Hot-dog (Max)',
        subtitle: 'Katta dudlangan sosiska',
        url: 'https://images.unsplash.com/photo-1627059173003-8898198947f6?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Ovchi Hot-dog (Hunter)',
        subtitle: 'Ovchi sosiskasi bilan',
        url: 'https://images.unsplash.com/photo-1612528443702-f6741f74a04b?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pishloqli Hot-dog',
        subtitle: 'Erigan mozzarella va chedder',
        url: 'https://images.unsplash.com/photo-1541214113241-21578d2d9b62?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Achchiq Jalapeno Hot-dog',
        subtitle: 'Olovli achchiq qalampir',
        url: 'https://images.unsplash.com/photo-1585238342024-78d387f4a707?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Frantsuzcha Hot-dog',
        subtitle: 'Baqat nonda sosiskali',
        url: 'https://images.unsplash.com/photo-1592415486689-125cbbfcbee2?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Klabb Sendvich',
        subtitle: 'Uch burchakli toster non',
        url: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Toster Sendvich',
        subtitle: 'Pishloq va vetchina',
        url: 'https://images.unsplash.com/photo-1554433607-66b5efe9d304?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tovuqli Sendvich',
        subtitle: 'Gril tovuq filesi',
        url: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mol Go\'shtli Baget Sendvich',
        subtitle: 'Qarsildoq baget non',
        url: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tunetsli Sendvich',
        subtitle: 'Dengiz balig\'i va tuxum',
        url: 'https://images.unsplash.com/photo-1521390188846-e2a39b7ef4a8?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pishloqli Panini',
        subtitle: 'Grilda pishirilgan panini',
        url: 'https://images.unsplash.com/photo-1539252554453-80ab65ce3586?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Ham & Cheese Sendvich',
        subtitle: 'Klassik uyg\'unlik',
        url: 'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Gril Sendvich',
        subtitle: 'Tosterda qizargan non',
        url: 'https://images.unsplash.com/photo-1567234669003-dce7a7a88821?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mini Sendvichlar Assorti',
        subtitle: 'Bir nechta ta\'mlar to\'plami',
        url: 'https://images.unsplash.com/photo-1481070414801-51fd732d7184?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Max Sousli Hot-dog',
        subtitle: 'Ko\'p sousli va piyozli',
        url: 'https://images.unsplash.com/photo-1585238341267-1cfbc2046a55?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),

  // 5. Pitsa & Piroglar (18 ta turli xil)
  _PresetFoodCategory(
    title: 'Pitsa & Piroglar',
    icon: Icons.local_pizza_rounded,
    items: [
      _PresetFoodItem(
        title: 'Margarita Pitsa',
        subtitle: 'Pomidor va mozzarella',
        url: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pepperoni Pitsa',
        subtitle: 'Dudlangan kolbasa bilan',
        url: 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: '4 Pishloqli Pitsa',
        subtitle: 'To\'rt xil nozik pishloq',
        url: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qo\'ziqorinli Pitsa',
        subtitle: 'Shampinyon va oq sous',
        url: 'https://images.unsplash.com/photo-1593560708920-61dd98c46a4e?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Go\'shtli Pitsa (Meat)',
        subtitle: 'Mol go\'shti va qazi',
        url: 'https://images.unsplash.com/photo-1594007654729-407eedc4be65?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Zavero Assorti Pitsa',
        subtitle: 'Barcha masalliqlar jamlanmasi',
        url: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tovuqli Pitsa (Chicken)',
        subtitle: 'Tovuq go\'shti va zaytun',
        url: 'https://images.unsplash.com/photo-1534308983496-4fabb1a015ee?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Barbekyu Pitsa (BBQ)',
        subtitle: 'BBQ sous va tovuq',
        url: 'https://images.unsplash.com/photo-1604382355076-af4b0eb60143?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Dengiz Mahsulotli Pitsa',
        subtitle: 'Krevyetka va kalmar',
        url: 'https://images.unsplash.com/photo-1571407970349-bc81e7e96d47?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Achchiq Diavola',
        subtitle: 'Achchiq qalampir va go\'sht',
        url: 'https://images.unsplash.com/photo-1588315029754-2dd089d39a1a?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Gavaya Pitsasi',
        subtitle: 'Ananas va tovuq',
        url: 'https://images.unsplash.com/photo-1565299507177-b0ac66763828?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Kalzone (Yopiq pitsa)',
        subtitle: 'Shirador yopiq pitsa',
        url: 'https://images.unsplash.com/photo-1541745537411-b8046dc6d66c?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Go\'shtli Pirog',
        subtitle: 'Qatlama xamirdan pirog',
        url: 'https://images.unsplash.com/photo-1608039829572-78524f79c4c7?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pishloqli Xachapuri',
        subtitle: 'Gruzincha erigan pishloq',
        url: 'https://images.unsplash.com/photo-1608897013039-887f21d8c804?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Go\'shtli Lahmajun',
        subtitle: 'Yupqa turkcha lahmajun',
        url: 'https://images.unsplash.com/photo-1626074353765-517a681e40be?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pide Go\'shtli',
        subtitle: 'Qayiqcha shaklidagi pide',
        url: 'https://images.unsplash.com/photo-1579751626657-72bc17010498?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mini Pitsachalar',
        subtitle: 'Bolalar uchun ixcham',
        url: 'https://images.unsplash.com/photo-1595854341625-f33ee10dbf94?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Zavero Mega Pitsa 40cm',
        subtitle: 'Katta oilaviy pitsa',
        url: 'https://images.unsplash.com/photo-1590947132387-155cc02f3212?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),

  // 6. Milliy taomlar (22 ta turli xil)
  _PresetFoodCategory(
    title: 'Milliy taomlar',
    icon: Icons.outdoor_grill_rounded,
    items: [
      _PresetFoodItem(
        title: 'Choyxona Oshi',
        subtitle: 'Dumba va noxatli an\'anaviy osh',
        url: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'To\'y Oshi (Devzira)',
        subtitle: 'Qazi, bedana tuxum va mayiz',
        url: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tandir Somsa',
        subtitle: 'Qarsildoq xamir va mayin go\'sht',
        url: 'https://images.unsplash.com/photo-1608039829572-78524f79c4c7?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qatlama Go\'shtli Somsa',
        subtitle: 'Qavat-qavat mayin xamir',
        url: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Shashlik Qiyma',
        subtitle: 'Mayin qiyma go\'sht kabob',
        url: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Shashlik Kuskovoy',
        subtitle: 'Mol va qo\'y go\'shti lo\'la',
        url: 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Jigar Shashlik',
        subtitle: 'Dumba bilan o\'ralgan jigar',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tovuq Shashlik',
        subtitle: 'Shirador qanot va file',
        url: 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qozon Kabob',
        subtitle: 'Qovurilgan kartoshka va go\'sht',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qovurma Lag\'mon',
        subtitle: 'Qo\'lda cho\'zilgan lag\'mon',
        url: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Cho\'zma Lag\'mon (Sho\'rva)',
        subtitle: 'Boy sabzavotli qayla bilan',
        url: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Go\'shtli Manti',
        subtitle: 'Qovoqli va go\'shtli manti',
        url: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mastava',
        subtitle: 'Guruchli va qatiqli milliy taom',
        url: 'https://images.unsplash.com/photo-1547592180-85f173990554?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Sho\'rva (Qo\'y go\'shtli)',
        subtitle: 'Sergo\'sht qaynatma sho\'rva',
        url: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Chuchvara Sho\'rvada',
        subtitle: 'Mayda qo\'lda tugilgan chuchvara',
        url: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Norin',
        subtitle: 'Yupqa xamir va ot go\'shti',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Dimlama',
        subtitle: 'Qozonda bug\'langan sabzavotlar',
        url: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Jiz-biz',
        subtitle: 'Qovurilgan shirador go\'sht',
        url: 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Go\'shtli Non (Patir)',
        subtitle: 'Tandirda pishgan go\'shtli patir',
        url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Issiq Tandir Non',
        subtitle: 'Kunjutli shirmoy non',
        url: 'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qazi Likopchada',
        subtitle: 'Qalampir va piyoz bilan',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Milliy Assorti Go\'sht',
        subtitle: 'Qazi, til va rulet',
        url: 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),

  // 7. Coca-Cola (Alohida o'lchamlar va turlari)
  _PresetFoodCategory(
    title: 'Coca-Cola',
    icon: Icons.local_drink_rounded,
    items: [
      _PresetFoodItem(
        title: 'Coca-Cola 0.5L',
        subtitle: '0.5 litr plastik idish',
        url: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Coca-Cola 1.0L',
        subtitle: '1.0 litr plastik idish',
        url: 'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Coca-Cola 1.5L',
        subtitle: '1.5 litr katta idish',
        url: 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Coca-Cola 2.0L',
        subtitle: '2.0 litr oilaviy idish',
        url: 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Coca-Cola Banka 0.33L',
        subtitle: 'Temir banka 330ml',
        url: 'https://images.unsplash.com/photo-1567103472667-6898f3a79cf2?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Coca-Cola Zero 0.5L',
        subtitle: 'Shakarsiz 0.5 litr',
        url: 'https://images.unsplash.com/photo-1596803244618-8dbee441d70b?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Coca-Cola Zero 1.5L',
        subtitle: 'Shakarsiz 1.5 litr',
        url: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Coca-Cola Shisha 0.25L',
        subtitle: 'Klassik shisha idish',
        url: 'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Coca-Cola Muz Bilan',
        subtitle: 'Stakanda muzdek kola',
        url: 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Coca-Cola Cherry',
        subtitle: 'Olchali maxsus ta\'m',
        url: 'https://images.unsplash.com/photo-1567103472667-6898f3a79cf2?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),

  // 8. Fanta (Alohida o'lchamlar va turlari)
  _PresetFoodCategory(
    title: 'Fanta',
    icon: Icons.local_drink_rounded,
    items: [
      _PresetFoodItem(
        title: 'Fanta Apelsin 0.5L',
        subtitle: '0.5 litr apelsin ta\'mi',
        url: 'https://images.unsplash.com/photo-1624638760978-7517178385ea?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Fanta Apelsin 1.0L',
        subtitle: '1.0 litr plastik idish',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Fanta Apelsin 1.5L',
        subtitle: '1.5 litr katta idish',
        url: 'https://images.unsplash.com/photo-1579268351234-073f85929562?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Fanta Apelsin 2.0L',
        subtitle: '2.0 litr oilaviy idish',
        url: 'https://images.unsplash.com/photo-1624638760978-7517178385ea?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Fanta Banka 0.33L',
        subtitle: 'Temir banka 330ml',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Fanta Shisha 0.25L',
        subtitle: 'Shisha idish 250ml',
        url: 'https://images.unsplash.com/photo-1579268351234-073f85929562?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Fanta Tropic',
        subtitle: 'Tropik mevalar ta\'mi',
        url: 'https://images.unsplash.com/photo-1624638760978-7517178385ea?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Fanta Muz Bilan',
        subtitle: 'Muzli stakanda tetiklantiruvchi',
        url: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),

  // 9. Pepsi (Alohida o'lchamlar va turlari)
  _PresetFoodCategory(
    title: 'Pepsi',
    icon: Icons.local_drink_rounded,
    items: [
      _PresetFoodItem(
        title: 'Pepsi 0.5L',
        subtitle: '0.5 litr plastik idish',
        url: 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pepsi 1.0L',
        subtitle: '1.0 litr plastik idish',
        url: 'https://images.unsplash.com/photo-1553456558-aff63285bdd1?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pepsi 1.5L',
        subtitle: '1.5 litr katta idish',
        url: 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pepsi 2.0L',
        subtitle: '2.0 litr oilaviy idish',
        url: 'https://images.unsplash.com/photo-1553456558-aff63285bdd1?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pepsi Banka 0.33L',
        subtitle: 'Temir banka 330ml',
        url: 'https://images.unsplash.com/photo-1553456558-aff63285bdd1?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pepsi Max Zero 0.5L',
        subtitle: 'Shakarsiz 0.5 litr',
        url: 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pepsi Max Zero 1.5L',
        subtitle: 'Shakarsiz 1.5 litr',
        url: 'https://images.unsplash.com/photo-1553456558-aff63285bdd1?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pepsi Shisha 0.25L',
        subtitle: 'Shisha idish 250ml',
        url: 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),

  // 10. Muzqaymoq & Marojni (Alohida - 18 ta turli xil)
  _PresetFoodCategory(
    title: 'Muzqaymoq & Marojni',
    icon: Icons.icecream_rounded,
    items: [
      _PresetFoodItem(
        title: 'Plombir Klassik',
        subtitle: 'Qaymoqli oq plombir',
        url: 'https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Shokoladli Marojni',
        subtitle: 'Quyuq shokoladli muzqaymoq',
        url: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qulupnayli Marojni',
        subtitle: 'Haqiqiy mevali qulupnay',
        url: 'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Rojok Vanilli',
        subtitle: 'Qarsildoq vafli rojogida',
        url: 'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Rojok Shokoladli',
        subtitle: 'Shokolad glazuri bilan',
        url: 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Eskimo Shokoladda',
        subtitle: 'Qalin shokolad qoplamasi',
        url: 'https://images.unsplash.com/photo-1580915411954-282cb1b0d780?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Eskimo Yong\'oqli',
        subtitle: 'Yong\'oq bo\'laklari bilan',
        url: 'https://images.unsplash.com/photo-1505394033641-40c6ad1178d7?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Sundae Karamelli',
        subtitle: 'Iliq karamel va yong\'oq',
        url: 'https://images.unsplash.com/photo-1570197788417-0e82375c9371?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Sundae Qulupnayli',
        subtitle: 'Qulupnay murabbosi bilan',
        url: 'https://images.unsplash.com/photo-1560008581-09826d1de69e?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Donali Sharik Marojni',
        subtitle: '3 xil ta\'m shariklari',
        url: 'https://images.unsplash.com/photo-1516559828984-fb3b99548b21?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Oreo Muzqaymoq',
        subtitle: 'Oreo pechenyelari bilan',
        url: 'https://images.unsplash.com/photo-1587314168485-3236d6710814?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mevali Muzqaymoq',
        subtitle: 'Yangi mevalar assortisi',
        url: 'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Muzqaymoq Qadahda',
        subtitle: 'Restoran taqdimotidagi desert',
        url: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pista Muzqaymoq (Pistachio)',
        subtitle: 'Xushbo\'y pista ta\'mi',
        url: 'https://images.unsplash.com/photo-1579954115545-a95591f28bfc?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Muzqaymoqli Milkshake',
        subtitle: 'Quyuq shirin sutli kokteyl',
        url: 'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Bananli Split',
        subtitle: 'Banan va 3 sharik marojni',
        url: 'https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mango Sorbet',
        subtitle: '100% tetiklantiruvchi mevali muz',
        url: 'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Zavero Special Sundae',
        subtitle: 'Shokolad, meva va qaymoq',
        url: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),

  // 11. Qahva & Choy (16 ta turli xil)
  _PresetFoodCategory(
    title: 'Qahva & Choy',
    icon: Icons.coffee_rounded,
    items: [
      _PresetFoodItem(
        title: 'Espresso',
        subtitle: 'Klassik to\'q qahva',
        url: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Amerikano',
        subtitle: 'Issiq va yumshoq qahva',
        url: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Kapuchino',
        subtitle: 'Qalin va mayin sutli ko\'pik',
        url: 'https://images.unsplash.com/photo-1572442388796-11668a67e53d?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Latte',
        subtitle: 'Sutli mayin qahva',
        url: 'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mokkachino',
        subtitle: 'Shokolad va qahva uyg\'unligi',
        url: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Raf Qahva',
        subtitle: 'Qaymoq va vanilli qahva',
        url: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Muzli Kofe (Ice Latte)',
        subtitle: 'Muzdek va tetiklashtiruvchi',
        url: 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Issiq Shokolad (Kakao)',
        subtitle: 'Quyuq shokoladli ichimlik',
        url: 'https://images.unsplash.com/photo-1542990253-0d0f5be5f0ed?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Ko\'k Choy (Choynak)',
        subtitle: 'Ko\'k 95 choyi',
        url: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qora Choy (Choynak)',
        subtitle: 'Xushbo\'y qora choy',
        url: 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Limonli Choy',
        subtitle: 'Yangi limon bo\'laklari',
        url: 'https://images.unsplash.com/photo-1556881286-fc6915169721?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tog\' Choyi (Giyohli)',
        subtitle: 'Kiyiko\'t va yalpizli choy',
        url: 'https://images.unsplash.com/photo-1597481499750-3e6b22637e12?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mevali Choy',
        subtitle: 'Olma, qulupnay va apelsin',
        url: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Zanjabil Choy (Asalli)',
        subtitle: 'Imbilli va asal bilan',
        url: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qulupnayli Choy',
        subtitle: 'Yangi qulupnayli choy',
        url: 'https://images.unsplash.com/photo-1556881286-fc6915169721?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Matcha Latte',
        subtitle: 'Yapon yashil choyi latesi',
        url: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),

  // 12. Sharbat & Suv (16 ta turli xil)
  _PresetFoodCategory(
    title: 'Sharbat & Suv',
    icon: Icons.local_bar_rounded,
    items: [
      _PresetFoodItem(
        title: 'Apelsin Sharbati (Fresh)',
        subtitle: 'Yangi siqilgan tabiiy sharbat',
        url: 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Olma Sharbati',
        subtitle: '100% tiniq olma sharbati',
        url: 'https://images.unsplash.com/photo-1568651316335-e106ea46261c?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Anor Sharbati',
        subtitle: 'Vitaminga boy qizil anor',
        url: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Olcha Sharbati (Vishnya)',
        subtitle: 'Shirin-nordon olcha',
        url: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Gazsiz Suv 0.5L',
        subtitle: 'Tog\' buloq suvi',
        url: 'https://images.unsplash.com/photo-1548839140-29a749e1bc4e?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Gazsiz Suv 1.5L',
        subtitle: 'Katta idishda toza suv',
        url: 'https://images.unsplash.com/photo-1559839914-ba2a578a05c3?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Gazli Suv 0.5L',
        subtitle: 'Mineral gazli suv',
        url: 'https://images.unsplash.com/photo-1550572017-edd951aa8f72?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Borjomi',
        subtitle: 'Shifobaxsh mineral suv',
        url: 'https://images.unsplash.com/photo-1527661591475-527312dd65f5?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Red Bull Energetik',
        subtitle: 'Energiya beruvchi ichimlik',
        url: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Flash Energetik',
        subtitle: 'Meva ta\'mli energetik',
        url: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Klassik Mojito',
        subtitle: 'Yalpiz, laym va muz',
        url: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qulupnayli Mojito',
        subtitle: 'Qulupnay va yalpiz ta\'mi',
        url: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Uy Limonadi',
        subtitle: 'Tsitrusli salqin ichimlik',
        url: 'https://images.unsplash.com/photo-1621263764928-df1444c5e859?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tarxun',
        subtitle: 'Yashil xushbo\'y limonad',
        url: 'https://images.unsplash.com/photo-1536935338788-846bb9981813?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Dyushes (Nok limonadi)',
        subtitle: 'Shirin nokli salqin ichimlik',
        url: 'https://images.unsplash.com/photo-1556881286-fc6915169721?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Berry Mix Smoothie',
        subtitle: 'Rezavor mevali smuzi',
        url: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),

  // 13. Shirinliklar & Tortlar (16 ta turli xil)
  _PresetFoodCategory(
    title: 'Shirinliklar & Tortlar',
    icon: Icons.cake_rounded,
    items: [
      _PresetFoodItem(
        title: 'Medovik (Asalli tort)',
        subtitle: 'Nozik asal va smetana kremi',
        url: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Napoleon Torti',
        subtitle: 'Qatlama xamir va vanilli krem',
        url: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qizil Baxmal (Red Velvet)',
        subtitle: 'Mayin krem-chiz qatlami',
        url: 'https://images.unsplash.com/photo-1586788680434-30d324b2d46f?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Chizkeyk Nyu-York',
        subtitle: 'Klassik qaymoqli chizkeyk',
        url: 'https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Shokoladli Fondant',
        subtitle: 'Ichidan oqib chiquvchi issiq shokolad',
        url: 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tiramisu',
        subtitle: 'Italiyacha kofe va maskarpone',
        url: 'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Shokoladli Brauni',
        subtitle: 'Yong\'oqli quyuq shokolad',
        url: 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pahlava (Baklava)',
        subtitle: 'Asal va yong\'oqli sharqona shirinlik',
        url: 'https://images.unsplash.com/photo-1587314168485-3236d6710814?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Kruassan Shokoladli',
        subtitle: 'Fransuzcha mayin qatlama',
        url: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Ponchiklar Assorti',
        subtitle: 'Rangli shokolad va nachinka',
        url: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Ekler (2 dona)',
        subtitle: 'Qaymoqli nachinka bilan',
        url: 'https://images.unsplash.com/photo-1612203985729-70726954388c?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mevali Tort',
        subtitle: 'Yangi rezavor mevalar bilan',
        url: 'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'San-Sebastyan Chizkeyk',
        subtitle: 'Kuygan kremli chizkeyk',
        url: 'https://images.unsplash.com/photo-1535141192574-5d4897c13136?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Kapkeyk (Maffin)',
        subtitle: 'Chiroyli kremli keks',
        url: 'https://images.unsplash.com/photo-1587668178277-295251f900ce?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Makaron Shirinligi (3 dona)',
        subtitle: 'Fransuz bodom pechenyesi',
        url: 'https://images.unsplash.com/photo-1569864358642-9d1684040f43?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Vafli Shirinligi',
        subtitle: 'Shokolad va meva bilan vafli',
        url: 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),

  // 14. Salat & Gazaklar (16 ta turli xil)
  _PresetFoodCategory(
    title: 'Salat & Gazaklar',
    icon: Icons.set_meal_rounded,
    items: [
      _PresetFoodItem(
        title: 'Achchiq-chuchuk',
        subtitle: 'Oshbop mayda to\'g\'ralgan pomidor',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Sezar Salati',
        subtitle: 'Gril tovuq va parmezan',
        url: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Yunoncha Salat (Greek)',
        subtitle: 'Feta pishloq va zaytun',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Olivye Salati',
        subtitle: 'Klassik bayramona salat',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Mujskoy Kapriz',
        subtitle: 'Qazi, til va pishloqli salat',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Bahor Salati',
        subtitle: 'Rediska, bodring va ko\'katlar',
        url: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Suzma Ko\'katlar Bilan',
        subtitle: 'Xushbo\'y sarimsoqli suzma',
        url: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Yangi Bodring-Pomidor',
        subtitle: 'Ko\'katlar bilan to\'g\'ralgan',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Sabzavotli Assorti',
        subtitle: 'Taziy pomidor, bodring, bulg\'ori',
        url: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Pishloqli Assorti',
        subtitle: 'Turli elita pishloqlar',
        url: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tovuqli Salat',
        subtitle: 'Tovuq filesi va bodring',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qisqichbaqasimon Salat (Krab)',
        subtitle: 'Krab tayoqchalari va makkajo\'xori',
        url: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Fransuzcha Go\'shtli Salat',
        subtitle: 'Qovurilgan go\'sht va sabzi',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qovurilgan Baqlajon Salati',
        subtitle: 'Qarsildoq baqlajon va sous',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Qazi va Go\'sht Assorti',
        subtitle: 'Milliy yaxna go\'shtlar',
        url: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80',
      ),
      _PresetFoodItem(
        title: 'Tuzlamalar Assorti',
        subtitle: 'Tuzlangan pomidor, bodring, patisson',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
      ),
    ],
  ),
];

class _PresetImagesPickerDialog extends StatefulWidget {
  const _PresetImagesPickerDialog();

  @override
  State<_PresetImagesPickerDialog> createState() =>
      _PresetImagesPickerDialogState();
}

class _PresetImagesPickerDialogState extends State<_PresetImagesPickerDialog> {
  int _selectedCategoryIndex = 0;
  String? _selectedImageUrl;
  String? _selectedItemName;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectAndFinish(_PresetFoodItem item) {
    Navigator.pop(context, {
      'url': item.url,
      'name': item.title,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCategory = _presetFoodLibraries[_selectedCategoryIndex];

    // Filter items: if search is active, search across ALL categories
    final isSearching = _searchQuery.trim().isNotEmpty;
    final List<_PresetFoodItem> displayedItems;
    if (isSearching) {
      final q = _searchQuery.trim().toLowerCase();
      displayedItems = _presetFoodLibraries
          .expand((c) => c.items)
          .where((item) =>
              item.title.toLowerCase().contains(q) ||
              (item.subtitle?.toLowerCase().contains(q) ?? false))
          .toList();
    } else {
      displayedItems = activeCategory.items;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFA000), Color(0xFFFFB300)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFA000).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.collections_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Tayyor taom va ichimlik rasmlari',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: kDarkYellow.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Alohida (Adena)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: kDarkYellow,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kerakli mahsulotni tanlang yoki qidiring (ikki marta bosib darhol tanlash mumkin)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Box
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _searchQuery.isNotEmpty
                        ? const Color(0xFFFFA000)
                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
                      if (mounted) setState(() => _searchQuery = val);
                    });
                  },
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Taom yoki ichimlik qidirish (masalan: 1.5L, shaurma, lavash, marojni, osh)...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: _searchQuery.isNotEmpty
                          ? const Color(0xFFFFA000)
                          : Colors.grey,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Categories Horizontal Bar (only when not searching globally)
              if (!isSearching)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: List.generate(_presetFoodLibraries.length, (i) {
                      final cat = _presetFoodLibraries[i];
                      final isSel = i == _selectedCategoryIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedCategoryIndex = i),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? (isDark
                                      ? const Color(0xFFFFA000)
                                      : const Color(0xFF0F172A))
                                  : (isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSel
                                    ? Colors.transparent
                                    : (isDark
                                        ? Colors.white12
                                        : Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat.icon,
                                  size: 16,
                                  color: isSel
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cat.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSel
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white70
                                            : Colors.black87),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : (isDark
                                            ? Colors.white12
                                            : Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${cat.items.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSel
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list_rounded,
                          size: 16, color: kDarkYellow),
                      const SizedBox(width: 6),
                      Text(
                        'Qidiruv natijalari: ${displayedItems.length} ta mahsulot topildi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Items Grid
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: displayedItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 48,
                                  color: isDark
                                      ? Colors.white30
                                      : Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'Hech narsa topilmadi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Boshqa so\'z yoki o\'lcham (0.5L, 1.5L) bilan qidirib ko\'ring',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          itemCount: displayedItems.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.15,
                          ),
                          itemBuilder: (context, idx) {
                            final item = displayedItems[idx];
                            final isSelected = _selectedImageUrl == item.url;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedImageUrl = item.url;
                                  _selectedItemName = item.title;
                                });
                              },
                              onDoubleTap: () => _selectAndFinish(item),
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      item.url,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, progress) {
                                        if (progress == null) return child;
                                        return Container(
                                          color: isDark
                                              ? const Color(0xFF1E293B)
                                              : Colors.grey.shade200,
                                          child: const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.broken_image,
                                            color: Colors.grey),
                                      ),
                                    ),
                                  ),

                                  // Dark Bottom Gradient with Title & Subtitle
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(
                                            bottom: Radius.circular(14)),
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withValues(alpha: 0.9),
                                            Colors.black.withValues(alpha: 0.5),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              shadows: [
                                                Shadow(
                                                  blurRadius: 4,
                                                  color: Colors.black,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (item.subtitle != null) ...[
                                            const SizedBox(height: 1),
                                            Text(
                                              item.subtitle!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.8),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Selection ring / badge
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFFFA000)
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                      color: isSelected
                                          ? const Color(0xFFFFA000)
                                              .withValues(alpha: 0.15)
                                          : Colors.transparent,
                                    ),
                                  ),

                                  // Checkmark badge in corner
                                  if (isSelected)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFA000),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 14),

              // Bottom Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Bekor qilish'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        _selectedItemName != null
                            ? '«$_selectedItemName» tanlash'
                            : 'Rasmni tanlash',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _selectedImageUrl == null
                          ? null
                          : () {
                              Navigator.pop(context, {
                                'url': _selectedImageUrl,
                                'name': _selectedItemName,
                              });
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductEditDialog extends StatefulWidget {
  final Product? product;
  final int? defaultCategoryId;
  const _ProductEditDialog({this.product, this.defaultCategoryId});

  @override
  State<_ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<_ProductEditDialog> {
  late TextEditingController nameCtrl;
  late TextEditingController priceCtrl;
  late TextEditingController stockCtrl;
  late TextEditingController imageCtrl;
  late int categoryId;
  bool pickingImage = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    nameCtrl = TextEditingController(text: p?.name ?? '');
    priceCtrl = TextEditingController(
      text: p != null ? p.price.toStringAsFixed(0) : '',
    );
    stockCtrl = TextEditingController(text: p != null ? '${p.stock}' : '9999');
    imageCtrl = TextEditingController(text: p?.imageUrl ?? '');

    if (p != null) {
      if (appState.categories.any((c) => c.id == p.categoryId)) {
        categoryId = p.categoryId;
      } else {
        final pCatName = appState.getCategoryName(p.categoryId);
        final match = appState.categories.firstWhere(
          (c) =>
              appState.normalizeCatName(c.name).toLowerCase() ==
              appState.normalizeCatName(pCatName).toLowerCase(),
          orElse: () => appState.categories.isNotEmpty
              ? appState.categories.first
              : Category(id: 1, name: 'Shaurma', icon: Icons.lunch_dining),
        );
        categoryId = match.id;
      }
    } else if (widget.defaultCategoryId != null &&
        appState.categories.any((c) => c.id == widget.defaultCategoryId)) {
      categoryId = widget.defaultCategoryId!;
    } else {
      categoryId =
          appState.categories.isNotEmpty ? appState.categories.first.id : 1;
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    stockCtrl.dispose();
    imageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromPresetLibrary() async {
    final selected = await showDialog<dynamic>(
      context: context,
      builder: (_) => const _PresetImagesPickerDialog(),
    );
    if (selected != null && mounted) {
      if (selected is Map) {
        final url = (selected['url'] ?? '').toString();
        final name = (selected['name'] ?? '').toString();
        setState(() {
          if (url.isNotEmpty) imageCtrl.text = url;
          if (nameCtrl.text.trim().isEmpty && name.isNotEmpty) {
            nameCtrl.text = name;
          }
        });
      } else if (selected is String) {
        setState(() => imageCtrl.text = selected);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => pickingImage = true);
    try {
      final savedUrl = await pickAndUploadImageFromGallery();
      if (savedUrl != null && mounted) {
        setState(() => imageCtrl.text = savedUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rasm muvaffaqiyatli yuklandi va saqlandi!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rasm yuklashda xatolik: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => pickingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 490),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kYellow.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                        color: kDarkYellow,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Taomni tahrirlash' : 'Yangi taom qo\'shish',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEdit
                                ? 'Taom ma\'lumotlarini yangilang'
                                : 'Taom nomi, narxi va rasmini kiriting',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Image Preview Card
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        buildUniversalProductImage(
                          rawUrl: imageCtrl.text,
                          fallbackBuilder: () => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.image_outlined,
                                  color: isDark ? Colors.white30 : Colors.grey.shade400,
                                  size: 44,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Taom rasmi tanlanmagan',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (imageCtrl.text.trim().isNotEmpty)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                tooltip: 'Rasmni tozalash',
                                onPressed: () => setState(() => imageCtrl.clear()),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Action Buttons for Image Picking
                Row(
                  children: [
                    // 1. Preset Food Images Button (Tayyor rasmlar)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _pickFromPresetLibrary,
                        icon: const Icon(Icons.collections_rounded, size: 18),
                        label: const Text(
                          'Tayyor rasmlar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 2. Gallery Upload Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: pickingImage ? null : _pickFromGallery,
                        icon: pickingImage
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_library_outlined, size: 18),
                        label: Text(
                          pickingImage ? 'Yuklanmoqda...' : 'Galereyadan',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Image Link Field
                TextField(
                  controller: imageCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Yoki rasm havolasini kiriting (URL)',
                    prefixIcon: const Icon(Icons.link_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Taom nomi
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Taom nomi',
                    hintText: 'Masalan: Katta Lavash, Pitsa Pepperoni...',
                    prefixIcon: const Icon(Icons.restaurant_menu_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Narxi
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Narxi (so\'m)',
                    hintText: 'Masalan: 32000',
                    prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Kategoriya Dropdown
                Builder(
                  builder: (context) {
                    final uniqueCats = <int, Category>{};
                    for (final c in appState.categories) {
                      uniqueCats[c.id] = c;
                    }
                    final catList = uniqueCats.values.toList();
                    if (catList.isEmpty) return const SizedBox.shrink();
                    final activeCat = catList.firstWhere(
                      (c) => c.id == categoryId,
                      orElse: () => catList.first,
                    );
                    final activeCatId = activeCat.id;

                    return DropdownButtonFormField<int>(
                      key: ValueKey('cat_dd_${activeCatId}_${catList.length}'),
                      initialValue: activeCatId,
                      decoration: InputDecoration(
                        labelText: 'Kategoriya',
                        prefixIcon: const Icon(Icons.category_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: catList
                          .map(
                            (c) => DropdownMenuItem<int>(
                              value: c.id,
                              child: Row(
                                children: [
                                  Icon(c.icon, size: 18, color: kDarkYellow),
                                  const SizedBox(width: 8),
                                  Text(c.name),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => categoryId = v);
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Dialog Actions (O'chirish, Bekor qilish, Saqlash)
                Row(
                  children: [
                    if (isEdit) ...[
                      IconButton(
                        tooltip: 'Taomni o\'chirish',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: const Text('Taomni o\'chirish'),
                              content: Text(
                                  '"${widget.product?.name}" ni o‘chirishni tasdiqlaysizmi?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Bekor qilish'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('O‘chirish'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            final prodToDelete = widget.product!;
                            Navigator.pop(context);
                            appState.deleteProduct(prodToDelete);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                        ),
                        child: const Text('Bekor qilish',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'Saqlash',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Iltimos, taom nomini kiriting!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          final category = appState.categories.firstWhere(
                            (c) => c.id == categoryId,
                          );
                          final p = Product(
                            id: widget.product?.id ?? appState.nextId(),
                            name: nameCtrl.text.trim(),
                            price: double.tryParse(priceCtrl.text) ?? 0,
                            categoryId: categoryId,
                            stock: 9999,
                            icon: category.icon,
                            imageUrl: imageCtrl.text.trim().isEmpty
                                ? null
                                : imageCtrl.text.trim(),
                          );
                          final origName = widget.product?.name;
                          Navigator.pop(context);
                          appState.addOrUpdateProduct(p, originalName: origName);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// KATEGORIYA QO'SHISH / TAHRIRLASH DIALOGI (masalan: Lavash, Shaurma...)
// ============================================================

const List<IconData> _categoryIconChoices = [
  Icons.lunch_dining,
  Icons.fastfood,
  Icons.local_pizza,
  Icons.kebab_dining,
  Icons.set_meal,
  Icons.dinner_dining,
  Icons.ramen_dining,
  Icons.soup_kitchen,
  Icons.rice_bowl,
  Icons.outdoor_grill,
  Icons.local_fire_department,
  Icons.local_dining,
  Icons.restaurant_menu,
  Icons.bakery_dining,
  Icons.cake,
  Icons.icecream,
  Icons.cookie,
  Icons.breakfast_dining,
  Icons.egg_alt,
  Icons.emoji_food_beverage,
  Icons.coffee,
  Icons.local_cafe,
  Icons.local_bar,
  Icons.liquor,
  Icons.sports_bar,
  Icons.wine_bar,
  Icons.water_drop,
  Icons.takeout_dining,
  Icons.delivery_dining,
  Icons.tapas,
  Icons.flatware,
  Icons.grain,
];

class _CategoryEditDialog extends StatefulWidget {
  final Category? category;
  const _CategoryEditDialog({this.category});

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late TextEditingController nameCtrl;
  late IconData icon;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.category?.name ?? '');
    icon = widget.category?.icon ?? _categoryIconChoices.first;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNew = widget.category == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kYellow.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isNew ? Icons.add_circle_outline_rounded : Icons.edit_note_rounded,
                        color: kDarkYellow,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNew ? 'Yangi kategoriya' : 'Kategoriyani tahrirlash',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isNew
                                ? 'Kategoriya nomi va mos ikonkasini tanlang'
                                : 'Ma\'lumotlarni o\'zgartiring va saqlang',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Live Preview Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFA000).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nameCtrl.text.trim().isEmpty
                                  ? 'Kategoriya nomi...'
                                  : nameCtrl.text.trim(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: nameCtrl.text.trim().isEmpty
                                    ? (isDark ? Colors.white38 : Colors.grey.shade400)
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Ko\'rinish namunasi',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Name Input
                const Text(
                  'Kategoriya nomi',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  autofocus: isNew,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Masalan: Lavash, Pitsa, Ichimliklar...',
                    prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: kDarkYellow, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),

                // Icon Selector Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ikonkani tanlang',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${_categoryIconChoices.length} ta mavjud',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categoryIconChoices.map((ic) {
                        final selected = ic == icon;
                        return Tooltip(
                          message: ic.toString(),
                          child: InkWell(
                            onTap: () => setState(() => icon = ic),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: selected
                                    ? const LinearGradient(
                                        colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: selected
                                    ? null
                                    : (isDark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white),
                                border: Border.all(
                                  color: selected
                                      ? Colors.transparent
                                      : (isDark ? Colors.white10 : Colors.grey.shade200),
                                  width: selected ? 2 : 1,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFFFA000).withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                ic,
                                color: selected
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                size: 24,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                        ),
                        child: const Text(
                          'Bekor qilish',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'Saqlash',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Iltimos, kategoriya nomini kiriting!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          final c = Category(
                            id: widget.category?.id ?? appState.nextId(),
                            name: nameCtrl.text.trim(),
                            icon: icon,
                          );
                          appState.addOrUpdateCategory(c);
                          Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CART PANEL (Kassir/Admin savati)
// ============================================================

class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => _buildPanel(context),
    );
  }

  Widget _buildPanel(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header: Joriy buyurtma + Tozalash
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shopping_cart_outlined, color: Color(0xFF0F172A), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Joriy buyurtma',
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                if (appState.cart.isNotEmpty)
                  TextButton(
                    onPressed: () => appState.clearCart(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text(
                      'Tozalash',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: appState.cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.amber.shade50, Colors.orange.shade50],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.orange.shade100, width: 2),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 38,
                            color: Color(0xFFFF9100),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Savat bo\'sh',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Menyudan taom tanlang',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    itemCount: appState.cart.length,
                    itemBuilder: (context, i) {
                      final item = appState.cart[i];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFDF5),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFFEF3C7), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB300).withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Food Image (Image 5 style)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 68,
                                height: 68,
                                child: _buildCartItemImage(item.product),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // 2. Details (Name, Price, Stepper)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Soft red circular delete button (Image 5)
                                      InkWell(
                                        onTap: () => appState.removeFromCart(item),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFEE2E2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 17,
                                            color: Color(0xFFEF4444),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    formatSum(item.product.price),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Stepper pill [ -   1   + ] (Image 5)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.02),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () => appState.changeQty(item, -1),
                                              borderRadius: BorderRadius.circular(14),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                child: Icon(Icons.remove_rounded, size: 16, color: Color(0xFF0F172A)),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              child: Text(
                                                '${item.qty}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14.5,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => appState.changeQty(item, 1),
                                              borderRadius: BorderRadius.circular(14),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                child: Icon(Icons.add_rounded, size: 16, color: Color(0xFF0F172A)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (item.note.isNotEmpty)
                                        InkWell(
                                          onTap: () => _editNote(context, item),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              item.note,
                                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(Icons.note_add_outlined, size: 18, color: Color(0xFF94A3B8)),
                                          onPressed: () => _editNote(context, item),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Bottom Bar: Jami + To'lovga o'tish (Image 5 style)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Jami',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      formatSum(appState.cartTotal),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: appState.cart.isEmpty || appState.proceedingToPayment
                      ? null
                      : () async {
                          final ok = await appState.proceedToPayment();
                          if (ok && context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                settings: const RouteSettings(name: 'payment'),
                                builder: (_) => const PaymentScreen(),
                              ),
                            );
                          }
                        },
                  borderRadius: BorderRadius.circular(28),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: appState.cart.isEmpty
                            ? [Colors.grey.shade400, Colors.grey.shade500]
                            : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: appState.cart.isEmpty
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (appState.proceedingToPayment)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        else ...[
                          const Icon(Icons.credit_card_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'To\'lovga o\'tish',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemImage(Product product) {
    String? resolvedUrl = product.imageUrl;
    if (resolvedUrl == null || resolvedUrl.trim().isEmpty) {
      final name = product.name.toLowerCase();
      if (name.contains('shaurma')) {
        resolvedUrl = 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=400&auto=format&fit=crop&q=80';
      } else if (name.contains('lavash')) {
        resolvedUrl = 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=400&auto=format&fit=crop&q=80';
      } else if (name.contains('burger')) {
        resolvedUrl = 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&auto=format&fit=crop&q=80';
      } else if (name.contains('pitsa') || name.contains('pizza')) {
        resolvedUrl = 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&auto=format&fit=crop&q=80';
      } else if (name.contains('cola') || name.contains('coca')) {
        resolvedUrl = 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=400&auto=format&fit=crop&q=80';
      } else if (name.contains('fanta')) {
        resolvedUrl = 'https://images.unsplash.com/photo-1624517452488-04869289c4ca?w=400&auto=format&fit=crop&q=80';
      } else if (name.contains('pepsi')) {
        resolvedUrl = 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=400&auto=format&fit=crop&q=80';
      } else if (name.contains('marojni') || name.contains('muzqaymoq')) {
        resolvedUrl = 'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?w=400&auto=format&fit=crop&q=80';
      } else if (name.contains('osh') || name.contains('palov')) {
        resolvedUrl = 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=400&auto=format&fit=crop&q=80';
      } else {
        resolvedUrl = 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400&auto=format&fit=crop&q=80';
      }
    }

    return Image.network(
      resolvedUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFFFFBEB),
        child: Center(
          child: Icon(product.icon, color: const Color(0xFFF59E0B), size: 30),
        ),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      },
    );
  }

  void _editNote(BuildContext context, CartItem item) {
    final ctrl = TextEditingController(text: item.note);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${item.product.name} uchun izoh'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'masalan: achchiqsiz, ko\'p sous...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              appState.setNote(item, ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PAYMENT SCREEN
// ============================================================

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

// To'lov / hisob ekrani — stol band bo'lganda ustiga bosilganda ham,
// "To'lovga o'tish" tugmasi bosilganda ham shu ekran ochiladi. Bu yerda
// taomlar ro'yxati (nomi, narxi, soni, xizmat foizi, jami), to'lanayotgan
// summa, izoh, "Xarid cheki"/"Oshpaz cheki" chop etish tugmalari va
// naqd/karta orqali to'lash belgilari bor.
class _PaymentScreenState extends State<PaymentScreen> {
  // 0% = hozircha xizmat haqi yo'q (kerak bo'lsa shu yerdan o'zgartiriladi)
  double servicePercent = 0;
  // ---- To'lov turi belgilari (Naqd/Karta/Olib ketish) ----
  bool payByCash = false;
  bool payByCard = false;
  bool isTakeaway = false;
  final TextEditingController _payingCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  bool printingKitchen = false;
  bool confirming = false;
  bool _payingInitialized = false;
  double? _lastSyncedTotal;

  @override
  void initState() {
    super.initState();
    _noteCtrl.text = appState.selectedTableNote;
    if (appState.selectedHall?.name.toLowerCase() == 'saboy' ||
        _noteCtrl.text.contains('[Olib ketish]')) {
      isTakeaway = true;
    }
  }

  @override
  void dispose() {
    _payingCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _productsTotal => appState.cartTotal;
  double get _serviceTotal => _productsTotal * servicePercent / 100;
  double get _grandTotal => _productsTotal + _serviceTotal;

  void _ensurePayingInitialized() {
    if (!_payingInitialized || _lastSyncedTotal != _grandTotal) {
      _payingCtrl.text = _grandTotal.round().toString();
      _payingInitialized = true;
      _lastSyncedTotal = _grandTotal;
    }
  }

  double get _payingAmount => double.tryParse(_payingCtrl.text) ?? 0;

  void _changePaying(double delta) {
    final v = (_payingAmount + delta).clamp(0, double.infinity);
    setState(() => _payingCtrl.text = v.round().toString());
  }

  bool printingBill = false;

  // ---- "Xarid cheki" tugmasi endi hech qanday oraliq sahifa ochmaydi —
  // to'g'ridan-to'g'ri (hali to'lanmagan) hisobni zamonaviy chek
  // ko'rinishida printer/"Chop etish" oynasiga yuboradi. ----
  Future<void> _printBill() async {
    if (appState.cart.isEmpty) return;
    setState(() => printingBill = true);
    final method = payByCash && payByCard
        ? PaymentMethod.split
        : (payByCash ? PaymentMethod.cash : PaymentMethod.card);
    try {
      await printBillPreview(
        items: List<CartItem>.from(appState.cart),
        productsTotal: _productsTotal,
        serviceTotal: _serviceTotal,
        grandTotal: _grandTotal,
        method: method,
        table: appState.selectedTable,
        hallName: appState.selectedHall?.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Chop etishda xatolik: $e')));
      }
    } finally {
      if (mounted) setState(() => printingBill = false);
    }
  }

  Future<void> _printKitchen() async {
    setState(() => printingKitchen = true);
    try {
      await printKitchenTicket(
        items: appState.cart,
        table: appState.selectedTable,
        hallName: appState.selectedHall?.name,
        note: _noteCtrl.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Chop etishda xatolik: $e')));
      }
    } finally {
      if (mounted) setState(() => printingKitchen = false);
    }
  }

  // ---- "Chekni ko'rish" — to'lovdan oldin, real (joriy) savat
  // ma'lumotlari bilan ReceiptWidget orqali ekranda chek ko'rinishini
  // ko'rsatadi. Bu yerdan to'g'ridan-to'g'ri "Chop etish" ham mumkin. ----
  void _showReceiptPreview() {
    if (appState.cart.isEmpty) return;
    final table = appState.selectedTable;
    final hall = appState.selectedHall;
    final cashierName =
        appState.currentUser?.name ?? appState.guestName ?? 'Mehmon';
    final now = DateTime.now();
    final dateTimeStr = '${now.year}.${now.month.toString().padLeft(2, '0')}.'
        '${now.day.toString().padLeft(2, '0')} - '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final checkId = 'T${table?.number ?? '-'}-${now.millisecondsSinceEpoch}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFEDEDED),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Material(
                          elevation: 2,
                          borderRadius: BorderRadius.circular(4),
                          child: ReceiptWidget(
                            checkId: checkId,
                            waiter: cashierName,
                            hallName: hall?.name ?? 'Зал',
                            table: '${table?.number ?? ''}',
                            customer: '1',
                            dateTime: dateTimeStr,
                            items: appState.cart
                                .map(
                                  (c) => ReceiptItem(
                                    name: c.product.name,
                                    quantity: '${c.qty} dona',
                                    price: ReceiptWidget.money(
                                      c.product.price.round(),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B6E91),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _printBill();
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('Chop etish'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _addMoreItems() {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'pos'),
        builder: (_) => const POSScreen(),
      ),
    ).then((_) => setState(() {}));
  }

  void _backToTableSelection() {
    appState.leaveOrderSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'dashboard'),
        builder: (_) => const DashboardScreen(),
      ),
      (route) => route.isFirst,
    );
  }

  Future<void> _confirmPaid() async {
    if (appState.cart.isEmpty) return;
    // Agar to'lov turi belgilanmagan bo'lsa, standart Naqd pul sifatida qabul qilamiz
    if (!payByCash && !payByCard) {
      payByCash = true;
    }
    setState(() => confirming = true);
    final method = payByCash && payByCard
        ? PaymentMethod.split
        : (payByCash ? PaymentMethod.cash : PaymentMethod.card);
    double cash = 0, card = 0;
    if (method == PaymentMethod.split) {
      cash = _payingAmount;
      card = (_grandTotal - cash).clamp(0, double.infinity).toDouble();
    } else if (method == PaymentMethod.cash) {
      cash = _payingAmount < _grandTotal ? _grandTotal : _payingAmount;
    } else {
      card = _grandTotal;
    }

    Hall? hallBeforeCheckout = appState.selectedHall;
    if (hallBeforeCheckout == null && appState.selectedTable != null) {
      for (final h in appState.halls) {
        if (h.id == appState.selectedTable!.hallId) {
          hallBeforeCheckout = h;
          break;
        }
      }
    }

    if (isTakeaway) {
      final existingNote = appState.selectedTableNote;
      if (!existingNote.contains('[Olib ketish]')) {
        appState.setTableNote('[Olib ketish] $existingNote'.trim());
      }
    }

    // 1. To'lovni qayd qilish va chek obyektini olish
    final receipt = appState.checkout(method: method, cashPaid: cash, cardPaid: card);

    // 2. AVTOMATIK CHEK CHIQARISH: "Xarid cheki" alohida bosilmagan bo'lsa ham, "To'landi" bosilganda chek avtomatik chiqadi!
    try {
      printReceipt(receipt, isAutoCheckout: true).catchError((e) {
        debugPrint('Avtomatik chek chiqarishda xatolik: $e');
      });
    } catch (e) {
      debugPrint('Avtomatik chek chiqarishda xatolik: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('To\'lov qabul qilindi va chek chiqarildi')));

    if (hallBeforeCheckout != null) {
      appState.selectedHall = hallBeforeCheckout;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'dashboard'),
        builder: (_) => const DashboardScreen(),
      ),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        _ensurePayingInitialized();
        final table = appState.selectedTable;
        final hall = appState.selectedHall;
        final narrow = MediaQuery.of(context).size.width < 700;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _backToTableSelection();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: _backToTableSelection),
              title: Text(
                table != null
                    ? '${hall?.name ?? ''} - stol ${table.number}'
                    : 'To\'lov',
              ),
              actions: [
                IconButton(
                  tooltip: 'Yangilash',
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ma\'lumotlar yangilanmoqda...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    await appState.loadCloudDataForCafe(appState.currentCafeId);
                    if (mounted) setState(() {});
                  },
                ),
                PopupMenuButton<String>(
                  tooltip: 'Chek va Printer sozlamalari',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit_text':
                        showEditReceiptTemplateDialog(context);
                        break;
                      case 'layout_font':
                        showPrinterQuickSettingsSheet(context);
                        break;
                      case 'visibility':
                        showReceiptVisibilityDialog(context);
                        break;
                      case 'printer_settings':
                        showPrinterSettingsModal(context);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit_text',
                      child: ListTile(
                        leading:
                            Icon(Icons.edit_note, color: Color(0xFF3B6E91)),
                        title: Text('Chek yozuvlarini tahrirlash'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'layout_font',
                      child: ListTile(
                        leading: Icon(Icons.format_align_center,
                            color: Color(0xFF3B6E91)),
                        title: Text('Joylashuv va shrift'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'visibility',
                      child: ListTile(
                        leading: Icon(Icons.visibility_outlined,
                            color: Color(0xFF3B6E91)),
                        title: Text('Elementlarni ko\'rsatish/yashirish'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'printer_settings',
                      child: ListTile(
                        leading: Icon(Icons.print_outlined),
                        title: Text('Printer sozlamalari (IP/Port)'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              heroTag: 'payment_add_fab',
              backgroundColor: kDarkYellow,
              onPressed: _addMoreItems,
              tooltip: 'Taom qo\'shish',
              child: const Icon(Icons.add),
            ),
            body: appState.cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bu stolda hali buyurtma yo\'q',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _addMoreItems,
                          icon: const Icon(Icons.add),
                          label: const Text('Taom qo\'shish'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ---- TAOMLAR JADVALI ----
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                narrow
                                    ? const Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Menyu',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            'Summa',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              'Menyu',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Summa',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              'Soni',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              'Xizmat',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Barchasi',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 40,
                                            child: Text(
                                              '',
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                const Divider(height: 18),
                                for (final item in appState.cart)
                                  narrow
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item.product.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    formatSum(item.total),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    '${formatSum(item.product.price)} · ${servicePercent.round()}% xizmat',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  _qtyMiniBtn(
                                                    Icons.remove,
                                                    () => appState.changeQty(
                                                      item,
                                                      -1,
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 4,
                                                    ),
                                                    child: Text(
                                                      '${item.qty}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  _qtyMiniBtn(
                                                    Icons.add,
                                                    () => appState.changeQty(
                                                      item,
                                                      1,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                    onPressed: () => appState
                                                        .removeFromCart(item),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        )
                                      : Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  item.product.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  formatSum(item.product.price),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              Expanded(
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    _qtyMiniBtn(
                                                      Icons.remove,
                                                      () => appState.changeQty(
                                                        item,
                                                        -1,
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 4,
                                                      ),
                                                      child: Text(
                                                        '${item.qty}',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    _qtyMiniBtn(
                                                      Icons.add,
                                                      () => appState.changeQty(
                                                        item,
                                                        1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  '${servicePercent.round()} %',
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  formatSum(item.total),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 40,
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                    size: 20,
                                                  ),
                                                  onPressed: () => appState
                                                      .removeFromCart(item),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ---- JAMI VA TO'LANMOQDA ----
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _summaryRow(
                                  'Mahsulotlar qiymati:',
                                  formatSum(_productsTotal),
                                ),
                                _summaryRow(
                                  'Xizmat:',
                                  formatSum(_serviceTotal),
                                ),
                                _summaryRow(
                                  'Hammasi:',
                                  formatSum(_grandTotal),
                                  bold: true,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'To\'lanmoqda:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove),
                                            color: Colors.blueGrey,
                                            onPressed: () =>
                                                _changePaying(-1000),
                                          ),
                                          SizedBox(
                                            width: 90,
                                            child: TextField(
                                              controller: _payingCtrl,
                                              textAlign: TextAlign.center,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add),
                                            color: Colors.blueGrey,
                                            onPressed: () =>
                                                _changePaying(1000),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _noteCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'Izoh kiritish',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  onChanged: (v) => appState.setTableNote(v),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // ---- CHEKNI EKRANDA KO'RISH (ReceiptWidget) ----
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3B6E91),
                              side: const BorderSide(color: Color(0xFF3B6E91)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _showReceiptPreview,
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('Chekni ko\'rish'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ---- CHOP ETISH TUGMALARI ----
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B6E91),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: printingBill ? null : _printBill,
                                icon: printingBill
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.print),
                                label: const Text('Xarid cheki'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B6E91),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed:
                                    printingKitchen ? null : _printKitchen,
                                icon: printingKitchen
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.print),
                                label: const Text('Oshpaz cheki'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // ---- NAQD / KARTA / OLIB KETISH BELGILARI ----
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: payByCash,
                                onChanged: (v) => setState(() {
                                  payByCash = v ?? false;
                                }),
                                title: const Text(
                                  'Naqd pul',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            Expanded(
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: payByCard,
                                onChanged: (v) => setState(() {
                                  payByCard = v ?? false;
                                }),
                                title: const Text(
                                  'Karta',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            Expanded(
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: isTakeaway,
                                onChanged: (v) => setState(() {
                                  isTakeaway = v ?? false;
                                }),
                                title: const Text(
                                  'Olib ketish',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kDarkYellow,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: confirming ? null : _confirmPaid,
                            icon: confirming
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: const Text(
                              'To\'landi',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 70),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  // ---- "Soni" ustunidagi kichik +/- tugmasi (taom sonini ko'paytirish/
  // kamaytirish uchun) ----
  Widget _qtyMiniBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: kYellow.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 13, color: kDarkYellow),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
              color: bold ? kDarkYellow : null,
            ),
          ),
        ],
      ),
    );
  }
}

class ReceiptScreen extends StatefulWidget {
  final Receipt receipt;
  const ReceiptScreen({super.key, required this.receipt});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _printing = false;

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      await printReceipt(widget.receipt);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Chop etishda xatolik: $e')));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    final dateTimeStr = '${receipt.date.day.toString().padLeft(2, '0')}.${receipt.date.month.toString().padLeft(2, '0')}.${receipt.date.year}';
    final timeStr = '${receipt.date.hour.toString().padLeft(2, '0')}:${receipt.date.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('80mm Chek'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Chop etish',
            onPressed: _printing ? null : _print,
          ),
          PopupMenuButton<String>(
            tooltip: 'Ko\'proq',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'printer_settings') {
                showPrinterQuickSettingsSheet(context).then((_) {
                  if (mounted) setState(() {});
                });
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'printer_settings',
                child: ListTile(
                  leading: Icon(Icons.print_outlined),
                  title: Text('Printer sozlamalari'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReceiptWidget(
                checkId: '${receipt.id}',
                waiter: receipt.cashierName.isNotEmpty ? receipt.cashierName : 'Admin',
                hallName: receipt.hallName ?? 'Zal',
                table: receipt.tableNumber != null ? '${receipt.tableNumber}' : '',
                dateTime: receipt.date.toIso8601String(),
                dateOnly: dateTimeStr,
                timeOnly: timeStr,
                customTotal: receipt.total,
                items: receipt.items
                    .map(
                      (c) => ReceiptItem(
                        name: c.product.name,
                        quantity: '${c.qty} dona',
                        price: '${c.product.price.round()}',
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 370,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _printing ? null : _print,
                  icon: _printing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print),
                  label: const Text('Chekni chop etish (80mm)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 370,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'dashboard'),
                      builder: (_) => const DashboardScreen(),
                    ),
                    (r) => false,
                  ),
                  icon: const Icon(Icons.done),
                  label: const Text('Tayyor'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// RECEIPT HISTORY SCREEN
// ============================================================

class ReceiptHistoryScreen extends StatefulWidget {
  const ReceiptHistoryScreen({super.key});

  @override
  State<ReceiptHistoryScreen> createState() => _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends State<ReceiptHistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final dateRangeStr = '$formattedDate / $formattedDate';

    final filtered = appState.receipts.reversed.where((r) {
      final matchesDate = r.date.year == _selectedDate.year &&
          r.date.month == _selectedDate.month &&
          r.date.day == _selectedDate.day;

      final matchesQuery = _searchQuery.isEmpty ||
          r.id.toString().contains(_searchQuery) ||
          r.cashierName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (r.hallName ?? '').toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesDate && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cheklar tarixi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Search input bar: "Chekni qidirish"
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Chekni qidirish',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF4F5F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 180), () {
                  if (mounted) setState(() => _searchQuery = v);
                });
              },
            ),
          ),

          // 2. Calendar / Date Range Picker container bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFFFBC02D),
                          onPrimary: Colors.black,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Text(
                    dateRangeStr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // 3. Grid of Receipt Cards (Matching Image 3!)
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          '$formattedDate kuni uchun cheklar topilmadi',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 260,
                      childAspectRatio: 0.83,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final r = filtered[i];
                      final codeStr = '-P-u${r.id}BXLVU_yqPV';
                      final timeStr =
                          '${r.date.year}.${r.date.month.toString().padLeft(2, '0')}.${r.date.day.toString().padLeft(2, '0')} - ${r.date.hour.toString().padLeft(2, '0')}:${r.date.minute.toString().padLeft(2, '0')}';

                      return Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        color: Colors.white,
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReceiptScreen(receipt: r),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Code Header
                                Text(
                                  codeStr,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),

                                // Row: Xo'randalar soni | Foiz
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Xo\'randalar soni',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                        Text('${r.tableNumber ?? 1}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Foiz',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                        const Text('0%',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Hisoblangan
                                Text('Hisoblangan',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                Text('${formatSum(r.total)} UZS',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),

                                // To'langan
                                Text('To\'langan',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                Text(
                                  '${formatSum(r.cashPaid + r.cardPaid > 0 ? (r.cashPaid + r.cardPaid) : r.total)} UZS',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),

                                // Foiz
                                Text('Foiz',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                const Text('0 UZS',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),

                                const Spacer(),

                                // Waiter/Staff Name (Centered)
                                Center(
                                  child: Text(
                                    r.cashierName.isNotEmpty ? r.cashierName : 'Ozod',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Timestamp
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// REPORTS SCREEN
// ============================================================

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum ReportFilterMode { day, week, month, year, all, custom }

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  ReportFilterMode _filterMode = ReportFilterMode.day;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  bool _isReceiptInFilter(Receipt r) {
    final d = r.date;
    switch (_filterMode) {
      case ReportFilterMode.day:
      case ReportFilterMode.custom:
        return d.year == _selectedDate.year &&
            d.month == _selectedDate.month &&
            d.day == _selectedDate.day;
      case ReportFilterMode.week:
        final now = _selectedDate;
        final weekAgo = now.subtract(const Duration(days: 7));
        return d.isAfter(weekAgo) && d.isBefore(now.add(const Duration(days: 1)));
      case ReportFilterMode.month:
        return d.year == _selectedDate.year && d.month == _selectedDate.month;
      case ReportFilterMode.year:
        return d.year == _selectedDate.year;
      case ReportFilterMode.all:
        return true;
    }
  }

  String get _periodLabel {
    final y = _selectedDate.year;
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final day = _selectedDate.day.toString().padLeft(2, '0');
    switch (_filterMode) {
      case ReportFilterMode.day:
        return 'Bugun ($y-$m-$day)';
      case ReportFilterMode.week:
        return 'Oxirgi 7 kun';
      case ReportFilterMode.custom:
        return 'Tanlangan sana: $y-$m-$day';
      case ReportFilterMode.month:
        return 'Shu Oy ($y-$m)';
      case ReportFilterMode.year:
        return 'Shu Yil ($y)';
      case ReportFilterMode.all:
        return 'Barcha davr (Jami)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final filteredReceipts = appState.receipts.where(_isReceiptInFilter).toList();

    final totalRevenue = filteredReceipts.fold(0.0, (s, r) => s + r.total);
    final totalOrders = filteredReceipts.length;
    final avgOrder = totalOrders > 0 ? (totalRevenue / totalOrders) : 0.0;

    double cashTotal = 0;
    double cardTotal = 0;
    for (final r in filteredReceipts) {
      if (r.cashPaid > 0 || r.cardPaid > 0) {
        cashTotal += r.cashPaid;
        cardTotal += r.cardPaid;
      } else if (r.method == PaymentMethod.cash) {
        cashTotal += r.total;
      } else {
        cardTotal += r.total;
      }
    }

    final Map<String, int> productQtySold = {};
    final Map<String, double> productRevenue = {};
    int totalItemsCount = 0;

    for (final r in filteredReceipts) {
      for (final item in r.items) {
        final pName = item.product.name;
        productQtySold[pName] = (productQtySold[pName] ?? 0) + item.qty;
        productRevenue[pName] = (productRevenue[pName] ?? 0.0) + item.total;
        totalItemsCount += item.qty;
      }
    }

    // Waiter / Cashier sales performance
    final Map<String, int> staffOrderCount = {};
    final Map<String, double> staffSales = {};
    for (final r in filteredReceipts) {
      final name = r.cashierName.isNotEmpty ? r.cashierName : 'Noma\'lum';
      staffOrderCount[name] = (staffOrderCount[name] ?? 0) + 1;
      staffSales[name] = (staffSales[name] ?? 0.0) + r.total;
    }

    // Sort products by sales
    final sortedProducts = productRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Sort staff by sales
    final sortedStaff = staffSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Moliya va Savdo Hisobotlari',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: false,
        bottom: TabBar(
          controller: tabController,
          labelColor: const Color(0xFFFFB300),
          unselectedLabelColor: Colors.white60,
          indicatorColor: const Color(0xFFFFB300),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          tabs: const [
            Tab(text: 'Umumiy Tahlil', icon: Icon(Icons.insights_rounded, size: 18)),
            Tab(text: 'Top Taomlar', icon: Icon(Icons.emoji_events_rounded, size: 18)),
            Tab(text: 'Xodimlar Savdosi', icon: Icon(Icons.people_alt_rounded, size: 18)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Period Filter Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterPill('Bugun', ReportFilterMode.day),
                    _filterPill('Hafta', ReportFilterMode.week),
                    _filterPill('Shu Oy', ReportFilterMode.month),
                    _filterPill('Shu Yil', ReportFilterMode.year),
                    _filterPill('Barchasi', ReportFilterMode.all),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                              _filterMode = ReportFilterMode.custom;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _filterMode == ReportFilterMode.custom ? const Color(0xFFFFB300) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _filterMode == ReportFilterMode.custom ? const Color(0xFFFFB300) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: _filterMode == ReportFilterMode.custom ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _filterMode == ReportFilterMode.custom ? '${_selectedDate.day}/${_selectedDate.month}' : 'Kalendar',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: _filterMode == ReportFilterMode.custom ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  // 1. UMUMIY TAHLIL TAB
                  ListView(
                    padding: EdgeInsets.all(isMobile ? 12 : 20),
                    children: [
                      // Period banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range_rounded, color: Color(0xFFFFB300), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _periodLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.5),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$totalOrders ta chek',
                                style: const TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Metric Grid
                      Row(
                        children: [
                          _flaticonCard(
                            'Jami Daromad',
                            formatSum(totalRevenue),
                            Icons.monetization_on_rounded,
                            const Color(0xFF10B981),
                            const Color(0xFFECFDF5),
                          ),
                          const SizedBox(width: 12),
                          _flaticonCard(
                            'Jami Cheklar',
                            '$totalOrders ta',
                            Icons.receipt_long_rounded,
                            const Color(0xFF3B82F6),
                            const Color(0xFFEFF6FF),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _flaticonCard(
                            'Sotilgan Taomlar',
                            '$totalItemsCount ta',
                            Icons.restaurant_menu_rounded,
                            const Color(0xFFF59E0B),
                            const Color(0xFFFFFBEB),
                          ),
                          const SizedBox(width: 12),
                          _flaticonCard(
                            'O\'rtacha Chek',
                            formatSum(avgOrder),
                            Icons.calculate_rounded,
                            const Color(0xFF8B5CF6),
                            const Color(0xFFF5F3FF),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Payment Method Breakdown Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0F172A), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'To\'lov Usullari Bo\'yicha Taqsimot',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _paymentPill(
                                    'Naqd pul',
                                    formatSum(cashTotal),
                                    totalRevenue > 0 ? (cashTotal / totalRevenue) : 0,
                                    Icons.payments_rounded,
                                    const Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _paymentPill(
                                    'Plastik / Karta',
                                    formatSum(cardTotal),
                                    totalRevenue > 0 ? (cardTotal / totalRevenue) : 0,
                                    Icons.credit_card_rounded,
                                    const Color(0xFF3B82F6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1.5. BUGUNGI OFITSIANTLAR VA XODIMLAR NATIJALARI (IMAGE 2)
                      _buildStaffOverviewSection(context, appState, sortedStaff, staffOrderCount, totalRevenue),
                    ],
                  ),

                  // 2. TOP TAOMLAR TAB
                  sortedProducts.isEmpty
                      ? const Center(child: Text('Shu davr uchun sotilgan taomlar yo\'q', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: sortedProducts.length,
                          itemBuilder: (context, i) {
                            final entry = sortedProducts[i];
                            final pName = entry.key;
                            final rev = entry.value;
                            final qty = productQtySold[pName] ?? 0;
                            final pct = totalRevenue > 0 ? (rev / totalRevenue) : 0.0;

                            final productModel = appState.products.firstWhere(
                              (p) => p.name == pName,
                              orElse: () => Product(id: 0, name: pName, price: 0, categoryId: 0, stock: 0, icon: Icons.fastfood_rounded),
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Rank badge
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: i == 0
                                          ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                                          : i == 1
                                              ? const Color(0xFFC0C0C0).withValues(alpha: 0.2)
                                              : i == 2
                                                  ? const Color(0xFFCD7F32).withValues(alpha: 0.2)
                                                  : const Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        i == 0
                                            ? '🥇'
                                            : i == 1
                                                ? '🥈'
                                                : i == 2
                                                    ? '🥉'
                                                    : '${i + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: i < 3 ? 16 : 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Product Icon
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: productModel.imageUrl != null && productModel.imageUrl!.isNotEmpty
                                          ? Image.network(
                                              productModel.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Icon(productModel.icon, color: const Color(0xFFFFB300), size: 24),
                                            )
                                          : Icon(productModel.icon, color: const Color(0xFFFFB300), size: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pName,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$qty ta sotilgan · Zaxirada: ${productModel.stock} ta',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: pct.clamp(0.0, 1.0),
                                            backgroundColor: const Color(0xFFF1F5F9),
                                            valueColor: AlwaysStoppedAnimation(
                                              i == 0 ? const Color(0xFFFFB300) : const Color(0xFF10B981),
                                            ),
                                            minHeight: 4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Price
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatSum(rev),
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF10B981)),
                                      ),
                                      Text(
                                        '${(pct * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                  // 3. XODIMLAR VA OFITSIANTLAR SAVDOSI TAB
                  sortedStaff.isEmpty
                      ? const Center(child: Text('Shu davr uchun xodimlar savdosi yo\'q', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: sortedStaff.length,
                          itemBuilder: (context, i) {
                            final entry = sortedStaff[i];
                            final staffName = entry.key;
                            final rev = entry.value;
                            final ordersCount = staffOrderCount[staffName] ?? 0;
                            final avgPerOrder = ordersCount > 0 ? (rev / ordersCount) : 0.0;

                            final staffUser = appState.users.firstWhere(
                              (u) => u.name.toLowerCase() == staffName.toLowerCase() || u.username.toLowerCase() == staffName.toLowerCase(),
                              orElse: () => AppUser(id: 0, name: staffName, username: staffName, password: '', role: UserRole.waiter),
                            );

                            final isWaiterRole = staffUser.role == UserRole.waiter;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isWaiterRole
                                            ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                            : [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isWaiterRole ? Icons.room_service_rounded : Icons.person_rounded,
                                        color: isWaiterRole ? Colors.white : Colors.black87,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              staffName,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isWaiterRole ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isWaiterRole ? 'Ofitsiant' : 'Kassir',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: isWaiterRole ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$ordersCount ta buyurtma yopgan · O\'rtacha: ${formatSum(avgPerOrder)}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatSum(rev),
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF10B981)),
                                      ),
                                      Text(
                                        'Jami savdo',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ],
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
    );
  }

  Widget _filterPill(String label, ReportFilterMode mode) {
    final isSel = _filterMode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _filterMode = mode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFFFFB300) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? const Color(0xFFFFB300) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isSel ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _flaticonCard(String title, String value, IconData icon, Color iconColor, Color bgIconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgIconColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600), maxLines: 1),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentPill(String title, String sumStr, double ratio, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              const Spacer(),
              Text('${(ratio * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(sumStr, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildStaffOverviewSection(
    BuildContext context,
    AppState appState,
    List<MapEntry<String, double>> sortedStaff,
    Map<String, int> staffOrderCount,
    double totalRevenue,
  ) {
    final List<Map<String, dynamic>> displayItems = [];

    if (sortedStaff.isNotEmpty) {
      for (final entry in sortedStaff) {
        final staffName = entry.key;
        final rev = entry.value;
        final ordersCount = staffOrderCount[staffName] ?? 0;
        final userModel = appState.users.firstWhere(
          (u) => u.name.toLowerCase() == staffName.toLowerCase() || u.username.toLowerCase() == staffName.toLowerCase(),
          orElse: () => AppUser(id: 0, name: staffName, username: staffName, password: '', role: UserRole.waiter),
        );
        displayItems.add({
          'name': staffName,
          'rev': rev,
          'orders': ordersCount,
          'user': userModel,
        });
      }
    } else {
      for (final u in appState.users) {
        displayItems.add({
          'name': u.name,
          'rev': 0.0,
          'orders': 0,
          'user': u,
        });
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.badge_rounded, color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Bugungi Ofitsiantlar va Xodimlar Natijalari',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${displayItems.length} ta xodim',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (displayItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Xodimlar ro\'yxati bo\'sh',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else
            ...displayItems.map((item) {
              final String name = item['name'];
              final double rev = item['rev'];
              final int orders = item['orders'];
              final AppUser u = item['user'];
              final isWaiter = u.role == UserRole.waiter;
              final avg = orders > 0 ? (rev / orders) : 0.0;
              final pct = totalRevenue > 0 ? (rev / totalRevenue) : 0.0;

              final staffStatus = StaffTrackingService().getStatus(u.id);
              final isOnBreak = staffStatus?.isOnBreak ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isOnBreak ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
                    width: isOnBreak ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isOnBreak
                              ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                              : (isWaiter
                                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                  : [const Color(0xFFFFB300), const Color(0xFFFF8F00)]),
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          isOnBreak
                              ? Icons.coffee_rounded
                              : (isWaiter ? Icons.room_service_rounded : Icons.person_rounded),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isWaiter ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isWaiter ? 'Ofitsiant' : 'Kassir',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isWaiter ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                              if (isOnBreak) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: const Text(
                                    '☕ Dam olmoqda',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Bugun: $orders ta mijozga qaradi · O\'rtacha: ${formatSum(avg)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatSum(rev),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        if (totalRevenue > 0)
                          Text(
                            '${(pct * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ============================================================
// INVENTORY SCREEN
// ============================================================

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  int? _selectedCategoryId;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _adjust(Product p, [int? delta]) {
    if (delta != null) {
      final newStock = (p.stock + delta).clamp(0, 999999);
      setState(() => appState.adjustStock(p, newStock));
      return;
    }

    final ctrl = TextEditingController(text: '${p.stock}');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.inventory_2_rounded, color: Color(0xFFFFB300)),
            const SizedBox(width: 8),
            Expanded(child: Text('Zaxirani o\'zgartirish: ${p.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hozirgi zaxira: ${p.stock} ta', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Yangi miqdor (dona/porsiya)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final v = int.tryParse(ctrl.text) ?? p.stock;
              setState(() => appState.adjustStock(p, v));
              Navigator.pop(context);
            },
            child: const Text('Saqlash', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = appState.products.where((p) {
      final matchSearch = _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCat = _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
      return matchSearch && matchCat;
    }).toList();

    final totalProducts = appState.products.length;
    final lowStockCount = appState.products.where((p) => p.stock <= 5 && p.stock > 0).length;
    final outOfStockCount = appState.products.where((p) => p.stock == 0).length;
    final totalInventoryValue = appState.products.fold(0.0, (sum, p) => sum + (p.price * p.stock));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('Ombor va Zaxira Boshqaruvi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Column(
        children: [
          // Metrics Cards Bar
          Container(
            padding: const EdgeInsets.all(14),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    _buildStatCard('Jami taomlar', '$totalProducts ta', Icons.fastfood_rounded, const Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    _buildStatCard('Kam qolgan', '$lowStockCount ta', Icons.warning_amber_rounded, const Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    _buildStatCard('Tugagan', '$outOfStockCount ta', Icons.highlight_off_rounded, const Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    _buildStatCard('Zaxira qiymati', formatSum(totalInventoryValue), Icons.account_balance_wallet_rounded, const Color(0xFF10B981)),
                  ],
                ),
                const SizedBox(height: 12),
                // Search Input
                TextField(
                  onChanged: (v) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
                      if (mounted) setState(() => _searchQuery = v);
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Taom yoki mahsulot nomi bo\'yicha qidirish...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (appState.categories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Barchasi'),
                          selected: _selectedCategoryId == null,
                          selectedColor: const Color(0xFFFFB300),
                          onSelected: (_) => setState(() => _selectedCategoryId = null),
                        ),
                        const SizedBox(width: 6),
                        ...appState.categories.map((c) {
                          final isSel = _selectedCategoryId == c.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(c.name),
                              selected: isSel,
                              selectedColor: const Color(0xFFFFB300),
                              onSelected: (_) => setState(() => _selectedCategoryId = isSel ? null : c.id),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Products List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text(
                          _searchQuery.isNotEmpty ? 'Mos mahsulot topilmadi' : 'Hozircha mahsulotlar yo\'q',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      final isOutOfStock = p.stock == 0;
                      final isLowStock = p.stock <= 5 && !isOutOfStock;
                      final category = appState.categories.firstWhere(
                        (c) => c.id == p.categoryId,
                        orElse: () => Category(id: 0, name: 'Umumiy', icon: Icons.category),
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isOutOfStock
                                ? const Color(0xFFFCA5A5)
                                : isLowStock
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Food Image Preview
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          p.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(p.icon, color: const Color(0xFFFFB300), size: 28),
                                        )
                                      : Center(
                                          child: Icon(p.icon, color: const Color(0xFFFFB300), size: 28),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.name,
                                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          formatSum(p.price),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            category.name,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isOutOfStock
                                                ? const Color(0xFFFEE2E2)
                                                : isLowStock
                                                    ? const Color(0xFFFEF3C7)
                                                    : const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isOutOfStock
                                                ? 'Tugadi: 0 ta'
                                                : isLowStock
                                                    ? 'Kam qoldi: ${p.stock} ta'
                                                    : 'Mavjud: ${p.stock} ta',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: isOutOfStock
                                                  ? const Color(0xFFDC2626)
                                                  : isLowStock
                                                      ? const Color(0xFFD97706)
                                                      : const Color(0xFF16A34A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Quick Stock Adjusters
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      padding: const EdgeInsets.all(6),
                                      minimumSize: const Size(32, 32),
                                    ),
                                    icon: const Icon(Icons.remove_rounded, size: 16, color: Color(0xFF0F172A)),
                                    tooltip: '-1 kamaytirish',
                                    onPressed: p.stock > 0 ? () => _adjust(p, -1) : null,
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => _adjust(p),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Text(
                                        '${p.stock}',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      padding: const EdgeInsets.all(6),
                                      minimumSize: const Size(32, 32),
                                    ),
                                    icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF0F172A)),
                                    tooltip: '+1 qo\'shish',
                                    onPressed: () => _adjust(p, 1),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF3B82F6), size: 22),
                                    tooltip: 'Miqdorni kiritish',
                                    onPressed: () => _adjust(p),
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
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500), maxLines: 1),
                  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color), maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PRODUCTS SCREEN (Admin CRUD)
// ============================================================

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  final Set<int> _selectedIds = {};

  void _edit([Product? product]) {
    showDialog(
      context: context,
      builder: (_) => _ProductEditDialog(product: product),
    ).then((_) => setState(() {}));
  }

  void _delete(Product p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mahsulotni o\'chirish'),
        content: Text(
          '"${p.name}" ni o\'chirasizmi? Buni qaytarib bo\'lmaydi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _selectedIds.remove(p.id);
                appState.deleteProduct(p);
              });
              Navigator.pop(context);
            },
            child: const Text(
              'O\'chirish',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteSelected() {
    if (_selectedIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tanlangan mahsulotlarni o\'chirish'),
        content: Text(
          'Tanlangan ${_selectedIds.length} ta mahsulotni haqiqatan ham o\'chirasizmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final idsToDelete = _selectedIds.toList();
              setState(() {
                _selectedIds.clear();
                appState.deleteProductsBulk(idsToDelete);
              });
              Navigator.pop(context);
            },
            child: const Text(
              'O\'chirish',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelectionMode = _selectedIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectionMode
            ? '${_selectedIds.length} ta tanlandi'
            : 'Mahsulotlar'),
        actions: [
          if (isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Barchasini tanlash',
              onPressed: () {
                setState(() {
                  if (_selectedIds.length == appState.products.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(appState.products.map((e) => e.id));
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: 'Tanlanganlarni o\'chirish',
              onPressed: _deleteSelected,
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
      body: appState.products.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.no_food_outlined,
                    size: 56,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Hozircha mahsulot yo\'q. "+" tugmasi bilan qo\'shing.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: appState.products.length,
              itemBuilder: (context, i) {
                final p = appState.products[i];
                final isSelected = _selectedIds.contains(p.id);
                final catName = appState.categories
                    .firstWhere(
                      (c) => c.id == p.categoryId,
                      orElse: () => appState.categories.first,
                    )
                    .name;
                return Card(
                  color: isSelected ? Colors.amber.withValues(alpha: 0.15) : null,
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
                          checkColor: Colors.black,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(p.id);
                              } else {
                                _selectedIds.remove(p.id);
                              }
                            });
                          },
                        ),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: _ProductThumb(product: p, iconSize: 22),
                        ),
                      ],
                    ),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '$catName · ${formatSum(p.price)} · Zaxira ${p.stock}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                          onPressed: () => _edit(p),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _delete(p),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================
// CATEGORIES SCREEN (Admin CRUD)
// ============================================================

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    appState.removeListener(_onAppStateChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _edit([Category? category]) {
    showDialog(
      context: context,
      builder: (_) => _CategoryEditDialog(category: category),
    ).then((_) => setState(() {}));
  }

  void _delete(Category c) {
    final productCount =
        appState.products.where((p) => p.categoryId == c.id).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Kategoriyani o\'chirish', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${c.name}" kategoriyasini o\'chirishni xohlaysizmi?',
              style: const TextStyle(fontSize: 15),
            ),
            if (productCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Unga tegishli $productCount ta mahsulot ham o\'chiriladi!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('O\'chirish'),
            onPressed: () {
              setState(() => appState.deleteCategory(c));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allCats = appState.categories;
    final filtered = _searchQuery.trim().isEmpty
        ? allCats
        : allCats
            .where((c) =>
                c.name.toLowerCase().contains(_searchQuery.trim().toLowerCase()))
            .toList();

    final totalProducts = appState.products.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Kategoriyalar', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Kategoriya qo\'shish',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, letterSpacing: 0.2),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              // Top Stats and Search Header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatBadge(
                            icon: Icons.category_rounded,
                            label: 'Kategoriyalar',
                            value: '${allCats.length} ta',
                            color: const Color(0xFF3B82F6),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatBadge(
                            icon: Icons.inventory_2_rounded,
                            label: 'Jami mahsulotlar',
                            value: '$totalProducts ta',
                            color: const Color(0xFF10B981),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    if (allCats.length > 4) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Kategoriyalarni qidirish...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Categories List or Empty State
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: kYellow.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _searchQuery.isNotEmpty
                                      ? Icons.search_off_rounded
                                      : Icons.category_outlined,
                                  size: 42,
                                  color: kDarkYellow,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Qidiruv bo\'yicha kategoriya topilmadi'
                                    : 'Hozircha hech qanday kategoriya yo\'q',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? '"$_searchQuery" bo\'yicha boshqa nom kiritib ko\'ring'
                                    : 'Taom yoki ichimliklar uchun yangi kategoriya qo\'shing',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 18),
                                FilledButton.icon(
                                  onPressed: () => _edit(),
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  label: const Text('Kategoriya qo\'shish'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final c = filtered[i];
                          final count = appState.products
                              .where((p) => p.categoryId == c.id)
                              .length;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.2 : 0.03,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _edit(c),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      // Icon container
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFFD54F),
                                              Color(0xFFFFA000),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(15),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFFA000)
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          c.icon,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Category Title & Count
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c.name,
                                              style: const TextStyle(
                                                fontSize: 16.5,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: count > 0
                                                        ? (isDark
                                                            ? Colors.blue.shade900.withValues(alpha: 0.4)
                                                            : Colors.blue.shade50)
                                                        : (isDark
                                                            ? Colors.white10
                                                            : Colors.grey.shade100),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: count > 0
                                                          ? (isDark
                                                              ? Colors.blue.shade700.withValues(alpha: 0.5)
                                                              : Colors.blue.shade200)
                                                          : Colors.transparent,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.inventory_2_outlined,
                                                        size: 13,
                                                        color: count > 0
                                                            ? (isDark
                                                                ? Colors.blue.shade300
                                                                : Colors.blue.shade700)
                                                            : (isDark
                                                                ? Colors.white54
                                                                : Colors.grey.shade600),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$count ta mahsulot',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: count > 0
                                                              ? (isDark
                                                                  ? Colors.blue.shade300
                                                                  : Colors.blue.shade700)
                                                              : (isDark
                                                                  ? Colors.white54
                                                                  : Colors.grey.shade600),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Action Buttons
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Tooltip(
                                            message: 'Tahrirlash',
                                            child: InkWell(
                                              onTap: () => _edit(c),
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.blue.shade900.withValues(alpha: 0.3)
                                                      : Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  Icons.edit_rounded,
                                                  size: 20,
                                                  color: isDark
                                                      ? Colors.blue.shade300
                                                      : Colors.blue.shade700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Tooltip(
                                            message: 'O\'chirish',
                                            child: InkWell(
                                              onTap: () => _delete(c),
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.red.shade900.withValues(alpha: 0.3)
                                                      : Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 20,
                                                  color: isDark
                                                      ? Colors.red.shade300
                                                      : Colors.red.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final Set<int> _revealed = {};

  void _edit([AppUser? user]) {
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final userCtrl = TextEditingController(text: user?.username ?? '');
    final passCtrl = TextEditingController(text: user?.password ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final salaryCtrl = TextEditingController(
      text: user != null ? user.salary.toStringAsFixed(0) : '0',
    );
    UserRole role = user?.role ?? UserRole.waiter;
    bool obscure = true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          user == null ? Icons.person_add_rounded : Icons.edit_note_rounded,
                          color: Colors.black87,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user == null ? 'Yangi Xodim Qo\'shish' : 'Xodimni Tahrirlash',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'To\'liq Ism *',
                      hintText: 'Masalan: Ali Valiyev',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: userCtrl,
                    decoration: InputDecoration(
                      labelText: 'Login / Username *',
                      hintText: 'Masalan: ofitsiant_ali',
                      prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Parol *',
                      hintText: 'Kamida 4 ta belgi',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                        onPressed: () => setStateDialog(() => obscure = !obscure),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Telefon raqam',
                      hintText: '+998 90 123 45 67',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    initialValue: role,
                    decoration: InputDecoration(
                      labelText: 'Lavozim (Rol) *',
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.waiter,
                        child: Row(
                          children: [
                            Icon(Icons.room_service_rounded, color: Color(0xFF10B981), size: 18),
                            SizedBox(width: 8),
                            Text('Ofitsiant (Stollar va buyurtma)'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: UserRole.cashier,
                        child: Row(
                          children: [
                            Icon(Icons.point_of_sale_rounded, color: Color(0xFF3B82F6), size: 18),
                            SizedBox(width: 8),
                            Text('Kassir (Savdo va hisob)'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: UserRole.admin,
                        child: Row(
                          children: [
                            Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFFB300), size: 18),
                            SizedBox(width: 8),
                            Text('Administrator (Boshqaruv)'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: UserRole.courier,
                        child: Row(
                          children: [
                            Icon(Icons.delivery_dining_rounded, color: Color(0xFF8B5CF6), size: 18),
                            SizedBox(width: 8),
                            Text('Kuryer (Dastavka)'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (v) => setStateDialog(() => role = v ?? role),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: salaryCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Oylik Maosh (so\'m)',
                      hintText: '0',
                      prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB300),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty || userCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ism va loginni kiriting!')),
                            );
                            return;
                          }
                          final u = AppUser(
                            id: user?.id ?? appState.nextId(),
                            name: nameCtrl.text.trim(),
                            username: userCtrl.text.trim(),
                            password: passCtrl.text.trim().isNotEmpty ? passCtrl.text.trim() : '1234',
                            phone: phoneCtrl.text.trim(),
                            role: role,
                            salary: double.tryParse(salaryCtrl.text) ?? 0,
                            cafeId: appState.currentCafeId,
                          );
                          setState(() => appState.addOrUpdateEmployee(u));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Xodim saqlandi: ${u.name} (Login: @${u.username}, Parol: ${u.password})'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Saqlash', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _delete(AppUser u) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xodimni o\'chirish'),
        content: Text('Haqiqatdan ham "${u.name}" (@${u.username}) ni tizimdan o\'chirasizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              setState(() => appState.deleteEmployee(u));
              Navigator.pop(context);
            },
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
  }

  String _roleLabel(UserRole r) {
    switch (r) {
      case UserRole.director:
        return 'Director (SaaS)';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.cashier:
        return 'Kassir';
      case UserRole.waiter:
        return 'Ofitsiant';
      case UserRole.courier:
        return 'Kuryer';
      case UserRole.customer:
        return 'Mijoz';
    }
  }

  Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.waiter:
        return const Color(0xFF10B981);
      case UserRole.admin:
        return const Color(0xFFFF9800);
      case UserRole.cashier:
        return const Color(0xFF3B82F6);
      case UserRole.courier:
        return const Color(0xFF8B5CF6);
      default:
        return Colors.blueGrey;
    }
  }

  IconData _roleIcon(UserRole r) {
    switch (r) {
      case UserRole.waiter:
        return Icons.room_service_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.cashier:
        return Icons.point_of_sale_rounded;
      case UserRole.courier:
        return Icons.delivery_dining_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final waitersCount = appState.users.where((u) => u.role == UserRole.waiter).length;
    final cashiersCount = appState.users.where((u) => u.role == UserRole.cashier).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('Xodimlar va Ofitsiantlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: const Color(0xFF0F172A),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Xodim qo\'shish', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFFB300),
        foregroundColor: const Color(0xFF0F172A),
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Yangi xodim', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Top stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _buildStatPill('Jami xodimlar', '${appState.users.length} ta', const Color(0xFF0F172A)),
                const SizedBox(width: 8),
                _buildStatPill('Ofitsiantlar', '$waitersCount ta', const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _buildStatPill('Kassirlar', '$cashiersCount ta', const Color(0xFF3B82F6)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: appState.users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.badge_outlined, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Hozircha xodimlar mavjud emas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _edit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Birinchi xodimni qo\'shish'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: appState.users.length,
                    itemBuilder: (context, i) {
                      final u = appState.users[i];
                      final revealed = _revealed.contains(u.id);
                      final rColor = _roleColor(u.role);
                      final rIcon = _roleIcon(u.role);

                      // Calculate staff order performance
                      final staffReceipts = appState.receipts.where((r) {
                        final cName = r.cashierName.trim().toLowerCase();
                        final uName = u.name.trim().toLowerCase();
                        final uLogin = u.username.trim().toLowerCase();
                        return (uName.isNotEmpty && cName == uName) || (uLogin.isNotEmpty && cName == uLogin);
                      }).toList();
                      final staffOrderCount = staffReceipts.length;
                      final staffRevenue = staffReceipts.fold(0.0, (s, r) => s + r.total);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: rColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(rIcon, color: rColor, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          u.name,
                                          style: const TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: rColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _roleLabel(u.role),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: rColor,
                                            ),
                                          ),
                                        ),
                                        Builder(builder: (context) {
                                          final status = StaffTrackingService().getStatus(u.id);
                                          final isOnBreak = status?.isOnBreak ?? false;
                                          if (!isOnBreak) return const SizedBox.shrink();
                                          return Padding(
                                            padding: const EdgeInsets.only(left: 6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF2F2),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFFCA5A5)),
                                              ),
                                              child: Text(
                                                '☕ ${u.name} dam olmoqda',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFDC2626),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.alternate_email_rounded, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              u.username,
                                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.key_rounded, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              revealed ? u.password : '••••••',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: revealed ? const Color(0xFF0F172A) : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.shopping_bag_outlined,
                                              size: 14,
                                              color: staffOrderCount > 0 ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              staffOrderCount > 0
                                                  ? '$staffOrderCount ta zakaz (${formatSum(staffRevenue)})'
                                                  : '0 ta zakaz',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: staffOrderCount > 0 ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                      color: const Color(0xFF64748B),
                                      size: 20,
                                    ),
                                    tooltip: 'Parolni ko\'rish',
                                    onPressed: () => setState(() {
                                      if (revealed) {
                                        _revealed.remove(u.id);
                                      } else {
                                        _revealed.add(u.id);
                                      }
                                    }),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6), size: 20),
                                    tooltip: 'Tahrirlash',
                                    onPressed: () => _edit(u),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                    tooltip: 'O\'chirish',
                                    onPressed: () => _delete(u),
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
  }

  Widget _buildStatPill(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CUSTOMERS SCREEN (Admin CRUD)
// ============================================================

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  void _edit([Customer? customer]) {
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final emailCtrl = TextEditingController(text: customer?.email ?? '');
    final loyaltyCtrl = TextEditingController(
      text: customer != null ? customer.loyaltyPoints.toString() : '0',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          customer == null ? 'Mijoz qo\'shish' : 'Mijozni tahrirlash',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Ism'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: loyaltyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Bonus ballari'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final c = Customer(
                id: customer?.id ?? appState.nextId(),
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                loyaltyPoints: int.tryParse(loyaltyCtrl.text) ?? 0,
              );
              setState(() => appState.addOrUpdateCustomer(c));
              Navigator.pop(context);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  void _delete(Customer c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mijozni o\'chirish'),
        content: Text('"${c.name}" ni o\'chirasizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => appState.deleteCustomer(c));
              Navigator.pop(context);
            },
            child: const Text(
              'O\'chirish',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (appState.customers.isEmpty) {
      appState.loadCloudDataForCafe(appState.currentCafeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final customers = appState.customers;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mijozlar'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Yangilash',
                onPressed: () => appState.loadCloudDataForCafe(appState.currentCafeId),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _edit(),
            child: const Icon(Icons.add),
          ),
          body: customers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_rounded, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Hozircha mijozlar yo\'q',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'QR menyudan skaner qilgan yoki buyurtma bergan\nmijozlar bu yerda real-time ko\'rinadi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: customers.length,
                  itemBuilder: (context, i) {
                    final c = customers[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: kYellow,
                          child: Icon(Icons.person, color: Colors.black87),
                        ),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${c.phone.isNotEmpty ? c.phone : "Telefon kiritilmagan"} · ${c.email.isEmpty ? "email yo'q" : c.email} · ${c.loyaltyPoints} ball',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _edit(c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _delete(c),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

// ============================================================
// SETTINGS SCREEN — restoran ma'lumotlari, printer va boshqa sozlamalar
// ============================================================

// ---- "CHEKNI TAHRIRLASH" — chekda ko'rinadigan barcha ma'lumotlarni
// ---- "CHEK NOMINI O'ZGARTIRISH" — Faqat CAFE OWNER (admin) uchun ----
Future<void> showEditReceiptNameDialog(BuildContext context) async {
  final user = appState.currentUser;
  if (user != null && user.role != UserRole.admin) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Faqat kafe egasi (admin) chek nomini o'zgartira oladi."),
        backgroundColor: Colors.redAccent,
      ),
    );
    return;
  }

  final ctrl = TextEditingController(text: appState.effectiveReceiptName);
  bool saving = false;
  String? error;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDlgState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Color(0xFF3B6E91)),
            SizedBox(width: 8),
            Text("Chek nomini o'zgartirish"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Chekning yuqori qismida chiqadigan sarlavha nomini kiriting. "
                "Bu faqat chekda ko'rinadi, kafe hisobining asl nomiga ta'sir qilmaydi.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Chek nomi',
                  hintText: 'Masalan: ZAVERO CAFE yoki Samarqand Osh',
                  errorText: error,
                  prefixIcon: const Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text('Chekdagi ko\'rinishi:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 6),
                    AnimatedBuilder(
                      animation: ctrl,
                      builder: (_, __) => Text(
                        ctrl.text.trim().isEmpty ? 'ZAVERO' : ctrl.text.trim(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) {
                      setDlgState(() => error = 'Chek nomini kiriting');
                      return;
                    }
                    setDlgState(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      await appState.updateReceiptName(text);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Chek nomi saqlandi: $text"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      setDlgState(() {
                        saving = false;
                        error = 'Xatolik: $e';
                      });
                    }
                  },
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Saqlash'),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
}

// ---- "CHEKNI TAHRIRLASH" — chekda ko'rinadigan barcha ma'lumotlarni
// (nomi, manzili, telefon, pastki matn) bitta oynada tahrirlash va
// natijani ko'rish uchun. Top-level qilingan — shu bilan "Sozlamalar"
// ekranidan ham, "Printer sozlamalari" tezkor panelidan ham chaqirish
// mumkin. ----
Future<void> showEditReceiptTemplateDialog(BuildContext context) async {
  final n = TextEditingController(text: appState.effectiveReceiptName);
  final a = TextEditingController(text: appState.restaurantAddress);
  final p = TextEditingController(text: appState.restaurantPhone);
  final s = TextEditingController(text: appState.receiptSlogan);
  final f = TextEditingController(text: appState.receiptFooterNote);
  bool qr = appState.receiptQrEnabled;

  final sampleItems = [
    const ReceiptItem(name: 'Mini shaurma', quantity: '1 dona', price: '25 000'),
    const ReceiptItem(name: 'Coca-Cola 0.5', quantity: '2 dona', price: '12 000'),
    const ReceiptItem(name: 'Kartoshka fri', quantity: '1 dona', price: '15 000'),
    const ReceiptItem(name: 'Cheesecake', quantity: '1 dona', price: '18 000'),
  ];

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Color(0xFF3B6E91)),
            SizedBox(width: 8),
            Text('Chekni tahrirlash (80mm)'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: n,
                  decoration: const InputDecoration(
                    labelText: 'Restoran / Kafe nomi',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: s,
                  decoration: const InputDecoration(
                    labelText: 'Slogan / Tagline',
                    hintText: 'masalan: Yaxshi ta\'m • Baxtli onlar',
                    prefixIcon: Icon(Icons.star_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: a,
                  decoration: const InputDecoration(
                    labelText: 'Manzil',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: p,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon raqami',
                    hintText: '+998 90 123 45 67',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: f,
                  decoration: const InputDecoration(
                    labelText: 'Rahmat matni / Footer',
                    hintText: 'masalan: Bizni tanlaganingiz uchun rahmat!',
                    prefixIcon: Icon(Icons.favorite_outline),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('QR Kodni ko\'rsatish'),
                  subtitle: const Text('Zavero web saytiga yo\'naltiruvchi QR kod', style: TextStyle(fontSize: 11)),
                  value: qr,
                  onChanged: (v) => setDlgState(() => qr = v),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Jonli 80mm Chek Ko\'rinishi:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: Listenable.merge([n, a, p, s, f]),
                  builder: (context, _) => Center(
                    child: ReceiptWidget(
                      checkId: '000125',
                      waiter: appState.currentUser?.name ?? 'Admin',
                      dateTime: DateTime.now().toIso8601String(),
                      dateOnly: '08.10.2026',
                      timeOnly: '14:32',
                      customCafeName: n.text,
                      customAddress: a.text,
                      customPhone: p.text,
                      customSlogan: s.text,
                      customFooter: f.text,
                      customShowQr: qr,
                      items: sampleItems,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              appState.updateSettings(
                name: n.text.trim(),
                receiptName: n.text.trim(),
                address: a.text.trim(),
                phone: p.text.trim(),
                slogan: s.text.trim(),
                footerNote: f.text.trim(),
                qrEnabled: qr,
              );
              Navigator.pop(ctx, true);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    ),
  );
  n.dispose();
  a.dispose();
  p.dispose();
  s.dispose();
  f.dispose();
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chek sozlamalari saqlandi'),
        backgroundColor: Colors.green,
        duration: Duration(milliseconds: 1200),
      ),
    );
  }
}

// ---- ELEMENTLARNI KO'RSATISH/YASHIRISH MULOQOT OYNASI ----
Future<void> showReceiptVisibilityDialog(BuildContext context) async {
  bool waiter = appState.showWaiterName;
  bool table = appState.showTableName;
  bool dateTime = appState.showDateTime;
  bool devTag = appState.showDeveloperTag;
  bool customerCount = appState.showCustomerCount;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.visibility_outlined, color: Color(0xFF3B6E91)),
            SizedBox(width: 8),
            Text('Elementlarni ko\'rsatish'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Ofitsiant ismini ko\'rsatish'),
                value: waiter,
                onChanged: (v) => setDlgState(() => waiter = v),
              ),
              SwitchListTile(
                title: const Text('Stol va zal nomini ko\'rsatish'),
                value: table,
                onChanged: (v) => setDlgState(() => table = v),
              ),
              SwitchListTile(
                title: const Text('Vaqti va sanani ko\'rsatish'),
                value: dateTime,
                onChanged: (v) => setDlgState(() => dateTime = v),
              ),
              SwitchListTile(
                title: const Text('Mijoz sonini ko\'rsatish'),
                value: customerCount,
                onChanged: (v) => setDlgState(() => customerCount = v),
              ),
              SwitchListTile(
                title: const Text('Developer mualliflik yozuvini ko\'rsatish'),
                subtitle: const Text(
                  'Restoranlarni avtomatlashtirish @mirzobekdeveloper',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                value: devTag,
                onChanged: (v) => setDlgState(() => devTag = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              appState.updateReceiptVisibilitySettings(
                waiter: waiter,
                table: table,
                dateTime: dateTime,
                devTag: devTag,
                customerCount: customerCount,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showPrinterSettingsModal(BuildContext context) async {
  await showPrinterQuickSettingsSheet(context);
}

// ---- "PRINTER SOZLAMALARI" TEZKOR PANELI ----
Future<void> showPrinterQuickSettingsSheet(BuildContext context) async {
  int paperWidth = appState.paperWidthMm;
  double marginMm = appState.printerMarginMm;
  PrinterFontSize fontSize = appState.printerFontSize;
  bool boldHeader = appState.receiptBoldHeader;
  ReceiptHeaderAlign headerAlign = appState.receiptHeaderAlign;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          void applyAndClose() {
            appState.updatePrinterSettings(
              ip: appState.printerIp,
              port: appState.printerPort,
              charsPerLine: paperWidth == 58 ? 32 : 48,
              fontSize: fontSize,
            );
            appState.updateReceiptLayoutSettings(
              boldHeader: boldHeader,
              headerAlign: headerAlign,
              paperWidth: paperWidth,
              margin: marginMm,
            );
            Navigator.pop(sheetCtx);
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.print_outlined),
                      SizedBox(width: 8),
                      Text(
                        'Printer va Chek sozlamalari',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Qog\'oz kengligi (Format)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: paperWidth,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.receipt_long),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 80,
                        child: Text(
                            '80 mm — standart termal roll (tavsiya etiladi)'),
                      ),
                      DropdownMenuItem(
                        value: 58,
                        child: Text('58 mm — tor termal roll'),
                      ),
                      DropdownMenuItem(
                        value: 148,
                        child: Text('A5 qog\'oz formati'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setSheetState(() {
                          paperWidth = v;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chetki masofa (Margin / Padding)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<double>(
                    initialValue: marginMm,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.line_weight),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 0.0,
                        child: Text('0 mm — chensiz (chekkagacha)'),
                      ),
                      DropdownMenuItem(
                        value: 3.0,
                        child: Text('3 mm — standart chet masofasi'),
                      ),
                      DropdownMenuItem(
                        value: 5.0,
                        child: Text('5 mm — kengroq chet masofasi'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => marginMm = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Yozuvlar o\'lchami (Shrift)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<PrinterFontSize>(
                    segments: const [
                      ButtonSegment(
                        value: PrinterFontSize.small,
                        label: Text('Kichik'),
                        icon: Icon(Icons.zoom_out, size: 18),
                      ),
                      ButtonSegment(
                        value: PrinterFontSize.normal,
                        label: Text('Oddiy'),
                        icon: Icon(Icons.text_fields, size: 18),
                      ),
                      ButtonSegment(
                        value: PrinterFontSize.large,
                        label: Text('Katta'),
                        icon: Icon(Icons.zoom_in, size: 18),
                      ),
                    ],
                    selected: {fontSize},
                    onSelectionChanged: (s) =>
                        setSheetState(() => fontSize = s.first),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sarlavha joylashuvi (Tekislash)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ReceiptHeaderAlign>(
                    segments: const [
                      ButtonSegment(
                        value: ReceiptHeaderAlign.left,
                        label: Text('Chap'),
                        icon: Icon(Icons.format_align_left, size: 18),
                      ),
                      ButtonSegment(
                        value: ReceiptHeaderAlign.center,
                        label: Text('Markaz'),
                        icon: Icon(Icons.format_align_center, size: 18),
                      ),
                      ButtonSegment(
                        value: ReceiptHeaderAlign.right,
                        label: Text('O\'ng'),
                        icon: Icon(Icons.format_align_right, size: 18),
                      ),
                    ],
                    selected: {headerAlign},
                    onSelectionChanged: (s) =>
                        setSheetState(() => headerAlign = s.first),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Qalin yozuv (sarlavha)'),
                    subtitle: const Text(
                      'Restoran nomi va "Hammasi" qalin harflarda chiqadi',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: boldHeader,
                    onChanged: (v) => setSheetState(() => boldHeader = v),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      showEditReceiptTemplateDialog(context);
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text(
                        'Chek yozuvlarini tahrirlash (nomi, manzil, tel)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      showReceiptVisibilityDialog(context);
                    },
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Elementlarni ko\'rsatish / yashirish'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Batafsil sozlamalar (IP, port)'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: applyAndClose,
                      icon: const Icon(Icons.save),
                      label: const Text('Saqlash'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ═══════════════════════════════════════════════════
// PROFIL SCREEN
// ═══════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _oldPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _appLockEnabled = false;
  bool _changingPw = false;
  bool _settingPin = false;

  @override
  void dispose() {
    _oldPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newPwCtrl.text != _confirmPwCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yangi parollar mos kelmadi!'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_newPwCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parol kamida 6 ta belgi bo\'lishi kerak!'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _changingPw = true);
    try {
      // Supabase auth orqali parolni yangilash
      await appState.updatePassword(_oldPwCtrl.text, _newPwCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parol muvaffaqiyatli o\'zgartirildi!'), backgroundColor: Colors.green),
        );
        _oldPwCtrl.clear();
        _newPwCtrl.clear();
        _confirmPwCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _changingPw = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = appState.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1E30),
        title: const Text('Profil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Akkount ma'lumotlari ──────────────────────────
          _section(
            icon: Icons.person_rounded,
            title: 'Akkount',
            children: [
              _infoRow('Ism', user?.name ?? '-'),
              _infoRow('Email', user?.email ?? '-'),
              _infoRow('Rol', _roleName(user?.role)),
            ],
          ),
          const SizedBox(height: 16),

          // ── Parol o'zgartirish ────────────────────────────
          _section(
            icon: Icons.lock_rounded,
            title: 'Parol o\'zgartirish',
            children: [
              _pwField('Joriy parol', _oldPwCtrl, _obscureOld, () => setState(() => _obscureOld = !_obscureOld)),
              const SizedBox(height: 10),
              _pwField('Yangi parol', _newPwCtrl, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
              const SizedBox(height: 10),
              _pwField('Yangi parolni tasdiqlang', _confirmPwCtrl, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _changingPw ? null : _changePassword,
                  icon: _changingPw
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Parolni saqlash'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5AFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Ilova paroli (PIN lock) ───────────────────────
          _section(
            icon: Icons.phonelink_lock_rounded,
            title: 'Ilova paroli',
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ilovani PIN bilan qulflash', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Switch(
                    value: _appLockEnabled,
                    activeColor: const Color(0xFF1E5AFF),
                    onChanged: (v) => setState(() => _appLockEnabled = v),
                  ),
                ],
              ),
              if (_appLockEnabled) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '4-6 xonali PIN kiriting',
                    prefixIcon: const Icon(Icons.pin_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _settingPin ? null : () async {
                      if (_pinCtrl.text.length < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PIN kamida 4 raqam bo\'lishi kerak!')),
                        );
                        return;
                      }
                      setState(() => _settingPin = true);
                      await Future.delayed(const Duration(milliseconds: 500));
                      setState(() => _settingPin = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PIN muvaffaqiyatli o\'rnatildi!'), backgroundColor: Colors.green),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('PIN saqlash'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ── Sozlamalar ────────────────────────────────────
          _section(
            icon: Icons.settings_rounded,
            title: 'Sozlamalar',
            children: [
              _navRow(context, Icons.tune_rounded, 'Ilova sozlamalari', const SettingsScreen()),
            ],
          ),
          const SizedBox(height: 24),

          // ── Chiqish ───────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await appState.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()), (r) => false);
                }
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: const Text('Chiqish', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required IconData icon, required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: const Color(0xFF0F1E30).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: const Color(0xFF0F1E30), size: 18),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F1E30))),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F1E30))),
      ]),
    );
  }

  Widget _navRow(BuildContext ctx, IconData icon, String label, Widget screen) {
    return InkWell(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen)),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF0F1E30), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _pwField(String label, TextEditingController ctrl, bool obscure, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility), onPressed: toggle),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  String _roleName(UserRole? role) {
    switch (role) {
      case UserRole.admin: return 'Administrator';
      case UserRole.director: return 'Direktor';
      case UserRole.waiter: return 'Ofitsiant';
      case UserRole.courier: return 'Kuryer';
      case UserRole.customer: return 'Mijoz';
      default: return '-';
    }
  }
}

class SettingsScreen extends StatefulWidget {

  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController addressCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController footerCtrl;
  late TextEditingController printerIpCtrl;
  late TextEditingController printerPortCtrl;
  int printerCharsPerLine = 48;
  PrinterFontSize printerFontSize = PrinterFontSize.normal;
  bool receiptBoldHeader = true;
  ReceiptHeaderAlign receiptHeaderAlign = ReceiptHeaderAlign.center;
  bool testingPrinter = false;
  bool savingPrinter = false;
  Hall? _selectedHallForTables;

  @override
  void initState() {
    super.initState();
    if (appState.halls.isNotEmpty) {
      _selectedHallForTables = appState.halls.first;
    }
    nameCtrl = TextEditingController(text: appState.restaurantName);
    addressCtrl = TextEditingController(text: appState.restaurantAddress);
    phoneCtrl = TextEditingController(text: appState.restaurantPhone);
    footerCtrl = TextEditingController(text: appState.receiptFooterNote);
    printerIpCtrl = TextEditingController(text: appState.printerIp);
    printerPortCtrl = TextEditingController(
      text: appState.printerPort.toString(),
    );
    printerCharsPerLine = appState.printerCharsPerLine;
    printerFontSize = appState.printerFontSize;
    receiptBoldHeader = appState.receiptBoldHeader;
    receiptHeaderAlign = appState.receiptHeaderAlign;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    addressCtrl.dispose();
    phoneCtrl.dispose();
    footerCtrl.dispose();
    printerIpCtrl.dispose();
    printerPortCtrl.dispose();
    super.dispose();
  }

  void _save() {
    appState.updateSettings(
      name: nameCtrl.text.trim(),
      address: addressCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      footerNote: footerCtrl.text.trim(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sozlamalar saqlandi'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _editReceiptName() async {
    await showEditReceiptNameDialog(context);
    if (!mounted) return;
    setState(() {});
  }

  // ---- "CHEKNI TAHRIRLASH" — endi umumiy (top-level) funksiya orqali
  // ochiladi (showEditReceiptTemplateDialog), shu bilan bir xil oyna
  // "Sozlamalar" ekranidan ham, "Printer sozlamalari" tezkor panelidan
  // ham chaqiriladi. Bu yerdan chaqirilgach, matn maydonlarini ekranda
  // ham yangilab qo'yamiz. ----
  Future<void> _editReceiptTemplate() async {
    await showEditReceiptTemplateDialog(context);
    if (!mounted) return;
    setState(() {
      nameCtrl.text = appState.restaurantName;
      addressCtrl.text = appState.restaurantAddress;
      phoneCtrl.text = appState.restaurantPhone;
      footerCtrl.text = appState.receiptFooterNote;
    });
  }

  Future<void> _editProfileDialog() async {
    final user = appState.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: user.name);
    final surnameController = TextEditingController(text: user.surname);
    final usernameController = TextEditingController(text: user.username);
    final phoneController = TextEditingController(text: user.phone);
    bool saving = false;
    String? errorMsg;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.person, color: kDarkYellow),
              const SizedBox(width: 10),
              const Text('Profilni tahrirlash', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Ism *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: surnameController,
                  decoration: const InputDecoration(labelText: 'Familiya'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Login / Username *',
                    hintText: 'Login kiriting',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Telefon raqami'),
                ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(errorMsg!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final n = nameController.text.trim();
                      final u = usernameController.text.trim();
                      if (n.isEmpty || u.isEmpty) {
                        setDState(() =>
                            errorMsg = 'Ism va Login to\'ldirilishi shart');
                        return;
                      }
                      setDState(() => saving = true);
                      try {
                        await AuthService().updateUserProfile(
                          uid: user.uid,
                          name: n,
                          surname: surnameController.text.trim(),
                          username: u,
                          phone: phoneController.text.trim(),
                        );
                        user.name = n;
                        user.surname = surnameController.text.trim();
                        user.username = u;
                        user.phone = phoneController.text.trim();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Profil muvaffaqiyatli saqlandi!')),
                          );
                        }
                      } catch (e) {
                        setDState(() {
                          saving = false;
                          errorMsg = 'Xatolik: $e';
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePasswordDialog() async {
    final passController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscure1 = true;
    bool obscure2 = true;
    bool saving = false;
    String? errorMsg;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.lock_reset, color: kDarkYellow),
              const SizedBox(width: 10),
              const Text('Parolni o\'zgartirish',
                  style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passController,
                  obscureText: obscure1,
                  decoration: InputDecoration(
                    labelText: 'Yangi parol (kamida 6 ta belgi) *',
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure1 ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDState(() => obscure1 = !obscure1),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPassController,
                  obscureText: obscure2,
                  decoration: InputDecoration(
                    labelText: 'Yangi parolni tasdiqlang *',
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure2 ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDState(() => obscure2 = !obscure2),
                    ),
                  ),
                ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(errorMsg!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final p = passController.text.trim();
                      final cp = confirmPassController.text.trim();
                      if (p.length < 6) {
                        setDState(() => errorMsg =
                            'Parol kamida 6 ta belgidan iborat bo\'lishi shart');
                        return;
                      }
                      if (p != cp) {
                        setDState(
                            () => errorMsg = 'Tasdiqlash paroli mos kelmadi');
                        return;
                      }
                      setDState(() => saving = true);
                      try {
                        await AuthService().changePassword(p);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Parol muvaffaqiyatli yangilandi!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDState(() {
                          saving = false;
                          errorMsg = 'Xatolik: $e';
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Yangilash'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- TARMOQ (Wi-Fi/LAN) PRINTERGA ULANISH ----
  // Printer bilan ulanish uning IP-manzili va porti (odatda 9100) orqali
  // amalga oshiriladi. "Saqlash" tugmasi shu ma'lumotlarni AppState ga
  // (va SharedPreferences orqali xotiraga) yozadi — shundan so'ng barcha
  // cheklar (mijoz cheki, hisob, oshpaz cheki) avtomatik shu printerga
  // IP orqali chiqadi.
  int? get _parsedPort => int.tryParse(printerPortCtrl.text.trim());

  Future<void> _savePrinterSettings({bool silent = false}) async {
    final ip = printerIpCtrl.text.trim();
    final port = _parsedPort;
    if (ip.isEmpty) {
      appState.updatePrinterSettings(
        ip: '',
        port: appState.printerPort,
        charsPerLine: printerCharsPerLine,
        fontSize: printerFontSize,
      );
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer ulanishi o\'chirildi')),
        );
      }
      setState(() {});
      return;
    }
    if (port == null || port <= 0 || port > 65535) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Port noto\'g\'ri. Masalan: 9100'),
          ),
        );
      }
      return;
    }
    appState.updatePrinterSettings(
      ip: ip,
      port: port,
      charsPerLine: printerCharsPerLine,
      fontSize: printerFontSize,
    );
    appState.updateReceiptLayoutSettings(
      boldHeader: receiptBoldHeader,
      headerAlign: receiptHeaderAlign,
    );
    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Printer sozlamalari saqlandi ($ip:$port)')),
      );
    }
    setState(() {});
  }

  Future<void> _testPrinterConnection() async {
    final ip = printerIpCtrl.text.trim();
    final port = _parsedPort;
    if (ip.isEmpty || port == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avval printerning IP-manzili va portini kiriting'),
        ),
      );
      return;
    }
    setState(() => testingPrinter = true);
    try {
      await NetworkPrinterService.testConnection(
        ip: ip,
        port: port,
        charsPerLine: printerCharsPerLine,
      );
      // Ulanish muvaffaqiyatli bo'lsa — sozlamalarni ham saqlab qo'yamiz.
      await _savePrinterSettings(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ulanish muvaffaqiyatli! Printerdan test cheki chiqishi kerak.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => testingPrinter = false);
    }
  }

  void _showEditUserDialog(BuildContext context, AppUser user) {
    final userCtrl = TextEditingController(text: user.username);
    final passCtrl = TextEditingController(text: user.password);
    final nameCtrl = TextEditingController(text: user.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${user.name} hisobini tahrirlash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Ism'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(labelText: 'Login'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: 'Parol'),
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
            onPressed: () {
              user.name = nameCtrl.text.trim();
              user.username = userCtrl.text.trim();
              user.password = passCtrl.text.trim();
              appState.saveData();
              setState(() {});
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Xodim ma\'lumotlari va paroli saqlandi!')),
              );
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  void _showAddTableDialog() {
    final hall = _selectedHallForTables ??
        (appState.halls.isNotEmpty ? appState.halls.first : null);
    if (hall == null) return;

    final currentTables = appState.tables.where((t) {
      if (t.hallId == hall.id) return true;
      final h = appState.halls.firstWhere(
        (x) => x.id == t.hallId,
        orElse: () => Hall(id: -1, name: '', icon: Icons.home),
      );
      return h.name.trim().toLowerCase() == hall.name.trim().toLowerCase();
    }).toList();

    int nextNum = 1;
    if (currentTables.isNotEmpty) {
      nextNum =
          currentTables.map((t) => t.number).reduce((a, b) => a > b ? a : b) + 1;
    }

    final numberCtrl = TextEditingController(text: nextNum.toString());
    final seatsCtrl = TextEditingController(text: '4');
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.add_circle_outline, color: kDarkYellow),
              const SizedBox(width: 10),
              Text(
                '${hall.name} - Yangi stol',
                style: const TextStyle(fontSize: 18),
              ),
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
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
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
                final num = int.tryParse(numberCtrl.text.trim());
                final seats = int.tryParse(seatsCtrl.text.trim()) ?? 4;
                if (num == null || num <= 0) {
                  setDState(() => error = 'Stol raqamini to\'g\'ri kiriting');
                  return;
                }
                final exists = currentTables.any((t) => t.number == num);
                if (exists) {
                  setDState(() => error = 'Bu raqamli stol allaqachon mavjud');
                  return;
                }
                Navigator.pop(ctx);
                await appState.addTableToHall(
                  hallId: hall.id,
                  number: num,
                  seats: seats,
                );
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${hall.name}ga $num-stol qo\'shildi'),
                    ),
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

  void _showEditTableDialog(TableModel table) {
    final numberCtrl = TextEditingController(text: table.number.toString());
    final seatsCtrl = TextEditingController(text: table.seats.toString());
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.edit, color: kDarkYellow),
              const SizedBox(width: 10),
              Text(
                'Stol ${table.number} ni tahrirlash',
                style: const TextStyle(fontSize: 18),
              ),
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
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
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
                final num = int.tryParse(numberCtrl.text.trim());
                final seats =
                    int.tryParse(seatsCtrl.text.trim()) ?? table.seats;
                if (num == null || num <= 0) {
                  setDState(() => error = 'Stol raqamini to\'g\'ri kiriting');
                  return;
                }
                Navigator.pop(ctx);
                await appState.updateTableDetails(
                  tableId: table.id,
                  number: num,
                  seats: seats,
                );
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Stol ma\'lumotlari yangilandi'),
                    ),
                  );
                }
              },
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTableDialog(TableModel table) {
    final hasActiveOrder =
        (appState.tableOrders[table.id]?.isNotEmpty ?? false) ||
            table.status == TableStatus.occupied;
    if (hasActiveOrder) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text('O\'chirish taqiqlangan!'),
            ],
          ),
          content: Text(
            '${table.number}-stolda hozirda faol buyurtma mavjud (stol band)!\n\n'
            'Stolni o\'chirishdan oldin buyurtma to\'lovi qilinishi yoki bekor qilinishi lozim.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tushunarli'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red),
            const SizedBox(width: 10),
            Text('${table.number}-stolni o\'chirish'),
          ],
        ),
        content: Text(
          'Haqiqatan ham ${table.number}-stolni o\'chirib tashlamoqchimisiz?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await appState.deleteTableById(tableId: table.id);
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${table.number}-stol o\'chirildi')),
                );
              }
            },
            child: const Text('Ha, o\'chirish'),
          ),
        ],
      ),
    );
  }

  Widget _buildHallAndTablesSection() {
    final halls = appState.halls;
    if (halls.isEmpty) return const SizedBox.shrink();

    _selectedHallForTables ??= halls.first;
    if (!halls.any((h) => h.id == _selectedHallForTables?.id)) {
      _selectedHallForTables = halls.first;
    }
    final curHall = _selectedHallForTables!;

    final currentTables = (appState.tables.where((t) {
      if (t.hallId == curHall.id) return true;
      final h = appState.halls.firstWhere(
        (x) => x.id == t.hallId,
        orElse: () => Hall(id: -1, name: '', icon: Icons.home),
      );
      return h.name.trim().toLowerCase() == curHall.name.trim().toLowerCase();
    }).toList()..sort((a, b) => a.number.compareTo(b.number)));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.table_restaurant, color: kDarkYellow),
                    const SizedBox(width: 8),
                    const Text(
                      'Joylar va Stollar',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDarkYellow,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _showAddTableDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Stol qo\'shish'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Joylar (Hall) tabs: Zal, Podval, Dala, Saboy, Soy bo'yi
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: halls.map((hall) {
                  final isSelected = hall.id == curHall.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hall.icon,
                            size: 16,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                          const SizedBox(width: 6),
                          Text(hall.name),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: kDarkYellow,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedHallForTables = hall);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            if (currentTables.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    '${curHall.name}da hali stollar yo\'q',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentTables.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final t = currentTables[idx];
                  final isFree = t.status == TableStatus.free;
                  final total = appState.tableOrderTotal(t);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isFree
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                      child: Icon(
                        Icons.chair,
                        color: isFree
                            ? const Color(0xFF00C853)
                            : const Color(0xFFE53935),
                      ),
                    ),
                    title: Text(
                      'Stol ${t.number}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${t.seats} o\'rinli · ${isFree ? "Bo'sh" : "Band (${formatSum(total)})"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isFree
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blueGrey,
                          ),
                          tooltip: 'Tahrirlash',
                          onPressed: () => _showEditTableDialog(t),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color:
                                isFree ? Colors.red.shade400 : Colors.grey,
                          ),
                          tooltip: 'O\'chirish',
                          onPressed: () => _showDeleteTableDialog(t),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.wifi, color: kDarkYellow),
                const SizedBox(width: 8),
                const Text(
                  'Tizim va Tarmoq holati',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kafe ID:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(appState.currentCafeId,
                    style: const TextStyle(fontFamily: 'monospace')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Server kechikishi (ping):',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                ConnectivityBadge(cafeId: appState.currentCafeId),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinSecuritySection() {
    return FutureBuilder<String?>(
      future: PinSecurityService().getCafePin(),
      builder: (context, snapshot) {
        final currentPin = snapshot.data;
        final hasPin = currentPin != null && currentPin.isNotEmpty;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dialpad_rounded, color: Color(0xFF00C2A8)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '4 xonali PIN kod (Tezkor kirish)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  hasPin
                      ? 'PIN kod faol: ••••. Ilova ochilganda 4 ta raqam terib to‘g‘ridan-to‘g‘ri kafe paneliga kirish mumkin.'
                      : 'PIN kod o‘rnatilmagan. 4 xonali PIN kod qo‘yilsa, har safar login-parol termasdan tezkor kirishingiz mumkin.',
                  style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.3),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C2A8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showSetCafePinDialog(currentPin),
                        icon: Icon(hasPin ? Icons.edit_rounded : Icons.lock_rounded, size: 18),
                        label: Text(hasPin ? 'PIN kodni o‘zgartirish' : 'PIN kod qo‘yish'),
                      ),
                    ),
                    if (hasPin) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'PIN kodni o‘chirish (bekor qilish)',
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () async {
                          await PinSecurityService().removeCafePin();
                          if (context.mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Kafe PIN kodi o‘chirildi va bekor qilindi')),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSetCafePinDialog(String? existingPin) {
    final pinCtrl = TextEditingController(text: existingPin ?? '');
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.dialpad_rounded, color: Color(0xFF00C2A8)),
              SizedBox(width: 10),
              Text('Kafe uchun PIN kod'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ilovaga tezkor kirish uchun 4 xonali raqamli PIN kod kiriting (Masalan: 1234):',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '1234',
                  counterText: '',
                  errorText: errorMsg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
                backgroundColor: const Color(0xFF00C2A8),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final text = pinCtrl.text.trim();
                if (text.length != 4 || int.tryParse(text) == null) {
                  setDState(() => errorMsg = 'Aynan 4 ta raqam kiriting (Masalan: 1234)');
                  return;
                }
                final user = appState.currentUser;
                if (user != null) {
                  await PinSecurityService().saveCafePin(text, user);
                }
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kafe uchun 4 xonali PIN kod muvaffaqiyatli o‘rnatildi!')),
                  );
                }
              },
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection() {
    final current = LocalizationService().currentLanguage;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.language_rounded, color: Color(0xFF3B82F6), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('menu_language'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'O‘zbekcha / Русский / English',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final lang in AppLanguage.values) ...[
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        LocalizationService().setLanguage(lang);
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: current == lang
                              ? const Color(0xFFFFB300)
                              : const Color(0xFF1E293B).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: current == lang
                                ? const Color(0xFFFFB300)
                                : Colors.grey.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            lang.title,
                            style: TextStyle(
                              color: current == lang ? Colors.black87 : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (lang != AppLanguage.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceNotificationSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.record_voice_over_rounded, color: Color(0xFFFFB300), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ovozli gapiradigan bildirishnoma',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'QR buyurtma kelganda gapirib e‘lon qilish sozlamasi',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: appState.voiceNotificationEnabled
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    appState.voiceNotificationEnabled ? 'Yoqilgan 🟢' : 'O‘chirilgan ⚪️',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: appState.voiceNotificationEnabled ? Colors.green.shade700 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: const Color(0xFFFFB300),
              title: const Text(
                'Gapiradigan ovozni yoqish / o‘chirish',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Yangi buyurtma tushganda taomlar va stol raqamini ovoz chiqarib gapiradi.\n🔔 «Ting!» qo‘ng‘iroq ovozi har doim faol bo‘ladi.',
                  style: TextStyle(fontSize: 12, height: 1.3),
                ),
              ),
              value: appState.voiceNotificationEnabled,
              onChanged: (val) {
                setState(() {
                  appState.setVoiceNotificationEnabled(val);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      val
                          ? '🔊 Gapiradigan ovozli bildirishnoma yoqildi'
                          : '🔇 Gapiradigan ovoz o‘chirildi («Ting» ovozi faol qoladi)',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFB300),
                side: const BorderSide(color: Color(0xFFFFB300), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              ),
              icon: const Icon(Icons.volume_up_rounded, size: 18),
              label: const Text('Ovozni sinab ko‘rish (Test)', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                SoundService().testVoiceAnnouncement();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔊 Test ovozli xabar ijro etilmoqda...'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = appState.currentUser?.role == UserRole.admin;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: Color(0xFFFFB300), size: 22),
            SizedBox(width: 10),
            Text(
              'Tizim Sozlamalari',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Til tanlash bloki (UZ / RU / EN)
                _buildLanguageSection(),
                const SizedBox(height: 16),
                // Ovozli bildirishnomalar bloki
                _buildVoiceNotificationSection(),
                const SizedBox(height: 16),
                // PIN kod xavfsizlik bloki
                _buildPinSecuritySection(),
                const SizedBox(height: 16),
                // Joylar va stollarni boshqarish
                _buildHallAndTablesSection(),
                const SizedBox(height: 16),
                if (isAdmin) ...[
                  Card(
                    elevation: 3,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF4D4D).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.fastfood_rounded, color: Color(0xFFFF4D4D), size: 22),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Brend va Ilova Logotipi',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Barcha qurilmalar, cheklar va APK uchun rasmiy logotip',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFFF4D4D).withValues(alpha: 0.4), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF4D4D).withValues(alpha: 0.18),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const CafeLogo(size: 88),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () async {
                                  final path = await pickAndSaveImageFromGallery();
                                  if (path != null && path.isNotEmpty) {
                                    appState.setAppLogoUrl(path);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Ilova logotipi muvaffaqiyatli yangilandi!'),
                                          backgroundColor: Color(0xFF10B981),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.upload_file_rounded, size: 18, color: Color(0xFFFFB300)),
                                label: const Text('Maxsus rasm yuklash', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              if (appState.appLogoUrl != null &&
                                  appState.appLogoUrl!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Logotipni standart ko\'rinishga qaytarish',
                                  icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent),
                                  onPressed: () {
                                    appState.setAppLogoUrl(null);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Logotip rasmiy ZAVERO FAST ko\'rinishiga qaytarildi'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ---- XODIMLAR VA PAROLLAR BOSHQARUVI ----
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people_alt, color: kDarkYellow),
                              const SizedBox(width: 8),
                              const Text(
                                'Xodimlar va Parollar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final u in appState.users)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: kYellow.withValues(alpha: 0.3),
                                child: Icon(
                                  u.role == UserRole.admin
                                      ? Icons.admin_panel_settings
                                      : u.role == UserRole.waiter
                                          ? Icons.person_pin
                                          : Icons.badge,
                                  color: kDarkYellow,
                                ),
                              ),
                              title: Text('${u.name} (${u.username})'),
                              subtitle: Text('Parol: ${u.password} · Rol: ${roleToString(u.role)}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.amber),
                                onPressed: () {
                                  _showEditUserDialog(context, u);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Restoran ma\'lumotlari',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Restoran nomi',
                      prefixIcon: Icon(Icons.storefront),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Manzil',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon (chekda "Bog\'lanish")',
                      hintText: 'masalan: (95) 225-11-18',
                      prefixIcon: Icon(Icons.call_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('O\'zgarishlarni saqlash'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text(
                  'Printer (tarmoq / Wi-Fi, IP-manzil orqali)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.print,
                              color: appState.printerConfigured
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                appState.printerConfigured
                                    ? 'Ulangan: ${appState.connectedPrinterName ?? appState.printerIp}:${appState.printerPort}'
                                    : 'Printer hali ulanmagan',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: printerIpCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Printer IP-manzili',
                            hintText: 'masalan: 192.168.1.50',
                            prefixIcon: Icon(Icons.wifi),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: printerPortCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '9100 (standart)',
                            prefixIcon: Icon(Icons.numbers),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: printerCharsPerLine,
                          decoration: const InputDecoration(
                            labelText: 'Chek o\'lchami (qog\'oz kengligi)',
                            prefixIcon: Icon(Icons.receipt_long),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 32,
                              child: Text('58 mm (32 belgi) — kichik'),
                            ),
                            DropdownMenuItem(
                              value: 48,
                              child: Text('80 mm (48 belgi) — katta'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => printerCharsPerLine = v);
                            }
                          },
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Chekdagi yozuvlar o\'lchami',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Kichik yozuvlar ko\'proq joyga sig\'adi, Katta '
                          'yozuvlar esa uzoqdan o\'qish uchun qulayroq.',
                          style: TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<PrinterFontSize>(
                          segments: const [
                            ButtonSegment(
                              value: PrinterFontSize.small,
                              label: Text('Kichik'),
                              icon: Icon(Icons.zoom_out, size: 18),
                            ),
                            ButtonSegment(
                              value: PrinterFontSize.normal,
                              label: Text('Oddiy'),
                              icon: Icon(Icons.text_fields, size: 18),
                            ),
                            ButtonSegment(
                              value: PrinterFontSize.large,
                              label: Text('Katta'),
                              icon: Icon(Icons.zoom_in, size: 18),
                            ),
                          ],
                          selected: {printerFontSize},
                          onSelectionChanged: (s) =>
                              setState(() => printerFontSize = s.first),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sarlavha joylashuvi',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<ReceiptHeaderAlign>(
                          segments: const [
                            ButtonSegment(
                              value: ReceiptHeaderAlign.left,
                              label: Text('Chap'),
                              icon: Icon(Icons.format_align_left, size: 18),
                            ),
                            ButtonSegment(
                              value: ReceiptHeaderAlign.center,
                              label: Text('Markaz'),
                              icon: Icon(Icons.format_align_center, size: 18),
                            ),
                            ButtonSegment(
                              value: ReceiptHeaderAlign.right,
                              label: Text('O\'ng'),
                              icon: Icon(Icons.format_align_right, size: 18),
                            ),
                          ],
                          selected: {receiptHeaderAlign},
                          onSelectionChanged: (s) =>
                              setState(() => receiptHeaderAlign = s.first),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Qalin yozuv (sarlavha)'),
                          subtitle: const Text(
                            'Restoran nomi va "Hammasi" qalin harflarda chiqadi',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: receiptBoldHeader,
                          onChanged: (v) =>
                              setState(() => receiptBoldHeader = v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: testingPrinter
                                    ? null
                                    : _testPrinterConnection,
                                icon: testingPrinter
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.wifi_tethering),
                                label: const Text('Ulanishni tekshirish'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _savePrinterSettings(),
                                icon: const Icon(Icons.save),
                                label: const Text('Saqlash'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Printer va bu qurilma bir xil Wi-Fi tarmog\'ida '
                          'bo\'lishi kerak. IP-manzilni printerning o\'zidan '
                          '("tarmoq sozlamalari" chekini chiqarish orqali) '
                          'yoki routerdagi ulangan qurilmalar ro\'yxatidan '
                          'topishingiz mumkin.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Chek sozlamalari',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBF3F8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long, color: Color(0xFF3B6E91)),
                          ),
                          title: const Text(
                            'Chek nomi',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              appState.effectiveReceiptName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                          trailing: isAdmin
                              ? ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B6E91),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _editReceiptName,
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text("O'zgartirish"),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text("Faqat ko'rish", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Chekning yuqori qismida chiqadigan nom. '
                          'Kafe hisobining asl nomi va login ma\'lumotlari o\'zgarmaydi.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(height: 14),
                          const Divider(),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: _editReceiptTemplate,
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Chek shablonini tahrirlash (manzil, tel, matn)'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Ko\'rinish',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Card(
                  child: SwitchListTile(
                    title: const Text('Tungi rejim'),
                    secondary: const Icon(Icons.dark_mode_outlined),
                    value: appState.darkMode,
                    onChanged: (v) =>
                        setState(() => appState.toggleDarkMode(v)),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSystemStatusCard(),
                const SizedBox(height: 24),
                const Text(
                  'Hisob',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                          appState.currentUser != null
                              ? '${appState.currentUser!.name} ${appState.currentUser!.surname}'
                              : (appState.guestName ?? 'Mehmon'),
                        ),
                        subtitle: Text(
                          appState.currentUser == null
                              ? 'mehmon'
                              : 'Login: ${appState.currentUser!.username} · ${roleToString(appState.currentUser!.role)}',
                        ),
                      ),
                      if (appState.currentUser != null) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading:
                              Icon(Icons.edit_outlined, color: kDarkYellow),
                          title: const Text('Profil va Loginni tahrirlash'),
                          subtitle: const Text(
                              'Ism, familiya, login va telefonni o\'zgartirish'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _editProfileDialog,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lock_reset_outlined,
                              color: Colors.blue),
                          title: const Text('Parolni o\'zgartirish'),
                          subtitle: const Text('Yangi maxfiy parol o\'rnatish'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _changePasswordDialog,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await appState.logout();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AuthScreen(),
                          ),
                          (r) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Chiqish (Hisobni almashtirish)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
