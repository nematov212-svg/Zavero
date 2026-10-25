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

  Widget _buildKeypadButton(String number) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: const Color(0xFFE5E7EB),
          highlightColor: const Color(0xFFF3F4F6),
          onTap: () => _onDigitPressed(number),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 27,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _build3DLockIcon() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            // Shackle
            Container(
              width: 48,
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF374151), width: 7.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
            ),
            // Padlock Body
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: Container(
                width: 72,
                height: 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4B5563),
                      Color(0xFF1F2937),
                      Color(0xFF111827),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 13,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFBBF24),
                          Color(0xFFD97706),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 4.5,
                        height: 4.5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF78350F),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Soft ground shadow beneath the lock
        Container(
          width: 58,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),

                  // 3D Padlock matching Image 3
                  _build3DLockIcon(),
                  const SizedBox(height: 28),

                  // Title: "Enter your MPIN"
                  const Text(
                    'Enter your MPIN',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle: "Please enter your 4-digit security pin."
                  const Text(
                    'Please enter your 4-digit security pin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 4 MPIN indicator dots (Filled vs Empty)
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
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled ? const Color(0xFF111827) : Colors.transparent,
                                border: Border.all(
                                  color: const Color(0xFF111827),
                                  width: 1.6,
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // Error / Loading Status
                  SizedBox(
                    height: 24,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF111827),
                            ),
                          )
                        : _errorMessage != null
                            ? Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                  ),
                  const SizedBox(height: 16),

                  // Keypad 3x4 (Image 3 design)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKeypadButton('1'),
                      _buildKeypadButton('2'),
                      _buildKeypadButton('3'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKeypadButton('4'),
                      _buildKeypadButton('5'),
                      _buildKeypadButton('6'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKeypadButton('7'),
                      _buildKeypadButton('8'),
                      _buildKeypadButton('9'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Empty placeholder on left
                      const SizedBox(width: 76, height: 76),

                      // 0 Button in center
                      _buildKeypadButton('0'),

                      // Backspace Button on right
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            splashColor: const Color(0xFFE5E7EB),
                            highlightColor: const Color(0xFFF3F4F6),
                            onTap: _onBackspace,
                            child: const Center(
                              child: Icon(
                                Icons.backspace_outlined,
                                color: Color(0xFF111827),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Bottom Blue Link: "Login va parol bilan kirish"
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      );
                    },
                    child: const Text(
                      'Login va parol bilan kirish',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
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
