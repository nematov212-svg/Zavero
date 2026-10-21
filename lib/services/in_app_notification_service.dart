import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'sound_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appMessengerKey = GlobalKey<ScaffoldMessengerState>();

class InAppNotificationService {
  static final InAppNotificationService _instance = InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal();

  OverlayEntry? _currentEntry;
  Timer? _dismissTimer;

  void showNewOrderNotification({
    required CustomerOrder order,
    required VoidCallback onViewOrder,
    VoidCallback? onAcceptOrder,
  }) {
    // 1. Har doim bildirishnoma qo'ng'irog'i ("Ting!" ovozi) yangraydi
    try {
      SoundService().playTing('qr_order');
    } catch (_) {}

    // 2. Agar Sozlamalarda ovozli gapirish yoqilgan bo'lsa, gapirib e'lon qiladi
    try {
      SoundService().announceNewOrder(order: order, repeatIntervalSec: 6);
    } catch (_) {}

    final overlayState = appNavigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final tableText = order.tableNumber != null && order.tableNumber! > 0
        ? '${order.tableNumber}-stol'
        : (order.deliveryAddress ?? 'Mijoz');
    final customerName = order.customerName.trim().isNotEmpty &&
            order.customerName.trim().toLowerCase() != 'mehmon'
        ? order.customerName.trim()
        : null;

    final titleRef = customerName != null ? '$tableText ($customerName)' : tableText;
    final itemsSummary = order.items.map((e) => '${e.qty}x ${e.product.name}').take(2).join(', ');
    final remainingCount = order.items.length > 2 ? ' +${order.items.length - 2}' : '';

    final entry = OverlayEntry(
      builder: (context) => _AnimatedNotificationBanner(
        title: '№${order.id} • $titleRef',
        subtitle: itemsSummary + remainingCount,
        totalSum: '${order.total.toStringAsFixed(0)} so‘m',
        onAccept: () {
          _dismissTimer?.cancel();
          _currentEntry?.remove();
          _currentEntry = null;
          SoundService().stopOrderVoice(order.id);
          if (onAcceptOrder != null) {
            onAcceptOrder();
          }
        },
        onView: () {
          _dismissTimer?.cancel();
          _currentEntry?.remove();
          _currentEntry = null;
          onViewOrder();
        },
        onDismiss: () {
          _dismissTimer?.cancel();
          _currentEntry?.remove();
          _currentEntry = null;
          SoundService().stopOrderVoice(order.id);
        },
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    // Auto-dismiss banner visually after 30s if untouched
    _dismissTimer = Timer(const Duration(seconds: 30), () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }
}

class _AnimatedNotificationBanner extends StatefulWidget {
  final String title;
  final String subtitle;
  final String totalSum;
  final VoidCallback onAccept;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  const _AnimatedNotificationBanner({
    required this.title,
    required this.subtitle,
    required this.totalSum,
    required this.onAccept,
    required this.onView,
    required this.onDismiss,
  });

  @override
  State<_AnimatedNotificationBanner> createState() => _AnimatedNotificationBannerState();
}

class _AnimatedNotificationBannerState extends State<_AnimatedNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _offsetAnim = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close(VoidCallback callback) async {
    await _ctrl.reverse();
    callback();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _offsetAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Bell Icon with glowing badge and red dot - Image 5
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.notifications_active_rounded, color: Color(0xFFB45309), size: 22),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Order Details
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _close(widget.onView),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.totalSum} • ${widget.subtitle}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Green Button [✓ Zakasni olish] - Image 5
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: () => _close(widget.onAccept),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text(
                      'Zakasni olish',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 2),

                  // Close icon (✕)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
                    onPressed: () => _close(widget.onDismiss),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    tooltip: 'Yopish',
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
