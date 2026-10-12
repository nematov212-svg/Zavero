import 'dart:math' as math;
import 'package:flutter/material.dart';

class ZaveroBrandLogo extends StatefulWidget {
  final double size;
  final bool showSubtitle;
  final bool darkText;
  final bool isWhite;
  final bool animatedSparks;

  const ZaveroBrandLogo({
    super.key,
    this.size = 90,
    this.showSubtitle = true,
    this.darkText = false,
    this.isWhite = false,
    this.animatedSparks = true,
  });

  @override
  State<ZaveroBrandLogo> createState() => _ZaveroBrandLogoState();
}

class _ZaveroBrandLogoState extends State<ZaveroBrandLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _sparkController;

  @override
  void initState() {
    super.initState();
    _sparkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _sparkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final bowlSize = size * 0.55;
    final titleFontSize = size * 0.22;
    final subFontSize = size * 0.085;

    Widget logoContent = FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. Stylized Orange/White Noodle Bowl with Chopsticks
          SizedBox(
            width: bowlSize,
            height: bowlSize * 0.85,
            child: CustomPaint(
              painter: _NoodleBowlPainter(isWhite: widget.isWhite),
            ),
          ),
          SizedBox(height: size * 0.04),

          // 2. Bold Handwritten Style Brand Text
          Text(
            'ZAVERO',
            style: TextStyle(
              color: widget.isWhite
                  ? Colors.white
                  : (widget.darkText ? const Color(0xFF0F172A) : Colors.white),
              fontWeight: FontWeight.w900,
              fontSize: titleFontSize,
              letterSpacing: 2.5,
              height: 1.0,
              shadows: widget.isWhite
                  ? [
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.4),
                        blurRadius: 10,
                      )
                    ]
                  : null,
            ),
          ),

          // 3. Subtitle "CAFE TIZIM" & "2026"
          if (widget.showSubtitle) ...[
            SizedBox(height: size * 0.03),
            Text(
              'CAFE TIZIM',
              style: TextStyle(
                color: widget.isWhite
                    ? Colors.white70
                    : (widget.darkText
                        ? const Color(0xFF475569)
                        : const Color(0xFF94A3B8)),
                fontWeight: FontWeight.w700,
                fontSize: subFontSize,
                letterSpacing: 3.5,
              ),
            ),
            SizedBox(height: size * 0.02),
            Text(
              '2026',
              style: TextStyle(
                color: widget.isWhite
                    ? Colors.white60
                    : (widget.darkText
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
                fontWeight: FontWeight.w600,
                fontSize: subFontSize * 0.9,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ],
      ),
    );

    if (!widget.animatedSparks) {
      return logoContent;
    }

    return AnimatedBuilder(
      animation: _sparkController,
      builder: (context, child) {
        return CustomPaint(
          painter: _FlyingLightningSparksPainter(
            progress: _sparkController.value,
            isWhite: widget.isWhite,
          ),
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.all(size * 0.16),
        child: logoContent,
      ),
    );
  }
}

/// Floating lightning sparks & energetic glowing particles orbiting around the logo
class _FlyingLightningSparksPainter extends CustomPainter {
  final double progress;
  final bool isWhite;

  _FlyingLightningSparksPainter({
    required this.progress,
    required this.isWhite,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radiusX = size.width * 0.48;
    final radiusY = size.height * 0.44;

    // We render 6 flying lightning sparks at different orbital phases
    const sparks = [
      _SparkData(phaseOffset: 0.0, baseScale: 1.0, color: Color(0xFFFFD700)),
      _SparkData(phaseOffset: 0.22, baseScale: 0.8, color: Color(0xFFFF9100)),
      _SparkData(phaseOffset: 0.42, baseScale: 1.1, color: Color(0xFF00E5FF)),
      _SparkData(phaseOffset: 0.60, baseScale: 0.75, color: Color(0xFFFFEA00)),
      _SparkData(phaseOffset: 0.78, baseScale: 0.9, color: Color(0xFFFF3D00)),
      _SparkData(phaseOffset: 0.92, baseScale: 0.65, color: Colors.white),
    ];

    for (final s in sparks) {
      final currentPhase = (progress + s.phaseOffset) % 1.0;
      final angle = currentPhase * 2 * math.pi;

      // Add a slight wave to the orbit for dynamic floating effect
      final wave = math.sin(currentPhase * 4 * math.pi) * (size.width * 0.05);
      final x = center.dx + (radiusX + wave) * math.cos(angle);
      final y = center.dy + (radiusY + wave) * math.sin(angle);

      // Fade in and out along path
      final opacity = (math.sin(currentPhase * math.pi)).clamp(0.2, 1.0);
      final sparkColor = isWhite
          ? Colors.white.withValues(alpha: opacity)
          : s.color.withValues(alpha: opacity);

      // Draw lightning bolt glyph at (x, y)
      _drawLightningBolt(
        canvas,
        Offset(x, y),
        angle + math.pi / 4,
        size.width * 0.08 * s.baseScale,
        sparkColor,
      );

      // Small glowing aura behind spark
      final glowPaint = Paint()
        ..color = sparkColor.withValues(alpha: opacity * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(x, y), size.width * 0.03 * s.baseScale, glowPaint);
    }
  }

  void _drawLightningBolt(
    Canvas canvas,
    Offset position,
    double rotation,
    double boltSize,
    Color color,
  ) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);

