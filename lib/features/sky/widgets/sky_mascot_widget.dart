import 'dart:io';
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
    );

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _pulseController.repeat(reverse: true);
      _spinController.repeat();
    }
  }

  @override
  void didUpdateWidget(SkyMascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!Platform.environment.containsKey('FLUTTER_TEST') && oldWidget.mood != widget.mood) {
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
          Color(0xFF0B132B),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, basePaint);

    // 2. Rotating Arc Segments (outer reactor rim)
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, size.width * 0.05)
      ..strokeCap = StrokeCap.round
      ..color = primaryColor.withValues(alpha: 0.85);

    final angleOffset = spinProgress * 2 * math.pi;
    for (int i = 0; i < 3; i++) {
      final startAngle = angleOffset + (i * 2 * math.pi / 3);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.82),
        startAngle,
        math.pi * 0.45,
        false,
        rimPaint,
      );
    }

    // 3. Inner Pulsing Core Ring
    final coreScale = 0.55 + (pulseProgress * 0.08);
    final coreRadius = radius * coreScale;
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * 0.04)
      ..color = primaryColor;
    canvas.drawCircle(center, coreRadius, corePaint);

    // 4. Glow behind core
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = primaryColor.withValues(alpha: 0.18 + (pulseProgress * 0.12));
    canvas.drawCircle(center, coreRadius, glowPaint);

    // 5. Expressive Digital Mascot Eyes
    _paintMascotEyes(canvas, center, radius);
  }

  void _paintMascotEyes(Canvas canvas, Offset center, double radius) {
    final eyePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    final eyeGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, radius * 0.08)
      ..color = primaryColor;

    final eyeSpacing = radius * 0.34;
    final eyeY = center.dy - (radius * 0.04);
    final leftEye = Offset(center.dx - eyeSpacing, eyeY);
    final rightEye = Offset(center.dx + eyeSpacing, eyeY);
    final eyeRadius = radius * 0.14;

    switch (mood) {
      case SkyMascotMood.idle:
      case SkyMascotMood.listening:
        // Round observant eyes with core iris
        canvas.drawCircle(leftEye, eyeRadius, eyePaint);
        canvas.drawCircle(rightEye, eyeRadius, eyePaint);
        canvas.drawCircle(leftEye, eyeRadius + 1.5, eyeGlow);
        canvas.drawCircle(rightEye, eyeRadius + 1.5, eyeGlow);
        break;

      case SkyMascotMood.thinking:
        // One focused eye, one pulsating processing slit
        canvas.drawCircle(leftEye, eyeRadius * 0.9, eyePaint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: rightEye, width: eyeRadius * 2.2, height: eyeRadius * 0.5),
            const Radius.circular(2),
          ),
          eyePaint,
        );
        break;

      case SkyMascotMood.speaking:
        // Slightly dilated vocal waveform rhythm
        final speakMod = 1.0 + (pulseProgress * 0.3);
        canvas.drawOval(
          Rect.fromCenter(center: leftEye, width: eyeRadius * 1.8, height: eyeRadius * 2.2 * speakMod),
          eyePaint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: rightEye, width: eyeRadius * 1.8, height: eyeRadius * 2.2 * speakMod),
          eyePaint,
        );
        break;

      case SkyMascotMood.celebrating:
        // Cheerful upward happy arcs (^_^)
        final arcPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(2.2, radius * 0.12)
          ..color = const Color(0xFFFBBF24);

        canvas.drawArc(
          Rect.fromCenter(center: leftEye, width: eyeRadius * 2.4, height: eyeRadius * 2.0),
          math.pi,
          math.pi,
          false,
          arcPaint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: rightEye, width: eyeRadius * 2.4, height: eyeRadius * 2.0),
          math.pi,
          math.pi,
          false,
          arcPaint,
        );
        break;

      case SkyMascotMood.alert:
        // Focused alert angular gaze
        final alertPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFB923C);
        canvas.drawRect(
          Rect.fromCenter(center: leftEye, width: eyeRadius * 2.2, height: eyeRadius * 0.8),
          alertPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: rightEye, width: eyeRadius * 2.2, height: eyeRadius * 0.8),
          alertPaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(_SkyMascotPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.spinProgress != spinProgress;
  }
}
