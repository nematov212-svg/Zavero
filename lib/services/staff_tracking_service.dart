import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'socket_service.dart';

class StaffMemberStatus {
  final int userId;
  final String userName;
  final String role;
  bool isOnBreak;
  DateTime? breakStartedAt;
  String statusText;
  String location;
  double distanceMeters;
  int steps;
  DateTime lastActive;
  bool isMoving;
  double x; // 0.0 to 1.0 relative position on cafe radar map
  double y; // 0.0 to 1.0 relative position on cafe radar map

  // Real-time GPS Location fields
  double latitude;
  double longitude;
  double accuracyMeters;
  String zoneName;
  String address;
  bool gpsActive;

  StaffMemberStatus({
    required this.userId,
    required this.userName,
    required this.role,
    this.isOnBreak = false,
    this.breakStartedAt,
    this.statusText = 'Faol / Ishlamoqda',
    this.location = '1-Zal',
    this.distanceMeters = 0.0,
    this.steps = 0,
    DateTime? lastActive,
    this.isMoving = false,
    this.x = 0.3,
    this.y = 0.4,
    double? latitude,
    double? longitude,
    this.accuracyMeters = 3.5,
    this.zoneName = '🍽️ 1-Zal (Stollar)',
    this.address = 'ZAVERO Cafe, Toshkent',
    this.gpsActive = true,
  })  : lastActive = lastActive ?? DateTime.now(),
        latitude = latitude ?? (41.2995 + (userId % 5) * 0.00015),
        longitude = longitude ?? (69.2401 + (userId % 7) * 0.00015);

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'userName': userName,
        'role': role,
        'isOnBreak': isOnBreak,
        'breakStartedAt': breakStartedAt?.toIso8601String(),
        'statusText': statusText,
        'location': location,
        'distanceMeters': distanceMeters,
        'steps': steps,
        'lastActive': lastActive.toIso8601String(),
        'isMoving': isMoving,
        'x': x,
        'y': y,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'zoneName': zoneName,
        'address': address,
        'gpsActive': gpsActive,
      };

  factory StaffMemberStatus.fromJson(Map<String, dynamic> j) {
    return StaffMemberStatus(
      userId: (j['userId'] as num?)?.toInt() ?? 0,
      userName: j['userName'] as String? ?? 'Xodim',
      role: j['role'] as String? ?? 'waiter',
      isOnBreak: j['isOnBreak'] == true,
      breakStartedAt: j['breakStartedAt'] != null
          ? DateTime.tryParse(j['breakStartedAt'])
          : null,
      statusText: j['statusText'] as String? ?? 'Faol / Ishlamoqda',
      location: j['location'] as String? ?? '1-Zal',
      distanceMeters: (j['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      steps: (j['steps'] as num?)?.toInt() ?? 0,
      lastActive: j['lastActive'] != null
          ? DateTime.tryParse(j['lastActive'])
          : DateTime.now(),
      isMoving: j['isMoving'] == true,
      x: (j['x'] as num?)?.toDouble() ?? 0.3,
      y: (j['y'] as num?)?.toDouble() ?? 0.4,
      latitude: (j['latitude'] as num?)?.toDouble() ?? 41.2995,
      longitude: (j['longitude'] as num?)?.toDouble() ?? 69.2401,
      accuracyMeters: (j['accuracyMeters'] as num?)?.toDouble() ?? 3.5,
      zoneName: j['zoneName'] as String? ?? '🍽️ 1-Zal (Stollar)',
      address: j['address'] as String? ?? 'ZAVERO Cafe, Toshkent',
      gpsActive: j['gpsActive'] != false,
    );
  }
}

class StaffTrackingService extends ChangeNotifier {
  static final StaffTrackingService _instance = StaffTrackingService._internal();
  factory StaffTrackingService() => _instance;
  StaffTrackingService._internal() {
    _initSocketListeners();
  }

  final Map<int, StaffMemberStatus> _staffStatuses = {};
  StreamSubscription? _statusSub;
  StreamSubscription? _movementSub;
  Timer? _movementSimulationTimer;
  final math.Random _random = math.Random();

  List<StaffMemberStatus> get allStatuses => _staffStatuses.values.toList();

  StaffMemberStatus? getStatus(int userId) => _staffStatuses[userId];

  void _initSocketListeners() {
    _statusSub?.cancel();
    _statusSub =
        SocketService().on(CafeSocketEvent.staffStatusUpdated).listen((data) {
      final uId = (data['userId'] as num?)?.toInt();
      if (uId == null) return;

      final existing = _staffStatuses[uId];
      final isOnBreak = data['isOnBreak'] == true;
      final breakStartedStr = data['breakStartedAt'] as String?;
      final statusText = data['statusText'] as String? ??
          (isOnBreak ? 'Dam olmoqda' : 'Faol / Ishlamoqda');

      if (existing != null) {
        existing.isOnBreak = isOnBreak;
        existing.statusText = statusText;
        existing.lastActive = DateTime.now();
        if (isOnBreak && existing.breakStartedAt == null) {
          existing.breakStartedAt = breakStartedStr != null
              ? DateTime.tryParse(breakStartedStr)
              : DateTime.now();
        } else if (!isOnBreak) {
          existing.breakStartedAt = null;
        }
      } else {
        _staffStatuses[uId] = StaffMemberStatus(
          userId: uId,
          userName: data['userName'] as String? ?? 'Xodim #$uId',
          role: data['role'] as String? ?? 'waiter',
          isOnBreak: isOnBreak,
          breakStartedAt: breakStartedStr != null
              ? DateTime.tryParse(breakStartedStr)
              : (isOnBreak ? DateTime.now() : null),
          statusText: statusText,
          location: data['location'] as String? ?? '1-Zal',
          distanceMeters: (data['distanceMeters'] as num?)?.toDouble() ?? 0.0,
          steps: (data['steps'] as num?)?.toInt() ?? 0,
        );
      }
      notifyListeners();
    });

    _movementSub?.cancel();
    _movementSub =
        SocketService().on(CafeSocketEvent.staffMovementUpdated).listen((data) {
      final uId = (data['userId'] as num?)?.toInt();
      if (uId == null) return;

      final existing = _staffStatuses[uId];
      if (existing != null) {
        if (data['distanceMeters'] != null) {
          existing.distanceMeters = (data['distanceMeters'] as num).toDouble();
        }
        if (data['steps'] != null) {
          existing.steps = (data['steps'] as num).toInt();
        }
        if (data['location'] != null) {
          existing.location = data['location'] as String;
        }
        if (data['x'] != null) existing.x = (data['x'] as num).toDouble();
        if (data['y'] != null) existing.y = (data['y'] as num).toDouble();
        if (data['latitude'] != null) {
          existing.latitude = (data['latitude'] as num).toDouble();
        }
        if (data['longitude'] != null) {
          existing.longitude = (data['longitude'] as num).toDouble();
        }
        if (data['zoneName'] != null) {
          existing.zoneName = data['zoneName'] as String;
        }
        existing.isMoving = data['isMoving'] == true;
        existing.lastActive = DateTime.now();
        notifyListeners();
      }
    });
  }

  /// Xodimlar ro'yxatini yuklash va boshlang'ich lokatsiya & holatni sozlash
  void syncStaffList(List<AppUser> users) {
    for (final user in users) {
      if (!_staffStatuses.containsKey(user.id)) {
        final isWait = user.role == UserRole.waiter;
        _staffStatuses[user.id] = StaffMemberStatus(
          userId: user.id,
          userName: user.name,
          role: user.role.name,
          isOnBreak: false,
          statusText: isWait ? 'Faol / Ishlamoqda' : 'Kassada faol',
          location: isWait ? '1-Zal · Stollar' : 'Asosiy Kassa',
          zoneName: isWait ? '🍽️ 1-Zal (Stollar 1-6)' : '💳 Kassa & Bar',
          distanceMeters: 45.0 + (_random.nextInt(60)),
          steps: 90 + (_random.nextInt(120)),
          x: 0.2 + (_random.nextDouble() * 0.6),
          y: 0.2 + (_random.nextDouble() * 0.6),
          latitude: 41.2995 + (_random.nextDouble() * 0.0004 - 0.0002),
          longitude: 69.2401 + (_random.nextDouble() * 0.0004 - 0.0002),
          accuracyMeters: 2.5 + (_random.nextDouble() * 2.0),
          address: 'ZAVERO Cafe binosi, Toshkent',
          gpsActive: true,
        );
      }
    }
    notifyListeners();
  }

  /// Xodim GPS lokatsiyasini to'g'ridan-to'g'ri yangilash
  void updateStaffLocation(
    int userId, {
    required double lat,
    required double lng,
    String? zone,
    String? addr,
    double? accuracy,
  }) {
    final status = _staffStatuses[userId];
    if (status != null) {
      status.latitude = lat;
      status.longitude = lng;
      if (zone != null) status.zoneName = zone;
      if (addr != null) status.address = addr;
      if (accuracy != null) status.accuracyMeters = accuracy;
      status.gpsActive = true;
      status.lastActive = DateTime.now();
      notifyListeners();
    }
  }

  /// Dam olish rejimini yoqish / o'chirish ("Dam olmoqda" toggle)
  void setBreakMode({
    required AppUser user,
    required String cafeId,
    required bool isOnBreak,
  }) {
    final status = _staffStatuses.putIfAbsent(
      user.id,
      () => StaffMemberStatus(
        userId: user.id,
        userName: user.name,
        role: user.role.name,
      ),
    );

    status.isOnBreak = isOnBreak;
    status.breakStartedAt = isOnBreak ? DateTime.now() : null;
    status.statusText = isOnBreak ? 'Dam olmoqda' : 'Faol / Ishlamoqda';
    status.lastActive = DateTime.now();
    if (isOnBreak) {
      status.zoneName = '☕ Dam olish xonasi';
      status.location = 'Dam olish xonasi';
    }

    final payload = {
      'cafeId': cafeId,
      'userId': user.id,
      'userName': user.name,
      'role': user.role.name,
      'isOnBreak': isOnBreak,
      'breakStartedAt': status.breakStartedAt?.toIso8601String(),
      'statusText': status.statusText,
      'location': status.location,
      'zoneName': status.zoneName,
      'distanceMeters': status.distanceMeters,
      'steps': status.steps,
      'x': status.x,
      'y': status.y,
      'latitude': status.latitude,
      'longitude': status.longitude,
    };

    SocketService().emitStaffStatus(payload);
    notifyListeners();
  }

  /// Harakat (metr va qadamlar) qo'shish va real-time yuborish
  void recordMovement({
    required AppUser user,
    required String cafeId,
    double deltaMeters = 2.5,
    String? location,
    double? x,
    double? y,
  }) {
    final status = _staffStatuses.putIfAbsent(
      user.id,
      () => StaffMemberStatus(
        userId: user.id,
        userName: user.name,
        role: user.role.name,
      ),
    );

    if (status.isOnBreak) return; // Dam olayotganda harakat sanalmaydi

    status.distanceMeters += deltaMeters;
    status.steps += (deltaMeters * 2.1).round();
    if (location != null) status.location = location;
    if (x != null) status.x = x.clamp(0.05, 0.95);
    if (y != null) status.y = y.clamp(0.05, 0.95);

    // Update GPS coords based on offset
    status.latitude = 41.2995 + (status.y - 0.5) * 0.0006;
    status.longitude = 69.2401 + (status.x - 0.5) * 0.0006;

    if (status.x < 0.5 && status.y < 0.5) {
      status.zoneName = '🍽️ 1-Zal (Stollar 1-6)';
    } else if (status.x >= 0.5 && status.y < 0.5) {
      status.zoneName = '🍷 2-Zal (Stollar 7-12)';
    } else if (status.x < 0.5 && status.y >= 0.5) {
      status.zoneName = '💳 Kassa & Bar';
    } else {
      status.zoneName = '👨‍🍳 Oshxona';
    }

    status.lastActive = DateTime.now();
    status.isMoving = true;

    final payload = {
      'cafeId': cafeId,
      'userId': user.id,
      'userName': user.name,
      'role': user.role.name,
      'distanceMeters': status.distanceMeters,
      'steps': status.steps,
      'location': status.location,
      'zoneName': status.zoneName,
      'x': status.x,
      'y': status.y,
      'latitude': status.latitude,
      'longitude': status.longitude,
      'isMoving': true,
    };

    SocketService().emitStaffMovement(payload);
    notifyListeners();

    // 2 soniyadan so'ng harakatni tinchlantirish
    Future.delayed(const Duration(seconds: 2), () {
      status.isMoving = false;
      notifyListeners();
    });
  }

  /// Real-time live fon harakati va GPS lokatsiya simulyatori
  void startMovementSimulation(String cafeId) {
    _movementSimulationTimer?.cancel();
    _movementSimulationTimer =
        Timer.periodic(const Duration(seconds: 4), (_) {
      for (final s in _staffStatuses.values) {
        if (!s.isOnBreak && s.role == 'waiter') {
          final delta = 0.8 + (_random.nextDouble() * 2.2);
          s.distanceMeters += delta;
          s.steps += (delta * 2).round();
          s.x = (s.x + (_random.nextDouble() * 0.08 - 0.04)).clamp(0.1, 0.85);
          s.y = (s.y + (_random.nextDouble() * 0.08 - 0.04)).clamp(0.15, 0.85);

          // Real GPS koordinatalari o'zgarishi
          s.latitude = 41.2995 + (s.y - 0.5) * 0.0006;
          s.longitude = 69.2401 + (s.x - 0.5) * 0.0006;

          if (s.x < 0.5 && s.y < 0.5) {
            s.zoneName = '🍽️ 1-Zal (Stollar 1-6)';
            s.location = '1-Zal';
          } else if (s.x >= 0.5 && s.y < 0.5) {
            s.zoneName = '🍷 2-Zal (Stollar 7-12)';
            s.location = '2-Zal';
          } else if (s.x < 0.5 && s.y >= 0.5) {
            s.zoneName = '💳 Kassa & Bar';
            s.location = 'Kassa';
          } else {
            s.zoneName = '👨‍🍳 Oshxona';
            s.location = 'Oshxona';
          }

          s.lastActive = DateTime.now();
          s.isMoving = true;
        }
      }
      notifyListeners();
    });
  }

  void stopMovementSimulation() {
    _movementSimulationTimer?.cancel();
    _movementSimulationTimer = null;
  }
}
