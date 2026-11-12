// ignore_for_file: non_const_argument_for_const_parameter

import 'dart:convert';
import 'package:flutter/material.dart';
export '../utils/safe_parse.dart';
import '../utils/safe_parse.dart';

enum UserRole { director, admin, cashier, waiter, courier, customer }

String roleToString(UserRole r) {
  switch (r) {
    case UserRole.director:
      return 'Director (SaaS)';
    case UserRole.admin:
      return 'Administrator (Cafe egasi)';
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



UserRole stringToRole(String s) {
  switch (s.toLowerCase()) {
    case 'director':
      return UserRole.director;
    case 'admin':
    case 'administrator':
      return UserRole.admin;
    case 'cashier':
    case 'kassir':
      return UserRole.cashier;
    case 'waiter':
    case 'ofitsiant':
      return UserRole.waiter;
    case 'courier':
    case 'kuryer':
      return UserRole.courier;
    case 'customer':
    case 'mijoz':
    default:
      return UserRole.customer;
  }
}

enum TableStatus { free, occupied, reserved }

enum PaymentMethod { cash, card, split }

String paymentMethodToString(PaymentMethod m) {
  switch (m) {
    case PaymentMethod.cash:
      return 'Naqd';
    case PaymentMethod.card:
      return 'Karta';
    case PaymentMethod.split:
      return 'Aralash';
  }
}

enum OrderType { dineIn, takeaway, delivery }

enum OrderStatus { pending, preparing, ready, delivered, completed, cancelled }

String orderStatusToString(OrderStatus s) {
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
      return 'Bekor qilindi';
  }
}

/// Foydalanuvchi hisobi modeli
class AppUser {
  int id;
  String uid; // Firebase Auth UID
  String name;
  String surname;
  String username;
  String email;
  String phone;
  String password;
  UserRole role;
  double salary;
  String ownerId; // Firebase UID (legacy)
  String cafeId; // Workspace ID — masalan: cafe1, cafe2
  String cafeName;
  String receiptName;
  DateTime? cafeEndDate;
  bool isActive;
  bool mustChangePassword;
  bool isBlocked;
  bool isExpired;
  DateTime createdAt;

  AppUser({
    required this.id,
    this.uid = '',
    required this.name,
    this.surname = '',
    required this.username,
    this.email = '',
    this.phone = '',
    required this.password,
    required this.role,
    this.salary = 0,
    this.ownerId = '',
    this.cafeId = '',
    this.cafeName = '',
    this.receiptName = '',
    this.cafeEndDate,
    this.isActive = true,
    this.mustChangePassword = false,
    this.isBlocked = false,
    this.isExpired = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Joriy foydalanuvchi workspace ID
  String get workspaceId =>
      cafeId.isNotEmpty ? cafeId : (ownerId.isNotEmpty ? ownerId : uid);

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'name': name,
        'surname': surname,
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role.name,
        'salary': salary,
        'ownerId': ownerId,
        'cafeId': cafeId,
        'cafeName': cafeName,
        'receiptName': receiptName,
        'cafeEndDate': cafeEndDate?.toIso8601String(),
        'isActive': isActive,
        'mustChangePassword': mustChangePassword,
        'isBlocked': isBlocked,
        'isExpired': isExpired,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: safeInt(j['id']),
        uid: j['uid'] as String? ?? '',
        name: j['name'] as String? ?? '',
        surname: j['surname'] as String? ?? '',
        username: j['username'] as String? ?? '',
        email: j['email'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        password: j['password'] as String? ?? '',
        role: j['role'] != null
            ? UserRole.values.firstWhere(
                (e) => e.name == j['role'],
                orElse: () => stringToRole(j['role'].toString()),
              )
            : UserRole.cashier,
        salary: safeDouble(j['salary']),
        ownerId: j['ownerId'] as String? ?? '',
        cafeId: j['cafeId'] as String? ?? '',
        cafeName: j['cafeName'] as String? ?? '',
        receiptName: j['receiptName'] as String? ?? '',
        cafeEndDate: j['cafeEndDate'] != null
            ? DateTime.tryParse(j['cafeEndDate'] as String)
            : null,
        isActive: j['isActive'] != false,
        mustChangePassword: j['mustChangePassword'] == true,
        isBlocked: j['isBlocked'] == true,
        isExpired: j['isExpired'] == true,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// ZAVERO SaaS Platform Metrikalari
class DirectorMetrics {
  final int totalCafes;
  final int activeCafes;
  final int blockedCafes;
  final int expiredCafes;
  final int totalUsers;
  final int totalWorkers;
  final int totalOwners;
  final int activeDevices;
  final int totalOrders;
  final int todayOrders;
  final double todayRevenue;
  final double totalRevenue;

  DirectorMetrics({
    this.totalCafes = 0,
    this.activeCafes = 0,
    this.blockedCafes = 0,
    this.expiredCafes = 0,
    this.totalUsers = 0,
    this.totalWorkers = 0,
    this.totalOwners = 0,
    this.activeDevices = 0,
    this.totalOrders = 0,
    this.todayOrders = 0,
    this.todayRevenue = 0,
    this.totalRevenue = 0,
  });

  factory DirectorMetrics.fromJson(Map<String, dynamic> j) => DirectorMetrics(
        totalCafes: safeInt(j['totalCafes']),
        activeCafes: safeInt(j['activeCafes']),
        blockedCafes: safeInt(j['blockedCafes']),
        expiredCafes: safeInt(j['expiredCafes']),
        totalUsers: safeInt(j['totalUsers']),
        totalWorkers: safeInt(j['totalWorkers']),
        totalOwners: safeInt(j['totalOwners']),
        activeDevices: safeInt(j['activeDevices']),
        totalOrders: safeInt(j['totalOrders']),
        todayOrders: safeInt(j['todayOrders']),
        todayRevenue: safeDouble(j['todayRevenue']),
        totalRevenue: safeDouble(j['totalRevenue']),
      );
}

/// Cafe SaaS elementi
class CafeSaaSItem {
  final String id;
  final String cafeId;
  final String name;
  final String receiptName;
  final String ownerName;
  final String ownerPhone;
  final String ownerEmail;
  final String status; // active, blocked, expired
  final bool isBlocked;
  final bool isExpired;
  final DateTime? startDate;
  final DateTime? endDate;
  final int usersCount;
  final int tablesCount;
  final int receiptsCount;
  final int activeDevicesCount;
  final DateTime? createdAt;

  CafeSaaSItem({
    required this.id,
    required this.cafeId,
    required this.name,
    this.receiptName = '',
    this.ownerName = '',
    this.ownerPhone = '',
    this.ownerEmail = '',
    this.status = 'active',
    this.isBlocked = false,
    this.isExpired = false,
    this.startDate,
    this.endDate,
    this.usersCount = 0,
    this.tablesCount = 0,
    this.receiptsCount = 0,
    this.activeDevicesCount = 0,
    this.createdAt,
  });

  factory CafeSaaSItem.fromJson(Map<String, dynamic> j) => CafeSaaSItem(
        id: j['id'] as String? ?? j['cafeId'] as String? ?? '',
        cafeId: j['cafeId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        receiptName: j['receiptName'] as String? ?? '',
        ownerName: j['ownerName'] as String? ?? '',
        ownerPhone: j['ownerPhone'] as String? ?? '',
        ownerEmail: j['ownerEmail'] as String? ?? '',
        status: j['status'] as String? ?? 'active',
        isBlocked: j['isBlocked'] == true,
        isExpired: j['isExpired'] == true,
        startDate: j['startDate'] != null
            ? DateTime.tryParse(j['startDate'] as String)
            : null,
        endDate: j['endDate'] != null
            ? DateTime.tryParse(j['endDate'] as String)
            : null,
        usersCount: safeInt(j['usersCount']),
        tablesCount: safeInt(j['tablesCount']),
        receiptsCount: safeInt(j['receiptsCount']),
        activeDevicesCount: safeInt(j['activeDevicesCount']),
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );

  int get daysLeft {
    if (endDate == null) return 999;
    final diff = endDate!.difference(DateTime.now()).inDays;
    return diff;
  }
}

/// SaaS Faoliyat jurnali yozuvi
class AuditLogItem {
  final int id;
  final int? actorId;
  final String actorName;
  final String actorRole;
  final String cafeId;
  final String cafeName;
  final String action;
  final String targetType;
  final String targetId;
  final DateTime? createdAt;

  AuditLogItem({
    required this.id,
    this.actorId,
    this.actorName = '',
    this.actorRole = '',
    this.cafeId = '',
    this.cafeName = '',
    required this.action,
    this.targetType = '',
    this.targetId = '',
    this.createdAt,
  });

  factory AuditLogItem.fromJson(Map<String, dynamic> j) => AuditLogItem(
        id: safeInt(j['id']),
        actorId: safeNullableInt(j['actor_id'] ?? j['actorId']),
        actorName: j['actor_name'] as String? ?? '',
        actorRole: j['actor_role'] as String? ?? '',
        cafeId: j['cafe_id'] as String? ?? '',
        cafeName: j['cafe_name'] as String? ?? '',
        action: j['action'] as String? ?? '',
        targetType: j['target_type'] as String? ?? '',
        targetId: j['target_id'] as String? ?? '',
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );
}

/// Ulangan qurilma modeli
class DeviceInfo {
  final int id;
  final String deviceName;
  final String deviceType;
  final String? deviceIdentifier;
  final String? userName;
  final DateTime? lastSeen;
  final bool isActive;

  DeviceInfo({
    required this.id,
    required this.deviceName,
    this.deviceType = 'desktop',
    this.deviceIdentifier,
    this.userName,
    this.lastSeen,
    this.isActive = true,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> j) => DeviceInfo(
        id: safeInt(j['id']),
        deviceName: j['device_name'] as String? ?? '',
        deviceType: j['device_type'] as String? ?? 'desktop',
        deviceIdentifier: j['device_identifier'] as String?,
        userName: j['user_name'] as String?,
        lastSeen: j['last_seen'] != null
            ? DateTime.tryParse(j['last_seen'] as String)
            : null,
        isActive: j['is_active'] != false,
      );
}

/// Kunlik hisobot modeli — cafes/{cafeId}/reports/{dateId}
class DailyReport {
  final String dateId;
  final double totalRevenue;
  final int orderCount;
  final Map<String, int> productQuantities;
  final Map<String, double> productRevenue;
  final String topProduct;
  final Map<String, double> tableRevenue;
  final DateTime updatedAt;

  DailyReport({
    required this.dateId,
    this.totalRevenue = 0,
    this.orderCount = 0,
    this.productQuantities = const {},
    this.productRevenue = const {},
    this.topProduct = '',
    this.tableRevenue = const {},
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'dateId': dateId,
        'totalRevenue': totalRevenue,
        'orderCount': orderCount,
        'productQuantities': productQuantities,
        'productRevenue': productRevenue,
        'topProduct': topProduct,
        'tableRevenue': tableRevenue,
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Backend REST API javobi (`/api/reports/...`) uchun — plain JSON,
  /// Firestore Timestamp emas.
  factory DailyReport.fromJson(Map<String, dynamic> data) {
    Map<String, int> qtyMap = {};
    final rawQty = data['productQuantities'];
    if (rawQty is Map) {
      rawQty.forEach((k, v) => qtyMap['$k'] = safeInt(v));
    }

    Map<String, double> revMap = {};
    final rawRev = data['productRevenue'];
    if (rawRev is Map) {
      rawRev.forEach((k, v) => revMap['$k'] = safeDouble(v));
    }

    Map<String, double> tableMap = {};
    final rawTable = data['tableRevenue'];
    if (rawTable is Map) {
      rawTable.forEach((k, v) => tableMap['$k'] = safeDouble(v));
    }

    return DailyReport(
      dateId: data['dateId'] as String? ?? '',
      totalRevenue: safeDouble(data['totalRevenue']),
      orderCount: safeInt(data['orderCount']),
      productQuantities: qtyMap,
      productRevenue: revMap,
      topProduct: data['topProduct'] as String? ?? '',
      tableRevenue: tableMap,
      updatedAt: data['updatedAt'] != null
          ? DateTime.tryParse(data['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static String dateIdFrom(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

IconData resolveIconData(int? codePoint, {IconData fallback = Icons.fastfood}) {
  if (codePoint == null || codePoint <= 0) return fallback;
  switch (codePoint) {
    case 61925:
      return const IconData(61925, fontFamily: 'MaterialIcons');
    case 58746:
      return const IconData(58746, fontFamily: 'MaterialIcons');
    case 61589:
      return const IconData(61589, fontFamily: 'MaterialIcons');
    case 61853:
      return const IconData(61853, fontFamily: 'MaterialIcons');
    case 58710:
      return const IconData(58710, fontFamily: 'MaterialIcons');
    case 58717:
      return const IconData(58717, fontFamily: 'MaterialIcons');
    case 58688:
      return const IconData(58688, fontFamily: 'MaterialIcons');
    case 60000:
      return const IconData(60000, fontFamily: 'MaterialIcons');
    case 59283:
      return const IconData(59283, fontFamily: 'MaterialIcons');
    case 58724:
      return const IconData(58724, fontFamily: 'MaterialIcons');
    case 59369:
      return const IconData(59369, fontFamily: 'MaterialIcons');
    case 58306:
      return const IconData(58306, fontFamily: 'MaterialIcons');
    case 58256:
      return const IconData(58256, fontFamily: 'MaterialIcons');
    case 0xe25a: // Icons.fastfood
      return Icons.fastfood;
    case 0xe318: // Icons.home_work
      return Icons.home_work;
    case 0xe39d: // Icons.local_dining
      return Icons.local_dining;
    case 0xe395: // Icons.local_cafe
      return Icons.local_cafe;
    case 0xe39b: // Icons.local_bar
      return Icons.local_bar;
    case 0xe3ab: // Icons.local_pizza
      return Icons.local_pizza;
    default:
      return fallback;
  }
}

/// Menyu kategoriyasi modeli
class Category {
  int id;
  String name;
  IconData icon;

  Category({
    required this.id,
    required this.name,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': icon.codePoint,
      };

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: safeInt(j['id']),
        name: j['name'] as String? ?? '',
        icon: resolveIconData(
          safeNullableInt(j['iconCodePoint'] ?? j['icon_code_point']),
          fallback: Icons.fastfood,
        ),
      );

}

/// Mahsulot / Taom modeli
class Product {
  int id;
  String name;
  double price;
  int categoryId;
  int stock;
  IconData icon;
  String? imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.stock,
    required this.icon,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'categoryId': categoryId,
        'stock': stock,
        'iconCodePoint': icon.codePoint,
        'imageUrl': imageUrl,
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: safeInt(j['id']),
        name: j['name'] as String? ?? '',
        price: safeDouble(j['price']),
        categoryId: safeInt(j['categoryId'] ?? j['category_id']),
        stock: safeInt(j['stock']),
        icon: resolveIconData(
          safeNullableInt(j['iconCodePoint'] ?? j['icon_code_point']),
          fallback: Icons.fastfood,
        ),
        imageUrl: (j['imageUrl'] ?? j['image_url']) as String?,
      );

}

/// Zal / Joy modeli
class Hall {
  int id;
  String name;
  IconData icon;
  String? imageAsset;

  Hall({
    required this.id,
    required this.name,
    required this.icon,
    this.imageAsset,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': icon.codePoint,
        'imageAsset': imageAsset,
      };

  factory Hall.fromJson(Map<String, dynamic> j) => Hall(
        id: safeInt(j['id']),
        name: j['name'] as String? ?? '',
        icon: resolveIconData(
          safeNullableInt(j['iconCodePoint'] ?? j['icon_code_point']),
          fallback: Icons.home_work,
        ),
        imageAsset: j['imageAsset'] as String?,
      );

}

/// Stol modeli
class TableModel {
  int id;
  int hallId;
  int number;
  int seats;
  TableStatus status;

  TableModel({
    required this.id,
    required this.hallId,
    required this.number,
    required this.seats,
    this.status = TableStatus.free,
  });

  String get tableKey => '${hallId}_$id';
  String get zoneNumberKey => '${hallId}_$number';

  Map<String, dynamic> toJson() => {
        'id': id,
        'hallId': hallId,
        'number': number,
        'seats': seats,
        'status': status.name,
      };

  factory TableModel.fromJson(Map<String, dynamic> j) => TableModel(
        id: safeInt(j['id']),
        hallId: safeInt(j['hallId'] ?? j['hall_id']),
        number: safeInt(j['number']),
        seats: safeInt(j['seats'], 4),
        status: TableStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => TableStatus.free,
        ),
      );

}

/// Savat elementi modeli
class CartItem {
  Product product;
  int qty;
  String note;

  CartItem({
    required this.product,
    this.qty = 1,
    this.note = '',
  });

  double get total => product.price * qty;

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'qty': qty,
        'note': note,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) {
    Product prod;
    if (j['product'] is Map) {
      prod = Product.fromJson(Map<String, dynamic>.from(j['product'] as Map));
    } else {
      prod = Product(
        id: safeInt(j['productId'] ?? j['id']),
        name: (j['name'] ?? j['productName'] ?? 'Taom').toString(),
        price: safeDouble(j['price']),
        categoryId: safeInt(j['categoryId'] ?? j['category_id'], 1),
        stock: safeInt(j['stock'], 999),
        icon: resolveIconData(safeNullableInt(j['iconCodePoint'] ?? j['icon_code_point']), fallback: Icons.fastfood_rounded),
        imageUrl: (j['imageUrl'] ?? j['image'])?.toString(),
      );
    }
    final rawQty = j['qty'] ?? j['quantity'] ?? j['count'];
    final qty = safeInt(rawQty, 1);
    final note = (j['note'] ?? j['notes'] ?? '').toString();
    return CartItem(
      product: prod,
      qty: qty > 0 ? qty : 1,
      note: note,
    );
  }

}

/// Mijoz modeli
class Customer {
  int id;
  String name;
  String phone;
  String email;
  int loyaltyPoints;

  Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.loyaltyPoints = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'loyaltyPoints': loyaltyPoints,
      };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: safeInt(j['id']),
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        email: j['email'] as String? ?? '',
        loyaltyPoints: safeInt(j['loyaltyPoints']),
      );

}

/// To'langan chek modeli
class Receipt {
  int id;
  DateTime date;
  List<CartItem> items;
  double total;
  PaymentMethod method;
  String cashierName;
  int? tableId;
  int? tableNumber;
  int? hallId;
  String? hallName;
  int? waiterId;
  String? waiterName;
  double cashPaid;
  double cardPaid;
  String printStatus; // 'printed', 'queued', 'unprinted'
  DateTime? printedAt;
  String telegramStatus; // 'sent', 'failed', 'unsent'
  DateTime? telegramSentAt;

  Receipt({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
    required this.method,
    required this.cashierName,
    this.tableId,
    this.tableNumber,
    this.hallId,
    this.hallName,
    this.waiterId,
    this.waiterName,
    this.cashPaid = 0,
    this.cardPaid = 0,
    this.printStatus = 'unprinted',
    this.printedAt,
    this.telegramStatus = 'unsent',
    this.telegramSentAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toUtc().toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
        'method': method.name,
        'cashierName': cashierName,
        'tableId': tableId,
        'tableNumber': tableNumber,
        'hallId': hallId,
        'hallName': hallName,
        'waiterId': waiterId,
        'waiterName': waiterName,
        'cashPaid': cashPaid,
        'cardPaid': cardPaid,
        'printStatus': printStatus,
        'printedAt': printedAt?.toUtc().toIso8601String(),
        'telegramStatus': telegramStatus,
        'telegramSentAt': telegramSentAt?.toUtc().toIso8601String(),
      };

  factory Receipt.fromJson(Map<String, dynamic> j) {
    final List<CartItem> parsedItems = [];
    final rawItems = j['items'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          try {
            parsedItems.add(CartItem.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('⚠️ [Receipt.fromJson] CartItem parsing xatosi: $e');
          }
        }
      }
    } else if (rawItems is String && rawItems.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawItems);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              parsedItems.add(CartItem.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      } catch (_) {}
    }

    final rawDate = j['date'] ?? j['created_at'] ?? j['createdAt'];
    DateTime parsedDate = DateTime.now();
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    }

    return Receipt(
      id: safeInt(j['id']),
      date: parsedDate,
      items: parsedItems,
      total: safeDouble(j['total']),
      method: PaymentMethod.values.firstWhere(
        (e) => e.name.toLowerCase() == (j['method'] ?? 'cash').toString().toLowerCase(),
        orElse: () => PaymentMethod.cash,
      ),
      cashierName: j['cashierName'] as String? ?? j['cashier_name'] as String? ?? '',
      tableId: safeNullableInt(j['tableId'] ?? j['table_id']),
      tableNumber: safeNullableInt(j['tableNumber'] ?? j['table_number']),
      hallId: safeNullableInt(j['hallId'] ?? j['hall_id']),
      hallName: (j['hallName'] ?? j['hall_name'])?.toString(),
      waiterId: safeNullableInt(j['waiterId'] ?? j['waiter_id']),
      waiterName: (j['waiterName'] ?? j['waiter_name'])?.toString(),
      cashPaid: safeDouble(j['cashPaid'] ?? j['cash_paid']),
      cardPaid: safeDouble(j['cardPaid'] ?? j['card_paid']),
      printStatus: (j['printStatus'] ?? j['print_status'] ?? 'unprinted').toString(),
      printedAt: j['printedAt'] != null
          ? DateTime.tryParse(j['printedAt'].toString())
          : (j['printed_at'] != null ? DateTime.tryParse(j['printed_at'].toString()) : null),
      telegramStatus: (j['telegramStatus'] ?? j['telegram_status'] ?? 'unsent').toString(),
      telegramSentAt: j['telegramSentAt'] != null
          ? DateTime.tryParse(j['telegramSentAt'].toString())
          : (j['telegram_sent_at'] != null ? DateTime.tryParse(j['telegram_sent_at'].toString()) : null),
    );
  }

}

/// Mijoz online buyurtmasi
class CustomerOrder {
  int id;
  String? cafeId;
  DateTime date;
  List<CartItem> items;
  String customerName;
  String phone;
  OrderType type;
  int? tableNumber;
  int? hallId;
  String? deliveryAddress;
  OrderStatus status;
  String? notes;

  CustomerOrder({
    required this.id,
    this.cafeId,
    required this.date,
    required this.items,
    required this.customerName,
    required this.phone,
    required this.type,
    this.tableNumber,
    this.hallId,
    this.deliveryAddress,
    this.status = OrderStatus.pending,
    this.notes,
  });

  double get total => items.fold(0, (s, i) => s + i.total);

  Map<String, dynamic> toJson() => {
        'id': id,
        'cafeId': cafeId,
        'date': date.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'customerName': customerName,
        'phone': phone,
        'type': type.name,
        'tableNumber': tableNumber,
        'hallId': hallId,
        'deliveryAddress': deliveryAddress,
        'status': status.name,
        'notes': notes,
      };

  factory CustomerOrder.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'];
    final List<CartItem> parsedItems = [];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          try {
            parsedItems.add(CartItem.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('CartItem parsing xatoligi: $e');
          }
        }
      }
    }

    final rawDate = j['date'] ?? j['createdAt'] ?? j['created_at'];
    DateTime parsedDate = DateTime.now();
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    }

    final rawStatus = (j['status'] ?? 'pending').toString().toLowerCase();
    OrderStatus parsedStatus = OrderStatus.pending;
    if (rawStatus == 'preparing' || rawStatus == 'cooking' || rawStatus == 'in_progress') {
      parsedStatus = OrderStatus.preparing;
    } else if (rawStatus == 'ready' || rawStatus == 'ready_to_serve' || rawStatus == 'delivering' || rawStatus == 'on_way') {
      parsedStatus = OrderStatus.ready;
    } else if (rawStatus == 'completed' || rawStatus == 'delivered' || rawStatus == 'served') {
      parsedStatus = OrderStatus.completed;
    } else if (rawStatus == 'cancelled' || rawStatus == 'rejected') {
      parsedStatus = OrderStatus.cancelled;
    }

    return CustomerOrder(
      id: safeInt(j['id']),
      cafeId: (j['cafeId'] ?? j['cafe_id'])?.toString(),
      date: parsedDate,
      items: parsedItems,
      customerName: (j['customerName'] ?? j['customer_name'] ?? '').toString(),
      phone: (j['phone'] ?? '').toString(),
      type: OrderType.values.firstWhere(
        (e) => e.name.toLowerCase() == (j['type'] ?? 'dineIn').toString().toLowerCase(),
        orElse: () => OrderType.dineIn,
      ),
      tableNumber: safeNullableInt(j['tableNumber'] ?? j['table_number']),
      hallId: safeNullableInt(j['hallId'] ?? j['hall_id']),
      deliveryAddress: (j['deliveryAddress'] ?? j['delivery_address'])?.toString(),
      status: parsedStatus,
      notes: (j['notes'] ?? j['comment'])?.toString(),
    );
  }

}

/// Faoliyat jurnali modeli
class ActivityLog {
  final String id;
  final String action;
  final String details;
  final String performedBy;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.action,
    required this.details,
    required this.performedBy,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Tizim va buyurtma bildirishnomalari modeli (qo'ng'iroqcha paneli uchun)
class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  bool isRead;
  final String type; // 'order', 'system', 'subscription'

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
    this.type = 'order',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'time': time.toIso8601String(),
    'isRead': isRead,
    'type': type,
  };

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) => AppNotificationItem(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    time: DateTime.tryParse(json['time']?.toString() ?? '') ?? DateTime.now(),
    isRead: json['isRead'] == true,
    type: json['type']?.toString() ?? 'order',
  );
}

class TodayWaiterMetric {
  final String name;
  final int orderCount;
  final int totalRevenue;

  TodayWaiterMetric({
    required this.name,
    required this.orderCount,
    required this.totalRevenue,
  });

  factory TodayWaiterMetric.fromJson(Map<String, dynamic> j) => TodayWaiterMetric(
        name: j['name'] as String? ?? 'Kassa',
        orderCount: safeInt(j['orderCount']),
        totalRevenue: safeInt(j['totalRevenue']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'orderCount': orderCount,
        'totalRevenue': totalRevenue,
      };
}

class TodayProductMetric {
  final String name;
  final int quantity;
  final int totalRevenue;

  TodayProductMetric({
    required this.name,
    required this.quantity,
    required this.totalRevenue,
  });

  factory TodayProductMetric.fromJson(Map<String, dynamic> j) => TodayProductMetric(
        name: j['name'] as String? ?? '',
        quantity: safeInt(j['quantity']),
        totalRevenue: safeInt(j['totalRevenue']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'totalRevenue': totalRevenue,
      };
}

class TodayReportSummary {
  final int totalRevenue;
  final int orderCount;
  final int cashTotal;
  final int cardTotal;
  final int averageCheck;
  final List<TodayWaiterMetric> waiters;
  final List<TodayProductMetric> topProducts;
  final DateTime updatedAt;

  TodayReportSummary({
    required this.totalRevenue,
    required this.orderCount,
    required this.cashTotal,
    required this.cardTotal,
    required this.averageCheck,
    required this.waiters,
    required this.topProducts,
    required this.updatedAt,
  });

  factory TodayReportSummary.fromJson(Map<String, dynamic> j) {
    return TodayReportSummary(
      totalRevenue: safeInt(j['totalRevenue']),
      orderCount: safeInt(j['orderCount']),
      cashTotal: safeInt(j['cashTotal']),
      cardTotal: safeInt(j['cardTotal']),
      averageCheck: safeInt(j['averageCheck']),
      waiters: (j['waiters'] as List?)
              ?.map((e) => TodayWaiterMetric.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      topProducts: (j['topProducts'] as List?)
              ?.map((e) => TodayProductMetric.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      updatedAt: j['updatedAt'] != null
          ? DateTime.tryParse(j['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalRevenue': totalRevenue,
        'orderCount': orderCount,
        'cashTotal': cashTotal,
        'cardTotal': cardTotal,
        'averageCheck': averageCheck,
        'waiters': waiters.map((w) => w.toJson()).toList(),
        'topProducts': topProducts.map((p) => p.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

