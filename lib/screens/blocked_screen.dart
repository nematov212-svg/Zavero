import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import 'auth_screen.dart';

class BlockedScreen extends StatefulWidget {
  final AppUser user;
  const BlockedScreen({super.key, required this.user});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  bool _isChecking = false;
  bool _isRequestingSub = false;
  String? _message;
  StreamSubscription? _subExtSub;

  @override
  void initState() {
    super.initState();
    final cafeId = widget.user.workspaceId;
    if (cafeId.isNotEmpty) {
      SocketService().connect(cafeId: cafeId);
      _subExtSub = SocketService().on(CafeSocketEvent.subscriptionExtended).listen((data) {
        if (mounted) {
          _checkStatus();
        }
      });
    }
  }

  @override
  void dispose() {
    _subExtSub?.cancel();
    super.dispose();
  }

  Future<void> _request30Days() async {
    setState(() {
      _isRequestingSub = true;
      _message = null;
    });
    try {
      final cafeTitle = widget.user.cafeName.isNotEmpty
          ? widget.user.cafeName
          : (widget.user.cafeId.isNotEmpty ? widget.user.cafeId : 'ZAVERO Cafe');
      final res = await ApiClient().post('/subscription/request-30days', body: {
        'cafeName': cafeTitle,
        'currentEndDate': widget.user.cafeEndDate?.toIso8601String(),
      });
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _message = "✅ 30 kunlik obuna so'rovi adminga yuborildi!\nAdmin tasdiqlashi bilan tizim avtomatik ochiladi.";
        });
      } else {
        setState(() {
          _message = res['message'] ?? "So'rov yuborishda xatolik yuz berdi.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = "So'rov yuborishda xatolik: $e";
      });
    } finally {
      if (mounted) setState(() => _isRequestingSub = false);
    }
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });

    try {
      final updatedUser = await AuthService().getCurrentUserDetails();
      if (!mounted) return;

      if (updatedUser != null && !updatedUser.isBlocked && !updatedUser.isExpired) {
        await appState.saveUserSession(updatedUser);
        await appState.loadCloudDataForCafe(updatedUser.workspaceId);
        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'dashboard'),
            builder: (_) => const DashboardScreen(),
          ),
          (r) => false,
        );
      } else {
        setState(() {
          _message = "Hozircha faollashtirilmadi. Iltimos, administrator bilan bog'laning.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = "Holatni tekshirishda xatolik: $e";
      });
    } finally {
      if (mounted) setState(() => _isChecking = false);
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

  @override
  Widget build(BuildContext context) {
    final cafeTitle = widget.user.cafeName.isNotEmpty
        ? widget.user.cafeName
        : (widget.user.cafeId.isNotEmpty ? widget.user.cafeId : 'ZAVERO Cafe');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Sleek Slate 900
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 16,
                color: const Color(0xFF1E293B), // Slate 800
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Lock Icon with glowing background
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_person_rounded,
                          size: 46,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Platform Name
                      const Text(
                        'ZAVERO',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Color(0xFFFFC107),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Main Error Title
                      const Text(
                        "Kirish to'xtatilgan",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Strict required wording
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          "Xizmat muddati tugagan yoki to'xtatilgan. Iltimos, administrator bilan bog'laning.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFECACA), // Red 200
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Cafe Details card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow('Kafe nomi:', cafeTitle),
                            const Divider(color: Colors.white12, height: 16),
                            _buildInfoRow('Foydalanuvchi:', widget.user.name.isNotEmpty ? widget.user.name : widget.user.username),
                            const Divider(color: Colors.white12, height: 16),
                            _buildInfoRow(
                              'Holati:',
                              widget.user.isBlocked ? 'Bloklangan' : "Obuna muddati tugagan",
                              color: Colors.redAccent,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_message != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Colors.amber),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF315EFB),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isRequestingSub ? null : _request30Days,
                          icon: _isRequestingSub
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.rocket_launch_rounded),
                          label: Text(
                            _isRequestingSub ? "So'rov yuborilmoqda..." : "30 kunlik obuna so'rash",
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC107),
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isChecking ? null : _checkStatus,
                          icon: _isChecking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(
                            _isChecking ? 'Tekshirilmoqda...' : 'Qaytadan tekshirish',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade400,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Hisobdan chiqish'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
