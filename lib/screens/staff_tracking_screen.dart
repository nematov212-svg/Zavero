import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/staff_tracking_service.dart';

class StaffTrackingScreen extends StatefulWidget {
  const StaffTrackingScreen({super.key});

  @override
  State<StaffTrackingScreen> createState() => _StaffTrackingScreenState();
}

class _StaffTrackingScreenState extends State<StaffTrackingScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    StaffTrackingService().syncStaffList(appState.users);
    StaffTrackingService().startMovementSimulation(appState.currentCafeId);

    // Har soniyada vaqt o'tishini yangilab turish (dam olish vaqti taymeri)
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final tracking = StaffTrackingService();
    final allStaff = tracking.allStatuses;
    final isMobile = MediaQuery.of(context).size.width < 700;

    final onBreakCount = allStaff.where((s) => s.isOnBreak).length;
    final activeCount = allStaff.where((s) => !s.isOnBreak).length;
    final totalDistance = allStaff.fold<double>(0.0, (sum, s) => sum + s.distanceMeters);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
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
              child: const Icon(Icons.radar_rounded, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xodimlarni kuzatish',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white),
                ),
                Text(
                  'Real-time harakat, faollik va dam olish monitoringi',
                  style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w500),
                ),
              ],
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
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LivePulseDot(color: Color(0xFF10B981)),
                SizedBox(width: 6),
                Text(
                  'Jonli oqim',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
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

            // 2. Interaktiv Zallar & Radar Xaritasi
            Container(
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
                      const Icon(Icons.map_rounded, color: Color(0xFF0F172A), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Kafe va Zallar Bo\'ylab Harakat Radari',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      Text(
                        '1 metr harakat ham ko\'rinadi',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Radar Surface
                  Container(
                    height: 240,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B132B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // Grid Pattern
                          CustomPaint(
                            size: Size.infinite,
                            painter: _RadarGridPainter(),
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

                          // Staff Avatars on Map
                          ...allStaff.map((staff) {
                            return Positioned(
                              left: (staff.x * 280).clamp(20.0, 560.0),
                              top: (staff.y * 180).clamp(20.0, 190.0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Name Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: staff.isOnBreak
                                            ? const Color(0xFFEF4444)
                                            : (staff.isMoving ? const Color(0xFF10B981) : const Color(0xFFFFB300)),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (staff.isOnBreak ? Colors.red : Colors.green).withValues(alpha: 0.5),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (staff.isOnBreak)
                                            const Text('☕ ', style: TextStyle(fontSize: 10))
                                          else if (staff.isMoving)
                                            const Text('🏃 ', style: TextStyle(fontSize: 10)),
                                          Text(
                                            staff.userName,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    // Avatar circle with pulse
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: staff.isOnBreak ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (staff.isOnBreak ? Colors.red : Colors.green).withValues(alpha: 0.4),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Icon(
                                          staff.isOnBreak ? Icons.coffee_rounded : Icons.person_rounded,
                                          size: 15,
                                          color: staff.isOnBreak ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. Xodimlar Ro'yxati va Real-time Holatlari
            Row(
              children: [
                const Icon(Icons.people_alt_rounded, color: Color(0xFF0F172A), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Xodimlarning Jonli Faoliyati',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                Text(
                  '${allStaff.length} ta xodim',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (allStaff.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Text(
                    'Xodimlar hozircha ro\'yxatdan o\'tmagan',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              ...allStaff.map((staff) {
                // Bugungi savdosini hisoblash
                final staffRev = appState.receipts
                    .where((r) =>
                        r.cashierName.toLowerCase() == staff.userName.toLowerCase() &&
                        r.date.year == DateTime.now().year &&
                        r.date.month == DateTime.now().month &&
                        r.date.day == DateTime.now().day)
                    .fold<double>(0.0, (sum, r) => sum + r.total);

                final staffOrdersCount = appState.receipts
                    .where((r) =>
                        r.cashierName.toLowerCase() == staff.userName.toLowerCase() &&
                        r.date.year == DateTime.now().year &&
                        r.date.month == DateTime.now().month &&
                        r.date.day == DateTime.now().day)
                    .length;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: staff.isOnBreak
                          ? const Color(0xFFFECACA)
                          : const Color(0xFFE2E8F0),
                      width: staff.isOnBreak ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: staff.isOnBreak
                            ? Colors.red.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: staff.isOnBreak
                                    ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                    : [const Color(0xFF10B981), const Color(0xFF059669)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (staff.isOnBreak ? Colors.red : Colors.green).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                staff.isOnBreak ? Icons.coffee_rounded : Icons.person_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Name and Role
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
                                        fontSize: 16,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: staff.role == 'waiter' ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        staff.role == 'waiter' ? 'Ofitsiant' : (staff.role == 'admin' ? 'Admin' : 'Kassir'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: staff.role == 'waiter' ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_rounded, size: 13, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      staff.location,
                                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Live Break or Active Badge
                          if (staff.isOnBreak)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const _LivePulseDot(color: Color(0xFFEF4444)),
                                      const SizedBox(width: 6),
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
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          _miniStat('🚶 Masofa', '${staff.distanceMeters.toStringAsFixed(1)} metr'),
                          _miniStat('👣 Qadamlar', '${staff.steps} ta'),
                          _miniStat('👥 Mijozlar', '$staffOrdersCount ta'),
                          _miniStat('💰 Savdo', formatSum(staffRev)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
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
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
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
        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
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

class _LivePulseDotState extends State<_LivePulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
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
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), centerPaint);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
