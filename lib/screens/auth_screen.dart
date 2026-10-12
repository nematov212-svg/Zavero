import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/pin_security_service.dart';
import 'blocked_screen.dart';
import 'director_screen.dart';
import 'pin_lock_screen.dart';

class AuthScreen extends StatefulWidget {
  final void Function(BuildContext context, AppUser user)? onLoginSuccess;
  const AuthScreen({super.key, this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _authService = AuthService();
  final _pinService = PinSecurityService();

  final _loginUserCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  bool _loginObscure = true;
  bool _isLoginLoading = false;
  bool _rememberMe = true;
  bool _hasPinConfigured = false;
  String? _loginError;

  late AnimationController _ringController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkPinConfig();

    // 1. Slow orbital ring rotation
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // 2. Soft breathing pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    // 3. Staggered entrance
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
  }

  Future<void> _checkPinConfig() async {
    final hasPin = await _pinService.hasAnyPin();
    if (mounted) setState(() => _hasPinConfigured = hasPin);
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('saved_quick_login_user');
      final savedPass = prefs.getString('saved_quick_login_pass');
      if (savedUser != null && savedUser.isNotEmpty) {
        setState(() {
          _loginUserCtrl.text = savedUser;
          if (savedPass != null && savedPass.isNotEmpty) {
            _loginPassCtrl.text = savedPass;
          }
        });
      }
    } catch (_) {}
  }