    final path = Path();
    final half = boltSize / 2;

    // Stylized zig-zag lightning spark
    path.moveTo(0, -half);
    path.lineTo(half * 0.45, -half * 0.1);
    path.lineTo(half * 0.1, -half * 0.1);
    path.lineTo(half * 0.5, half);
    path.lineTo(-half * 0.4, 0.05);
    path.lineTo(-half * 0.05, 0.05);
    path.close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlyingLightningSparksPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SparkData {
  final double phaseOffset;
  final double baseScale;
  final Color color;

  const _SparkData({
    required this.phaseOffset,
    required this.baseScale,
    required this.color,
  });
}

class _NoodleBowlPainter extends CustomPainter {
  final bool isWhite;

  _NoodleBowlPainter({this.isWhite = false});

  @override
  void paint(Canvas canvas, Size size) {
    final primaryColor = isWhite ? Colors.white : const Color(0xFFFF4500);
    final accentColor = isWhite ? Colors.white70 : const Color(0xFFFF5722);
    final chopstickColor = isWhite ? Colors.white : const Color(0xFFFF3D00);

    final orangePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.065
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillOrangePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Chopsticks pointing upwards to top-right
    final chopstickPaint = Paint()
      ..color = chopstickColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;

    // Left chopstick
    canvas.drawLine(
      Offset(w * 0.52, h * 0.35),
      Offset(w * 0.85, h * 0.02),
      chopstickPaint,
    );
    // Right chopstick
    canvas.drawLine(
      Offset(w * 0.58, h * 0.38),
      Offset(w * 0.94, h * 0.06),
      chopstickPaint,
    );

    // Hanging noodles from chopsticks
    final noodlePath = Path();
    noodlePath.moveTo(w * 0.54, h * 0.20);
    noodlePath.quadraticBezierTo(w * 0.48, h * 0.30, w * 0.52, h * 0.42);
    noodlePath.moveTo(w * 0.60, h * 0.22);
    noodlePath.quadraticBezierTo(w * 0.56, h * 0.32, w * 0.62, h * 0.42);
    canvas.drawPath(noodlePath, orangePaint);

    // Bowl Rim (Oval top)
    final rimPath = Path();
    rimPath.addOval(Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.46),
      width: w * 0.78,
      height: h * 0.26,
    ));
    canvas.drawPath(rimPath, orangePaint);

    // Swirl noodles inside bowl
    final innerNoodle = Path();
    innerNoodle.moveTo(w * 0.28, h * 0.45);
    innerNoodle.quadraticBezierTo(w * 0.48, h * 0.38, w * 0.68, h * 0.45);
    innerNoodle.quadraticBezierTo(w * 0.48, h * 0.52, w * 0.32, h * 0.47);
    canvas.drawPath(innerNoodle, orangePaint);

    // Bowl Body (Curved Hemisphere)
    final bowlBody = Path();
    bowlBody.moveTo(w * 0.12, h * 0.46);
    bowlBody.cubicTo(
      w * 0.12,
      h * 0.88,
      w * 0.88,
      h * 0.88,
      w * 0.88,
      h * 0.46,
    );
    canvas.drawPath(bowlBody, orangePaint);

    // Bowl decorative stripe
    final stripePath = Path();
    stripePath.moveTo(w * 0.20, h * 0.62);
    stripePath.quadraticBezierTo(w * 0.50, h * 0.78, w * 0.80, h * 0.62);
    canvas.drawPath(stripePath, orangePaint);

    // Bowl Base (Foot)
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.90),
          width: w * 0.34,
          height: h * 0.10),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(baseRect, fillOrangePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
