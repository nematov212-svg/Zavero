import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/api_client.dart';
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

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _pinService = PinSecurityService();

  final _loginUserCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  bool _loginObscure = true;
  bool _isLoginLoading = false;
  bool _rememberMe = true;
  bool _hasPinConfigured = false;
  String? _loginError;
  bool _isOfflineMode = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Design color palette matching Image 1
  static const Color _bgCream = Color(0xFFF9F6F0);
  static const Color _cardBg = Colors.white;
  static const Color _peachPrimary = Color(0xFFF5CEB3);
  static const Color _peachDark = Color(0xFFE8B696);
  static const Color _peachLight = Color(0xFFFDEEE5);
  static const Color _textDark = Color(0xFF1E2432);
  static const Color _textMuted = Color(0xFF7A8293);
  static const Color _inputBorder = Color(0xFFE5E7EB);
  static const Color _inputBorderFocused = Color(0xFFE8B696);

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkPinConfig();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
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
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 20,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _peachLight,
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: _peachDark, size: 36),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Parolni unutdingizmi?',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Xavfsizlik talablariga muvofiq, parolni qayta tiklash uchun kafe ma\'muri (Admin) yoki ZAVERO boshqaruvchisi (Director) bilan bog\'laning.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textMuted, fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _peachPrimary,
                      foregroundColor: _textDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
    _fadeController.dispose();
    _loginUserCtrl.dispose();
    _loginPassCtrl.dispose();
    super.dispose();
  }

  void _toggleOfflineMode() {
    setState(() {
      _isOfflineMode = !_isOfflineMode;
      _loginError = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isOfflineMode ? Icons.offline_bolt_rounded : Icons.wifi_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isOfflineMode
                    ? 'Oflayn rejim faol! O‘zingizning login va parolingizni kiritib kiring.'
                    : 'Onlayn rejimga qaytildi.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: _isOfflineMode ? const Color(0xFFD97706) : const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submitLogin() async {
    final login = _loginUserCtrl.text.trim();
    final pass = _loginPassCtrl.text.trim();

    if (login.isEmpty) {
      setState(() => _loginError = 'Iltimos, foydalanuvchi nomini yoki emailni kiriting.');
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

    // 1. Agar foydalanuvchi "Oflayn rejim"ni yoqqan bo'lsa, to'g'ridan-to'g'ri oflayn tekshiramiz:
    if (_isOfflineMode) {
      await _performOfflineLogin(login, pass);
      if (mounted) setState(() => _isLoginLoading = false);
      return;
    }

    // 2. Aks holda oddiy online rejimda server orqali kirishga harakat qilamiz:
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

      if (user.role == UserRole.waiter) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'dashboard'),
            builder: (_) => const DashboardScreen(),
          ),
          (r) => false,
        );
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'dashboard'),
          builder: (_) => const DashboardScreen(),
        ),
        (r) => false,
      );
    } catch (e) {
      // 3. Agar serverga ulanishda tarmoq xatosi bo'lsa (internet uzilgan), avtomatik oflayn tekshiramiz:
      final isNetworkIssue = e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('failed host lookup') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('connection') ||
          e.toString().toLowerCase().contains('clientexception') ||
          e.toString().toLowerCase().contains('timeout');

      if (isNetworkIssue) {
        await _performOfflineLogin(login, pass);
        if (mounted) setState(() => _isLoginLoading = false);
        return;
      }

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

  /// Oflayn tizim orqali tekshirish va xodimni o'zining tegishli paneliga yo'naltirish
  Future<void> _performOfflineLogin(String login, String pass) async {
    final offlineUser = await _resolveOfflineUser(login, pass);
    if (offlineUser == null) {
      if (!mounted) return;
      setState(() {
        _loginError = 'Login yoki parol xato. Iltimos, qaytadan tekshiring.';
      });
      return;
    }

    if (!mounted) return;
    await appState.saveUserSession(offlineUser);
    try {
      await appState.loadCloudDataForCafe(offlineUser.workspaceId);
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Oflayn rejim: Kassa lokal ma’lumotlar bilan ishga tushdi (${offlineUser.name}).',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF59E0B),
        duration: const Duration(seconds: 4),
      ),
    );

    // Xodim o'zining roliga mos paneliga kiradi:
    if (offlineUser.role == UserRole.director) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'director'),
          builder: (_) => DirectorScreen(directorUser: offlineUser),
        ),
        (r) => false,
      );
      return;
    }

    if (offlineUser.role == UserRole.waiter) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'dashboard'),
          builder: (_) => const DashboardScreen(),
        ),
        (r) => false,
      );
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'dashboard'),
        builder: (_) => const DashboardScreen(),
      ),
      (r) => false,
    );
  }

  /// Oflayn foydalanuvchini aniqlash (Lokal baza, Kesh yoki Default Admin)
  Future<AppUser?> _resolveOfflineUser(String login, String pass) async {
    final cleanL = login.trim().toLowerCase();
    final cleanP = pass.trim();

    if (cleanL.isEmpty || cleanP.isEmpty) return null;

    // 1. Lokal xodimlar ro'yxatidan qidirish
    final localUser = appState.loginByCredentials(cleanL, cleanP);
    if (localUser != null) return localUser;

    // 2. Keshdagi oxirgi sessiyani tekshirish
    try {
      final cachedJson = await ApiClient().readCachedUserJson();
      if (cachedJson != null) {
        final uName = (cachedJson['username'] ?? '').toString().toLowerCase();
        final uEmail = (cachedJson['email'] ?? '').toString().toLowerCase();
        if (uName == cleanL || uEmail == cleanL) {
          final prefs = await SharedPreferences.getInstance();
          final savedPass = prefs.getString('saved_quick_login_pass') ?? '';
          if (savedPass.isEmpty || savedPass == cleanP) {
            return AppUser.fromJson(cachedJson);
          }
        }
      }
    } catch (_) {}

    // 3. Standart ma'murlar va xodimlar parollari
    if (cleanL == 'admin' &&
        (cleanP == '123456' || cleanP == 'admin' || cleanP == 'admin1' || cleanP == 'zavero2026')) {
      return AppUser(
        id: 1,
        uid: 'admin',
        name: 'Administrator',
        surname: '',
        username: 'admin',
        email: 'admin@zavero.pos',
        phone: '',
        password: '',
        role: UserRole.admin,
        ownerId: 'local_default',
        cafeId: 'cafe1',
      );
    }

    if (cleanL == 'kassir' && (cleanP == '123456' || cleanP == 'kassir123' || cleanP == 'kassir')) {
      return AppUser(
        id: 2,
        uid: 'kassir',
        name: 'Kassir',
        surname: '',
        username: 'kassir',
        email: 'kassir@zavero.pos',
        phone: '',
        password: '',
        role: UserRole.cashier,
        ownerId: 'local_default',
        cafeId: 'cafe1',
      );
    }

    if (cleanL == 'ofitsiant' && (cleanP == '123456' || cleanP == 'ofitsiant' || cleanP == 'waiter')) {
      return AppUser(
        id: 3,
        uid: 'ofitsiant',
        name: 'Ofitsiant',
        surname: '',
        username: 'ofitsiant',
        email: 'ofitsiant@zavero.pos',
        phone: '',
        password: '',
        role: UserRole.waiter,
        ownerId: 'local_default',
        cafeId: 'cafe1',
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktopOrTablet = screenSize.width >= 820;

    return Scaffold(
      backgroundColor: _bgCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktopOrTablet ? 32 : 20,
              vertical: isDesktopOrTablet ? 32 : 16,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: isDesktopOrTablet
                    ? _buildDesktopLayout(screenSize)
                    : _buildMobileLayout(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP & TABLET LAYOUT (Two-column Split Card) - Image 1 Left
  // ============================================================
  Widget _buildDesktopLayout(Size screenSize) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 960),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E2432).withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: _peachPrimary.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Column: Form & Inputs
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 48),
                child: _buildLoginForm(isMobile: false),
              ),
            ),

            // Right Column: Character with Peach Arch Backdrop - Image 1 Right
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildCharacterArch(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE LAYOUT (Vertical Stack) - Image 1 Mobile Mockup
  // ============================================================
  Widget _buildMobileLayout() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E2432).withValues(alpha: 0.05),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Circular Badge with 3D Character
          _buildMobileCharacterBadge(),
          const SizedBox(height: 20),

          // Form fields & Buttons
          _buildLoginForm(isMobile: true),
        ],
      ),
    );
  }

  // ============================================================
  // CHARACTER ARCH (Desktop Right Half)
  // ============================================================
  Widget _buildCharacterArch() {
    return Container(
      decoration: const BoxDecoration(
        color: _peachLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(180),
          topRight: Radius.circular(180),
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Subtle soft inner glow
          Positioned(
            top: 40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _peachPrimary.withValues(alpha: 0.35),
              ),
            ),
          ),

          // 3D Character Illustration
          Padding(
            padding: const EdgeInsets.only(top: 36, bottom: 12, left: 16, right: 16),
            child: Image.asset(
              'assets/images/login_character.png',
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => const Center(
                child: Icon(Icons.person_rounded, size: 100, color: _peachDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE CHARACTER CIRCLE BADGE
  // ============================================================
  Widget _buildMobileCharacterBadge() {
    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: _peachLight,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _peachDark.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Image.asset(
            'assets/images/login_character.png',
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => const Center(
              child: Icon(Icons.person_rounded, size: 64, color: _peachDark),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGIN FORM (Welcome Back! + Email + Password + Login Pill Button)
  // ============================================================
  Widget _buildLoginForm({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Heading "Welcome Back!"
        Text(
          'Welcome Back!',
          style: TextStyle(
            color: _textDark,
            fontSize: isMobile ? 26 : 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'ZAVERO tizimiga kirish uchun ma\'lumotlaringizni kiriting',
          style: TextStyle(
            color: _textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 24),

        // Error message banner if any
        if (_loginError != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _loginError!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Oflayn rejim faol bo'lsa ogohlantirish banneri
        if (_isOfflineMode) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFBBF24)),
            ),
            child: const Row(
              children: [
                Icon(Icons.offline_bolt_rounded, color: Color(0xFFD97706), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Oflayn rejim faol',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'O‘z login va parolingizni kiritib kiring. Har bir xodim o‘z paneliga yo‘naltiriladi.',
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Input 1: Email / Foydalanuvchi nomi
        _buildPillInputField(
          controller: _loginUserCtrl,
          label: 'Email',
          hint: 'example@zavero.uz',
          icon: Icons.alternate_email_rounded,
          isPassword: false,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 18),

        // Input 2: Password
        _buildPillInputField(
          controller: _loginPassCtrl,
          label: 'Password',
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscureText: _loginObscure,
          onToggleObscure: () => setState(() => _loginObscure = !_loginObscure),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitLogin(),
        ),
        const SizedBox(height: 12),

        // Remember Me & Forgot Password Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
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
                        activeColor: _peachDark,
                        checkColor: Colors.white,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        onChanged: (val) => setState(() => _rememberMe = val ?? true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Meni eslab qol',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: _textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              ),
              onPressed: _showForgotPasswordDialog,
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Peach Pill "Login" Button - Image 1
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _peachPrimary,
              foregroundColor: _textDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            onPressed: _isLoginLoading ? null : _submitLogin,
            child: _isLoginLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: _textDark),
                  )
                : Text(
                    _isOfflineMode ? 'Oflayn tizimga kirish' : 'Login',
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),

        // PIN Login Option if configured
        if (_hasPinConfigured) ...[
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: _textDark,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: _goToPinLock,
              icon: const Icon(Icons.dialpad_rounded, size: 18),
              label: const Text(
                'PIN kod orqali kirish',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),
        // Oflayn rejim almashtirish tugmasi (Avtomatik kirmaydi, rejimni yoqadi)
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: _isOfflineMode ? const Color(0xFF065F46) : const Color(0xFF92400E),
              backgroundColor: _isOfflineMode ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: _isOfflineMode ? const Color(0xFF10B981) : const Color(0xFFFBBF24),
                  width: 1.2,
                ),
              ),
            ),
            onPressed: _isLoginLoading ? null : _toggleOfflineMode,
            icon: Icon(
              _isOfflineMode ? Icons.check_circle_rounded : Icons.offline_bolt_rounded,
              size: 17,
              color: _isOfflineMode ? const Color(0xFF059669) : const Color(0xFFD97706),
            ),
            label: Text(
              _isOfflineMode ? 'Oflayn rejim faol (Onlaynga o‘tish)' : 'Oflayn rejimga o‘tish (Internetsiz)',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Footer brand mark
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/logo/logo_transparent.png',
                width: 16,
                height: 16,
                errorBuilder: (c, e, s) => const SizedBox.shrink(),
              ),
              const SizedBox(width: 6),
              const Text(
                'ZAVERO • Restoran va Kafe Savdo Tizimi',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ROUNDED PILL INPUT FIELD WITH FLOATING-STYLE LABEL
  // ============================================================
  Widget _buildPillInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isPassword,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: _textDark,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _inputBorder, width: 1.2),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword ? obscureText : false,
            style: const TextStyle(color: _textDark, fontSize: 14.5, fontWeight: FontWeight.w500),
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon, color: const Color(0xFF6B7280), size: 19),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF6B7280),
                        size: 20,
                      ),
                      onPressed: onToggleObscure,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              border: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: const BorderSide(color: _inputBorderFocused, width: 1.8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
