import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/pin_security_service.dart';
import 'auth_screen.dart';
import 'blocked_screen.dart';
import 'director_screen.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> with SingleTickerProviderStateMixin {
  final _pinService = PinSecurityService();
  String _enteredPin = '';
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length < 4 && !_isLoading) {
      HapticFeedback.lightImpact();
      setState(() {
        _errorMessage = null;
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty && !_isLoading) {
      HapticFeedback.selectionClick();
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _onClear() {
    if (!_isLoading) {
      setState(() {
        _errorMessage = null;
        _enteredPin = '';
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 150));

    final res = await _pinService.verifyPin(_enteredPin);
    if (!mounted) return;

    if (res['success'] == true) {
      final AppUser user = res['user'] as AppUser;
      await appState.saveUserSession(user);
      if (!mounted) return;

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

      try {
        await appState.loadCloudDataForCafe(user.workspaceId);
      } catch (e) {
        debugPrint('PIN orqali yuklash xatoligi: $e');
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
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _isLoading = false;
        _errorMessage = 'PIN kod noto‘g‘ri. Qaytadan urinib ko‘ring.';
        _enteredPin = '';
      });
    }
  }

  Widget _buildKeypadButton(String number, String letters) {
    const tealColor = Color(0xFF00C2A8);
    return SizedBox(
      width: 80,
      height: 80,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(
          side: BorderSide(color: tealColor, width: 2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: tealColor.withValues(alpha: 0.3),
          highlightColor: tealColor.withValues(alpha: 0.15),
          onTap: () => _onDigitPressed(number),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (letters.isNotEmpty)
                Text(
                  letters,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF00C2A8);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  // App Title / Brand
                  const Text(
                    'Use Password or PIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ilovaga kirish uchun 4 xonali PIN kodni tering',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // PIN Dots
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      final dx = _shakeAnimation.value * (_shakeController.isAnimating ? 1 : 0);
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final isFilled = index < _enteredPin.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled ? tealColor : Colors.transparent,
                                border: Border.all(
                                  color: isFilled ? tealColor : Colors.white.withValues(alpha: 0.7),
                                  width: 2,
                                ),
                                boxShadow: isFilled
                                    ? [
                                        BoxShadow(
                                          color: tealColor.withValues(alpha: 0.6),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Error / Loading Status
                  SizedBox(
                    height: 24,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: tealColor,
                            ),
                          )
                        : _errorMessage != null
                            ? Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                  ),
                  const SizedBox(height: 24),

                  // Keypad 3x4 (Image 2 style)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKeypadButton('1', ''),
                      _buildKeypadButton('2', 'ABC'),
                      _buildKeypadButton('3', 'DEF'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKeypadButton('4', 'GHI'),
                      _buildKeypadButton('5', 'JKL'),
                      _buildKeypadButton('6', 'MNO'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKeypadButton('7', 'PQRS'),
                      _buildKeypadButton('8', 'TUV'),
                      _buildKeypadButton('9', 'WXYZ'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Backspace Button
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: IconButton(
                          icon: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 26),
                          onPressed: _onBackspace,
                          tooltip: 'O‘chirish',
                        ),
                      ),
                      // 0 Button
                      _buildKeypadButton('0', '+'),
                      // Clear / Refresh
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 26),
                          onPressed: _onClear,
                          tooltip: 'Tozalash',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Switch to Standard Login
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFFC107),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      );
                    },
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text(
                      'Login va parol bilan kirish',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
