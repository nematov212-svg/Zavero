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
    final subFontSize = (size * 0.09).clamp(9.0, 15.0);

    Widget logoContent = FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/logo/logo_transparent.png',
            width: size,
            height: size * 0.68,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/images/logo.png',
              width: size,
              height: size * 0.68,
              fit: BoxFit.contain,
            ),
          ),
          if (widget.showSubtitle) ...[
            SizedBox(height: size * 0.03),
            Text(
              'RESTORAN & KAFE POS TIZIMI',
              style: TextStyle(
                color: widget.isWhite
                    ? Colors.white70
                    : (widget.darkText
                        ? const Color(0xFF475569)
                        : const Color(0xFF94A3B8)),
                fontWeight: FontWeight.w700,
                fontSize: subFontSize,
                letterSpacing: 2.2,
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
        final pulse = 1.0 + 0.025 * math.sin(_sparkController.value * 2 * math.pi);
        return Transform.scale(
          scale: pulse,
          child: CustomPaint(
            painter: _FlyingLightningSparksPainter(
              progress: _sparkController.value,
              isWhite: widget.isWhite,
            ),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.all(size * 0.10),
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
