import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Expressive moods for the "Sky" AI mascot.
enum SkyMascotMood {
  idle,
  listening,
  thinking,
  speaking,
  celebrating,
  alert,
}

/// Expressive animated mascot for "Sky" AI (Iron Man / Jarvis-inspired digital core).
/// Replaces static logos with responsive eyes, energy rings, and mood expressions.
class SkyMascotWidget extends StatefulWidget {
  final double size;
  final SkyMascotMood mood;
  final VoidCallback? onTap;

  const SkyMascotWidget({
    super.key,
    this.size = 56.0,
    this.mood = SkyMascotMood.idle,
    this.onTap,
  });

  @override
  State<SkyMascotWidget> createState() => _SkyMascotWidgetState();
}

class _SkyMascotWidgetState extends State<SkyMascotWidget>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void didUpdateWidget(SkyMascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      if (widget.mood == SkyMascotMood.thinking) {
        _spinController.duration = const Duration(milliseconds: 1000);
        _spinController.repeat();
      } else if (widget.mood == SkyMascotMood.speaking) {
        _pulseController.duration = const Duration(milliseconds: 350);
        _pulseController.repeat(reverse: true);
      } else {
        _spinController.duration = const Duration(milliseconds: 3000);
        _spinController.repeat();
        _pulseController.duration = const Duration(milliseconds: 2200);
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  Color _getPrimaryMoodColor() {
    switch (widget.mood) {
      case SkyMascotMood.listening:
        return const Color(0xFF38BDF8); // Bright Cyan
      case SkyMascotMood.thinking:
        return const Color(0xFF818CF8); // Indigo
      case SkyMascotMood.speaking:
        return const Color(0xFF34D399); // Emerald Green
      case SkyMascotMood.celebrating:
        return const Color(0xFFFBBF24); // Warm Gold
      case SkyMascotMood.alert:
        return const Color(0xFFFB923C); // Orange Alert
      case SkyMascotMood.idle:
        return const Color(0xFF60A5FA); // Sky Blue
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _getPrimaryMoodColor();

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _spinController]),
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _SkyMascotPainter(
              mood: widget.mood,
              primaryColor: baseColor,
              pulseProgress: _pulseController.value,
              spinProgress: _spinController.value,
            ),
          );
        },
      ),
    );
  }
}

class _SkyMascotPainter extends CustomPainter {
  final SkyMascotMood mood;
  final Color primaryColor;
  final double pulseProgress;
  final double spinProgress;

  _SkyMascotPainter({
    required this.mood,
    required this.primaryColor,
    required this.pulseProgress,
    required this.spinProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Dark circular reactor base
    final basePaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF0F172A),
          Color(0xFF020617),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 2, basePaint);

    // 2. Outer glowing energy ring
    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.35 + (0.3 * pulseProgress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
    canvas.drawCircle(center, radius - 3, glowPaint);

    // 3. Rotating reactor arcs (Iron Man Jarvis style)
    final arcPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final startAngle = spinProgress * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      startAngle,
      math.pi * 0.6,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      startAngle + math.pi,
      math.pi * 0.6,
      false,
      arcPaint,
    );

    // 4. Mascot Eyes / Digital Core depending on mood
    _drawMascotFace(canvas, center, radius);
  }

  void _drawMascotFace(Canvas canvas, Offset center, double radius) {
    final eyePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final eyeWidth = radius * 0.28;
    final eyeHeight = radius * (mood == SkyMascotMood.listening ? 0.38 : 0.26);
    final eyeOffset = radius * 0.32;

    if (mood == SkyMascotMood.celebrating) {
      // Happy curved upward crescent eyes (^_^)
      final happyPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      final leftRect = Rect.fromCenter(
        center: Offset(center.dx - eyeOffset, center.dy - 2),
        width: eyeWidth,
        height: eyeHeight * 1.2,
      );
      final rightRect = Rect.fromCenter(
        center: Offset(center.dx + eyeOffset, center.dy - 2),
        width: eyeWidth,
        height: eyeHeight * 1.2,
      );

      canvas.drawArc(leftRect, math.pi, math.pi, false, happyPaint);
      canvas.drawArc(rightRect, math.pi, math.pi, false, happyPaint);
      return;
    }

    if (mood == SkyMascotMood.thinking) {
      // Scanning / thinking single glowing core
      final corePaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * 0.28 * (0.8 + 0.3 * pulseProgress), corePaint);
      return;
    }

    // Default & other moods: expressive digital capsules
    final leftEye = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - eyeOffset, center.dy - 2),
        width: eyeWidth,
        height: eyeHeight * (0.85 + 0.15 * pulseProgress),
      ),
      const Radius.circular(8),
    );
    final rightEye = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + eyeOffset, center.dy - 2),
        width: eyeWidth,
        height: eyeHeight * (0.85 + 0.15 * pulseProgress),
      ),
      const Radius.circular(8),
    );

    canvas.drawRRect(leftEye, eyePaint);
    canvas.drawRRect(rightEye, eyePaint);

    // Mouth wave if speaking
    if (mood == SkyMascotMood.speaking) {
      final mouthPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final mouthY = center.dy + radius * 0.36;
      final waveOffset = pulseProgress * 3;
      final path = Path()
        ..moveTo(center.dx - 8, mouthY)
        ..quadraticBezierTo(center.dx, mouthY + waveOffset, center.dx + 8, mouthY);
      canvas.drawPath(path, mouthPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyMascotPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.spinProgress != spinProgress;
  }
}