  void _goToPinLock() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PinLockScreen()),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: const Color(0xFFFFB300).withValues(alpha: 0.4), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFFFB300), size: 36),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Parolni unutdingizmi?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Xavfsizlik talablariga muvofiq, parolni qayta tiklash uchun kafe ma\'muri (Admin) yoki ZAVERO boshqaruvchisi (Director) bilan bog\'laning.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tushunarli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _loginUserCtrl.dispose();
    _loginPassCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIN SUBMIT (KIRISH)
  // ============================================================
  Future<void> _submitLogin() async {
    final login = _loginUserCtrl.text.trim();
    final pass = _loginPassCtrl.text.trim();

    if (login.isEmpty) {
      setState(() => _loginError = 'Iltimos, foydalanuvchi nomini kiriting.');
      return;
    }
    if (pass.isEmpty) {
      setState(() => _loginError = 'Iltimos, parolni kiriting.');
      return;
    }

    setState(() {
      _isLoginLoading = true;
      _loginError = null;
    });

    try {
      final user = await _authService.login(login, pass);

      if (!mounted) return;

      // Save user session in AppState
      await appState.saveUserSession(user);

      // Save credentials if Remember Me is checked
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('saved_quick_login_user', login);
          await prefs.setString('saved_quick_login_pass', pass);
        } else {
          await prefs.remove('saved_quick_login_user');
          await prefs.remove('saved_quick_login_pass');
        }
      } catch (_) {}

      if (!mounted) return;

      // Role Routing:
      if (user.role == UserRole.director) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'director'),
            builder: (_) => DirectorScreen(directorUser: user),
          ),
          (r) => false,
        );
        return;
      }

      if (user.isBlocked || user.isExpired) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'blocked'),
            builder: (_) => BlockedScreen(user: user),
          ),
          (r) => false,
        );
        return;
      }

      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!(context, user);
        return;
      }

      try {
        await appState.loadCloudDataForCafe(user.workspaceId);
      } catch (e) {
        debugPrint('Cafe ma\'lumotlarini yuklashda xatolik: $e');
      }
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'dashboard'),
          builder: (_) => const DashboardScreen(),
        ),
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final rawMsg = e.toString().replaceAll('Exception: ', '');
        if (rawMsg.contains('xato') || rawMsg.contains('Noto\'g\'ri') || rawMsg.contains('401')) {
          _loginError = 'Login yoki parol xato. Iltimos, qaytadan tekshiring.';
        } else {
          _loginError = rawMsg;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoginLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 1120;
    final isTablet = screenSize.width >= 768 && screenSize.width < 1120;

    return Scaffold(
      backgroundColor: const Color(0xFF080D16),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Deep Atmospheric Dark Background with Radial Bokeh Glows
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.3),
                  radius: 1.3,
                  colors: [
                    Color(0xFF111A2B),
                    Color(0xFF090F1A),
                    Color(0xFF060911),
                  ],
                ),
              ),
            ),
          ),

          // Warm Cafe Golden Glows (Top Left & Center Ambient Aura)
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 480,
              height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFB300).withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -100,
            child: Container(
              width: 520,
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF9100).withValues(alpha: 0.07),
              ),
            ),
          ),

          // Ambient Golden Arcs / Rings
          Positioned(
            bottom: -80,
            left: -80,
            child: SizedBox(
              width: 320,
              height: 320,
              child: CustomPaint(
                painter: _GoldenRingPainter(opacity: 0.25),
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -60,
            child: SizedBox(
              width: 340,
              height: 340,
              child: CustomPaint(
                painter: _GoldenRingPainter(opacity: 0.20),
              ),
            ),
          ),

          // 2. Animated Main Content (Desktop 3-Column / Tablet / Mobile)
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 36 : 20,
                  vertical: isDesktop ? 24 : 16,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: isDesktop
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left Brand Column
                              Expanded(
                                flex: 3,
                                child: _buildLeftBrandColumn(),
                              ),
                              const SizedBox(width: 32),

                              // Center Glassmorphic Login Card
                              SizedBox(
                                width: 440,
                                child: _buildGlassLoginCard(),
                              ),
                              const SizedBox(width: 32),

                              // Right Features Column
                              Expanded(
                                flex: 3,
                                child: _buildRightFeaturesColumn(),
                              ),
                            ],
                          )
                        : (isTablet
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: _buildLeftBrandColumn(compact: true),
                                  ),
                                  const SizedBox(width: 28),
                                  SizedBox(
                                    width: 420,
                                    child: _buildGlassLoginCard(),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildMobileHeader(),
                                  const SizedBox(height: 18),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 440),
                                    child: _buildGlassLoginCard(),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildMobileFeatureChips(),
                                ],
                              )),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LEFT BRAND COLUMN (Desktop / Tablet)
  // ============================================================
  Widget _buildLeftBrandColumn({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand Badge: [☕] ZAVERO Cafe Automation System
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2010), Color(0xFF1A1308)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.7), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.coffee_rounded, color: Color(0xFFFFB300), size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ZAVERO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  'Cafe Automation System',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 38),

        // Catchy Headline
        Text(
          'Kafeningiz uchun',
          style: TextStyle(
            color: const Color(0xFFFFE082),
            fontSize: compact ? 22 : 28,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),

        RichText(
          text: TextSpan(
            text: 'Aqlli ',
            style: TextStyle(
              fontSize: compact ? 38 : 48,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
            children: const [
              TextSpan(
                text: 'Yechim',
                style: TextStyle(
                  color: Color(0xFFFFB300),
                  shadows: [
                    Shadow(color: Color(0x66FFB300), blurRadius: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            'Zavero – kafelar, restoranlar va ovqatlanish maskanlari uchun zamonaviy avtomatlashtirish tizimi.',
            style: TextStyle(
              color: const Color(0xFF94A3B8),
              fontSize: compact ? 13 : 14.5,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // 3 Feature Badges: ⚡ Tezkor | 🛡 Ishonchli | 📊 Biznes nazorati
        Wrap(
          spacing: 16,
          runSpacing: 14,
          children: [
            _buildLeftPillBadge(Icons.bolt_rounded, 'Tezkor', 'Boshqaruv'),
            _buildLeftPillBadge(Icons.shield_outlined, 'Ishonchli', 'Tizim'),
            _buildLeftPillBadge(Icons.trending_up_rounded, 'Sizning', 'Biznesingiz uchun'),
          ],
        ),
        const SizedBox(height: 42),

        // Golden Script Quote
        Transform.rotate(
          angle: -0.05,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.3)),
            ),
            child: const Text(
              'Kafe biznesini osonlashtiramiz!',
              style: TextStyle(
                color: Color(0xFFFFCA28),
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeftPillBadge(IconData icon, String top, String bottom) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2F).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFFFB300), size: 24),
          const SizedBox(height: 8),
          Text(
            top,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            bottom,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 10.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RIGHT FEATURES COLUMN (Desktop)
  // ============================================================
  Widget _buildRightFeaturesColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRightFeatureCard(
          icon: Icons.restaurant_rounded,
          title: 'Buyurtmalar',
          subtitle: 'Mijoz buyurtmalarini oson boshqaring',
        ),
        const SizedBox(height: 14),
        _buildRightFeatureCard(
          icon: Icons.qr_code_2_rounded,
          title: 'QR Menu',
          subtitle: 'Menyu QR orqali mijozlarga',
        ),
        const SizedBox(height: 14),
        _buildRightFeatureCard(
          icon: Icons.groups_rounded,
          title: 'Xodimlar',
          subtitle: 'Jamoangizni boshqaring',
        ),
        const SizedBox(height: 14),
        _buildRightFeatureCard(
          icon: Icons.insert_chart_rounded,
          title: 'Hisobotlar',
          subtitle: 'Daromad va savdo tahlili',
        ),
        const SizedBox(height: 14),
        _buildRightFeatureCard(
          icon: Icons.settings_rounded,
          title: 'Sozlamalar',
          subtitle: 'Kafengizni moslashtiring',
        ),
      ],
    );
  }

  Widget _buildRightFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF1E293B).withValues(alpha: 0.8),
              border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: const Color(0xFFFFB300), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CENTER GLASSMORPHIC LOGIN CARD
  // ============================================================
  Widget _buildGlassLoginCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1728).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFFFB300).withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: const Color(0xFFFFB300).withValues(alpha: 0.16),
                blurRadius: 36,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Animated ZAVERO Glowing Coffee Cup + Rotating Ring Emblem
              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_ringController, _pulseController]),
                  builder: (context, child) {
                    final pulse = 1.0 + (_pulseController.value * 0.06);
                    return SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rotating Glowing Golden Orbital Ring
                          Transform.rotate(
                            angle: _ringController.value * 2 * math.pi,
                            child: CustomPaint(
                              size: const Size(120, 120),
                              painter: _OrbitalRingPainter(),
                            ),
                          ),

                          // Central 3D Glowing Coffee Cup Tile
                          Transform.scale(
                            scale: pulse,
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: const RadialGradient(
                                  colors: [Color(0xFF2E2211), Color(0xFF130E07)],
                                  center: Alignment(0, -0.2),
                                  radius: 0.9,
                                ),
                                border: Border.all(
                                  color: const Color(0xFFFFD54F),
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFB300).withValues(alpha: 0.55),
                                    blurRadius: 24,
                                    spreadRadius: 3,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Golden Coffee Cup Icon
                                    const Icon(
                                      Icons.local_cafe_rounded,
                                      color: Color(0xFFFFCA28),
                                      size: 38,
                                    ),
                                    // Tiny "Z" mark on the cup
                                    Positioned(
                                      bottom: 25,
                                      child: Text(
                                        'Z',
                                        style: TextStyle(
                                          color: Colors.black.withValues(alpha: 0.85),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Title "ZAVERO"
              const Center(
                child: Text(
                  'ZAVERO',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Subtitle
              Center(
                child: Text(
                  'Restoran va Kafe Savdo Tizimi',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section Label: Tizimga kirish
              const Row(
                children: [
                  Icon(Icons.person_pin_rounded, color: Color(0xFFFFB300), size: 18),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tizimga kirish',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'O\'z hisobingiz bilan davom eting',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Error Banner
              if (_loginError != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loginError!,
                          style: const TextStyle(
                            color: Color(0xFFFECACA),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Input 1: Foydalanuvchi nomi
              TextField(
                controller: _loginUserCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Foydalanuvchi nomi',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.32)),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.white60, size: 20),
                  filled: true,
                  fillColor: const Color(0xFF090F1A).withValues(alpha: 0.9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Input 2: Parol
              TextField(
                controller: _loginPassCtrl,
                obscureText: _loginObscure,
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitLogin(),
                decoration: InputDecoration(
                  hintText: 'Parol',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.32)),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white60, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _loginObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.white60,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _loginObscure = !_loginObscure),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF090F1A).withValues(alpha: 0.9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Remember Me & Forgot Password Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: const Color(0xFFFFB300),
                              checkColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) => setState(() => _rememberMe = val ?? true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Meni eslab qol',
                            style: TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFFCA28),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    ),
                    onPressed: _showForgotPasswordDialog,
                    child: const Text(
                      'Parolni unutdingizmi?',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Glowing Submit Button "→ Tizimga kirish"
              Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9100), Color(0xFFFFC107)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoginLoading ? null : _submitLogin,
                  child: _isLoginLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Tizimga kirish',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // PIN Code button if enabled
              if (_hasPinConfigured) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFB300),
                    side: BorderSide(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _goToPinLock,
                  icon: const Icon(Icons.dialpad_rounded, size: 16),
                  label: const Text('PIN kod orqali kirish', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ],

              const SizedBox(height: 20),

              // Divider "Zavero"
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Zavero',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
                ],
              ),
              const SizedBox(height: 12),

              // Security Guarantee Footer Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFFFFB300), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Sizning ma\'lumotlaringiz xavfsiz',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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

  // ============================================================
  // MOBILE HEADER & CHIPS
  // ============================================================
  Widget _buildMobileHeader() {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF2A2010), Color(0xFF1A1308)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.coffee_rounded, color: Color(0xFFFFB300), size: 28),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'ZAVERO',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Restoran va Kafe Savdo Tizimi',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  Widget _buildMobileFeatureChips() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _mobileChip(Icons.restaurant_rounded, 'Buyurtmalar'),
        _mobileChip(Icons.qr_code_2_rounded, 'QR Menu'),
        _mobileChip(Icons.groups_rounded, 'Xodimlar'),
        _mobileChip(Icons.insert_chart_rounded, 'Hisobotlar'),
      ],
    );
  }

  Widget _mobileChip(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFFB300), size: 14),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        ],
      ),
    );
  }
}

// ============================================================
// CUSTOM PAINTERS (ORBITAL RING & GOLDEN BACKGROUND ARCS)
// ============================================================
class _OrbitalRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radiusX = size.width * 0.46;
    final radiusY = size.height * 0.22;

    final paint = Paint()
      ..color = const Color(0xFFFFCA28).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Tilted ellipse
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.35);

    final rect = Rect.fromCenter(center: Offset.zero, width: radiusX * 2, height: radiusY * 2);
    canvas.drawOval(rect, paint);

    // Glowing spark dot on the orbit
    final sparkPaint = Paint()
      ..color = const Color(0xFFFFF9C4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
    canvas.drawCircle(Offset(radiusX, 0), 3.0, sparkPaint);
    canvas.drawCircle(Offset(-radiusX * 0.8, -radiusY * 0.6), 2.0, sparkPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GoldenRingPainter extends CustomPainter {
  final double opacity;
  _GoldenRingPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawCircle(center, size.width * 0.45, paint);
    canvas.drawCircle(center, size.width * 0.35, paint..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
