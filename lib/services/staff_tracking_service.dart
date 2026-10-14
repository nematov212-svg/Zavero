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

  StaffMemberStatus({
    required this.userId,
    required this.userName,
    required this.role,
    this.isOnBreak = false,
    this.breakStartedAt,
    this.statusText = 'Faol / Ishlamoqda',
    this.location = 'Zal 1',
    this.distanceMeters = 0.0,
    this.steps = 0,
    DateTime? lastActive,
    this.isMoving = false,
    this.x = 0.3,
    this.y = 0.4,
  }) : lastActive = lastActive ?? DateTime.now();

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
      location: j['location'] as String? ?? 'Zal 1',
      distanceMeters: (j['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      steps: (j['steps'] as num?)?.toInt() ?? 0,
      lastActive: j['lastActive'] != null
          ? DateTime.tryParse(j['lastActive'])
          : DateTime.now(),
      isMoving: j['isMoving'] == true,
      x: (j['x'] as num?)?.toDouble() ?? 0.3,
      y: (j['y'] as num?)?.toDouble() ?? 0.4,
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
          location: data['location'] as String? ?? 'Zal 1',
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
        existing.isMoving = data['isMoving'] == true;
        existing.lastActive = DateTime.now();
        notifyListeners();
      }
    });
  }

  /// Xodimlar ro'yxatini yuklash va boshlang'ich holatni sozlash
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
          location: isWait ? 'Zal 1 · Stollar' : 'Asosiy Kassa',
          distanceMeters: 45.0 + (_random.nextInt(60)),
          steps: 90 + (_random.nextInt(120)),
          x: 0.2 + (_random.nextDouble() * 0.6),
          y: 0.2 + (_random.nextDouble() * 0.6),
        );
      }
    }
    notifyListeners();
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

    final payload = {
      'cafeId': cafeId,
      'userId': user.id,
      'userName': user.name,
      'role': user.role.name,
      'isOnBreak': isOnBreak,
      'breakStartedAt': status.breakStartedAt?.toIso8601String(),
      'statusText': status.statusText,
      'location': isOnBreak ? 'Dam olish xonasi' : status.location,
      'distanceMeters': status.distanceMeters,
      'steps': status.steps,
      'x': status.x,
      'y': status.y,
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
      'x': status.x,
      'y': status.y,
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

  /// Real-time live fon harakati simulyatori
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
