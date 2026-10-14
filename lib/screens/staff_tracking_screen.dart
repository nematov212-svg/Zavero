import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/staff_tracking_service.dart';

class StaffTrackingScreen extends StatefulWidget {
  const StaffTrackingScreen({super.key});

  @override
  State<StaffTrackingScreen> createState() => _StaffTrackingScreenState();
}

class _StaffTrackingScreenState extends State<StaffTrackingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _refreshTimer;
  int _activeViewMode = 0; // 0: Radar, 1: GPS Xarita (Lokatsiya), 2: Ro'yxat
  StaffMemberStatus? _selectedStaff;
  late AnimationController _radarSweepCtrl;

  @override
  void initState() {
    super.initState();
    // appState global singletonini bevosita xavfsiz yuklaymiz
    StaffTrackingService().syncStaffList(appState.users);
    StaffTrackingService().startMovementSimulation(appState.currentCafeId);

    // Radar nurlari animatsiyasi
    _radarSweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Har soniyada vaqt o'tishini yangilab turish (dam olish vaqti taymeri)
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _radarSweepCtrl.dispose();
    super.dispose();
  }

  String _formatBreakDuration(DateTime? startedAt) {
    if (startedAt == null) return '0 daq';
    final diff = DateTime.now().difference(startedAt);
    final mins = diff.inMinutes;
    final secs = diff.inSeconds % 60;
    if (mins == 0) return '$secs soniya';
    return '$mins daq $secs soniya';
  }

  Future<void> _openExternalMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Xaritani ochishda xatolik: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = StaffTrackingService();
    final allStaff = tracking.allStatuses;
    final isMobile = MediaQuery.of(context).size.width < 700;

    final onBreakCount = allStaff.where((s) => s.isOnBreak).length;
    final activeCount = allStaff.where((s) => !s.isOnBreak).length;
    final totalDistance =
        allStaff.fold<double>(0.0, (sum, s) => sum + s.distanceMeters);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.radar_rounded,
                  color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xodimlarni kuzatish & Lokatsiya',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                        color: Colors.white),
                  ),
                  Text(
                    'Real-time GPS lokatsiya, radar va dam olish monitoringi',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LivePulseDot(color: Color(0xFF10B981)),
                SizedBox(width: 6),
                Text(
                  'GPS Faol',
                  style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(isMobile ? 12 : 18),
          children: [
            // 1. KPI Metrikalar
            Row(
              children: [
                Expanded(
                  child: _kpiCard(
                    title: 'Jami Xodimlar',
                    value: '${allStaff.length} nafar',
                    icon: Icons.groups_rounded,
                    color: const Color(0xFF3B82F6),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _kpiCard(
                    title: 'Faol Xizmatda',
                    value: '$activeCount nafar',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF10B981),
                    bgColor: const Color(0xFFECFDF5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _kpiCard(
                    title: 'Dam Olayotganlar',
                    value: '$onBreakCount nafar',
                    icon: Icons.coffee_rounded,
                    color: const Color(0xFFF59E0B),
                    bgColor: const Color(0xFFFFFBEB),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _kpiCard(
                      title: 'Bosib O\'tilgan',
                      value: '${totalDistance.toStringAsFixed(1)} metr',
                      icon: Icons.directions_walk_rounded,
                      color: const Color(0xFF8B5CF6),
                      bgColor: const Color(0xFFF5F3FF),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // 2. View Mode Tabs (Radar | GPS Lokatsiya | Ro'yxat)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _modeTab(0, '🎯 Kafe Ichki Radari', Icons.radar_rounded),
                  _modeTab(1, '📍 GPS Lokatsiya & Xarita', Icons.location_on_rounded),
                  _modeTab(2, '👥 Xodimlar Ro\'yxati', Icons.view_list_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Tab Contents
            if (_activeViewMode == 0)
              _buildRadarSection(allStaff)
            else if (_activeViewMode == 1)
              _buildGpsMapSection(allStaff)
            else
              _buildStaffListSection(allStaff),

            const SizedBox(height: 18),

            // 4. Live Activity Details List (Always shown at bottom for quick oversight)
            if (_activeViewMode != 2) _buildStaffListSection(allStaff),
          ],
        ),
      ),
    );
  }

  Widget _modeTab(int index, String label, IconData icon) {
    final isSel = _activeViewMode == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeViewMode = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF0F172A) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSel ? const Color(0xFFFFA000) : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TAB 1: RADAR FLOOR PLAN
  // ============================================================
  Widget _buildRadarSection(List<StaffMemberStatus> allStaff) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Row(
            children: [
              const Icon(Icons.radar_rounded,
                  color: Color(0xFF0F172A), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Kafe Zallari Bo\'ylab Harakat Radari',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    _LivePulseDot(color: Color(0xFF10B981)),
                    SizedBox(width: 5),
                    Text(
                      '1 metr harakat ko\'rinadi',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Radar Surface with LayoutBuilder
          Container(
            height: 280,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;

                  return Stack(
                    children: [
                      // Grid Pattern
                      CustomPaint(
                        size: Size(w, h),
                        painter: _RadarGridPainter(),
                      ),

                      // Rotating sweep line
                      AnimatedBuilder(
                        animation: _radarSweepCtrl,
                        builder: (context, child) {
                          return CustomPaint(
                            size: Size(w, h),
                            painter: _RadarSweepPainter(
                              angle: _radarSweepCtrl.value * 2 * math.pi,
                            ),
                          );
                        },
                      ),

                      // Hall Zones Badges
                      Positioned(
                        top: 12,
                        left: 14,
                        child: _zoneBadge('🍽️ ZAL 1 (Stollar 1-6)'),
                      ),
                      Positioned(
                        top: 12,
                        right: 14,
                        child: _zoneBadge('🍷 ZAL 2 (Stollar 7-12)'),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 14,
                        child: _zoneBadge('💳 KASSA & BAR'),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 14,
                        child: _zoneBadge('👨‍🍳 OSHXONA'),
                      ),

                      // Center Compass / Radar core
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.2),
                                width: 1),
                          ),
                        ),
                      ),

                      // Staff Avatars on Map
                      ...allStaff.map((staff) {
                        final posX = (staff.x * (w - 70)).clamp(10.0, w - 70.0);
                        final posY = (staff.y * (h - 60)).clamp(10.0, h - 60.0);

                        return Positioned(
                          left: posX,
                          top: posY,
                          child: InkWell(
                            onTap: () => setState(() => _selectedStaff = staff),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (staff.isMoving)
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF10B981)
                                                  .withValues(alpha: 0.6),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: staff.isOnBreak
                                              ? const Color(0xFFEF4444)
                                              : (staff.isMoving
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF3B82F6)),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: (staff.isOnBreak
                                                      ? const Color(0xFFEF4444)
                                                      : const Color(0xFF10B981))
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Icon(
                                            staff.isOnBreak
                                                ? Icons.coffee_rounded
                                                : Icons.person_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: staff.isOnBreak
                                            ? const Color(0xFFEF4444)
                                                .withValues(alpha: 0.5)
                                            : Colors.white24,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      staff.userName,
                                      style: TextStyle(
                                        color: staff.isOnBreak
                                            ? const Color(0xFFFCA5A5)
                                            : Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Radar Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFF10B981), 'Faol / Harakatda'),
              const SizedBox(width: 14),
              _legendDot(const Color(0xFFEF4444), 'Dam olmoqda'),
              const SizedBox(width: 14),
              _legendDot(const Color(0xFF3B82F6), 'Kassada / Tinch'),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 2: REAL GPS LOKATSIYA & XARITA
  // ============================================================
  Widget _buildGpsMapSection(List<StaffMemberStatus> allStaff) {
    return Column(
      children: [
        // Cafe Base Location Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.store_mall_directory_rounded,
                    color: Color(0xFFFFA000), size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ZAVERO Bosh Filiali Lokatsiyasi',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '📍 Toshkent shahri, Chilonzor tumani (41.2995° N, 69.2401° E)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.map_rounded, size: 16),
                label: const Text('Google Maps'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _openExternalMap(41.2995, 69.2401),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Live GPS Vector Map Container
        Container(
          height: 320,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF334155), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;

                return Stack(
                  children: [
                    // City / Street Vector Background
                    CustomPaint(
                      size: Size(w, h),
                      painter: _GpsStreetPainter(),
                    ),

                    // Cafe Perimeter Polygon
                    Positioned(
                      left: w * 0.18,
                      top: h * 0.2,
                      width: w * 0.64,
                      height: h * 0.6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFFA000).withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 8,
                              left: 10,
                              child: Text(
                                'ZAVERO RESTORAN HUDUDI',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFFA000)
                                      .withValues(alpha: 0.8),
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Staff Pins with Live Coordinates
                    ...allStaff.map((staff) {
                      final px = (staff.x * (w - 80)).clamp(20.0, w - 80.0);
                      final py = (staff.y * (h - 70)).clamp(20.0, h - 70.0);
                      final isSelected = _selectedStaff?.userId == staff.userId;

                      return Positioned(
                        left: px,
                        top: py,
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedStaff = staff);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFFA000)
                                      : (staff.isOnBreak
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF0F172A)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      staff.isOnBreak
                                          ? Icons.coffee_rounded
                                          : Icons.navigation_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      staff.userName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              CustomPaint(
                                size: const Size(10, 8),
                                painter: _PinArrowPainter(
                                  color: isSelected
                                      ? const Color(0xFFFFA000)
                                      : (staff.isOnBreak
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Top Left Indicator
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.gps_fixed_rounded,
                                color: Color(0xFF10B981), size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Sun\'iy yo\'ldosh aloqasi: 8/12 ta faol (±2.5m)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // Selected Staff Pin Card
        if (_selectedStaff != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFA000), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFA000).withValues(alpha: 0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _selectedStaff!.isOnBreak
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      _selectedStaff!.isOnBreak
                          ? Icons.coffee_rounded
                          : Icons.person_pin_circle_rounded,
                      color: _selectedStaff!.isOnBreak
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      size: 26,
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
                            _selectedStaff!.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _selectedStaff!.isOnBreak
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _selectedStaff!.isOnBreak
                                  ? 'Dam olmoqda'
                                  : 'Harakatda',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: _selectedStaff!.isOnBreak
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '📍 Hudud: ${_selectedStaff!.zoneName} · GPS: ${_selectedStaff!.latitude.toStringAsFixed(5)}, ${_selectedStaff!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Google Maps\'da ochish',
                  icon: const Icon(Icons.open_in_new_rounded,
                      color: Color(0xFF0F172A)),
                  onPressed: () => _openExternalMap(
                      _selectedStaff!.latitude, _selectedStaff!.longitude),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // TAB 3: STAFF LIST & PERFORMANCE
  // ============================================================
  Widget _buildStaffListSection(List<StaffMemberStatus> allStaff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.groups_rounded,
                color: Color(0xFF0F172A), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Xodimlarning Jonli Holati va Lokatsiyasi',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF0F172A)),
            ),
            const Spacer(),
            Text(
              'Jami ${allStaff.length} ta xodim',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ...allStaff.map((staff) {
          final now = DateTime.now();
          final sName = staff.userName.trim().toLowerCase();
          final todayReceipts = appState.receipts.where((r) {
            final cName = r.cashierName.trim().toLowerCase();
            return (cName == sName ||
                    cName == 'ofitsiant $sName' ||
                    cName.contains(sName)) &&
                r.date.year == now.year &&
                r.date.month == now.month &&
                r.date.day == now.day;
          }).toList();

          final staffOrdersCount = todayReceipts.length;
          final staffRev =
              todayReceipts.fold<double>(0.0, (sum, r) => sum + r.total).round();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: staff.isOnBreak
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFE2E8F0),
                width: staff.isOnBreak ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Upper Row: Avatar + Name + Break/Active Pill
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: staff.isOnBreak
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFEFF6FF),
                          child: Text(
                            staff.userName.isNotEmpty
                                ? staff.userName[0].toUpperCase()
                                : 'X',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: staff.isOnBreak
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: staff.isOnBreak
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                staff.userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  staff.role == 'waiter'
                                      ? 'Ofitsiant'
                                      : staff.role == 'cashier'
                                          ? 'Kassir'
                                          : 'Boshqaruvchi',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 13, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                staff.zoneName,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• Lat: ${staff.latitude.toStringAsFixed(4)}, Lng: ${staff.longitude.toStringAsFixed(4)}',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status Badge
                    if (staff.isOnBreak)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF87171)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.coffee_rounded,
                                    size: 14, color: Color(0xFFDC2626)),
                                const SizedBox(width: 4),
                                Text(
                                  '${staff.userName} dam olmoqda',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _formatBreakDuration(staff.breakStartedAt),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF6EE7B7)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LivePulseDot(color: Color(0xFF10B981)),
                            SizedBox(width: 6),
                            Text(
                              'Faol / Ishlamoqda',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Metrics Row: Distance + Steps + Today Revenue
                Row(
                  children: [
                    _miniStat('🚶 Masofa',
                        '${staff.distanceMeters.toStringAsFixed(1)} metr'),
                    _miniStat('👣 Qadamlar', '${staff.steps} ta'),
                    _miniStat('👥 Mijozlar', '$staffOrdersCount ta'),
                    _miniStat('💰 Savdo', formatSum(staffRev)),
                    IconButton(
                      tooltip: 'Xaritada ko\'rish',
                      icon: const Icon(Icons.map_rounded,
                          size: 18, color: Color(0xFF0F172A)),
                      onPressed: () {
                        setState(() {
                          _selectedStaff = staff;
                          _activeViewMode = 1;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _zoneBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LivePulseDot extends StatefulWidget {
  final Color color;
  const _LivePulseDot({required this.color});

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    // Horizontal lines
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Center dividing lines
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.2;
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), centerPaint);
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RadarSweepPainter extends CustomPainter {
  final double angle;
  _RadarSweepPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(size.width, size.height) / 1.2;

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          const Color(0xFF10B981).withValues(alpha: 0.25),
          Colors.transparent,
        ],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) =>
      oldDelegate.angle != angle;
}

class _GpsStreetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.4)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Main road horizontal
    canvas.drawLine(
        Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.4), roadPaint);
    canvas.drawLine(
        Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.4), dashPaint);

    // Cross road vertical
    canvas.drawLine(
        Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), roadPaint);
    canvas.drawLine(
        Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), dashPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PinArrowPainter extends CustomPainter {
  final Color color;
  _PinArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
