import 'dart:math';
import 'package:flutter/material.dart';

class AviatorFlightPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 (relative to canvas width)
  final double multiplier;
  final bool isCrashed;
  final bool isWaiting;
  final double countdownProgress; // 0.0 to 1.0
  final double flightTimeSec;

  static final Paint _gridPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.04)
    ..strokeWidth = 1.0;

  static final Paint _baseLinePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.12)
    ..strokeWidth = 1.5;

  static final Paint _linePaintFlying = Paint()
    ..color = const Color(0xFFE51D35)
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final Paint _linePaintCrashed = Paint()
    ..color = Colors.red.withValues(alpha: 0.6)
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final Paint _glowPaint = Paint()
    ..color = const Color(0xFFFF4757).withValues(alpha: 0.4)
    ..strokeWidth = 7.0
    ..style = PaintingStyle.stroke
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _bodyPaint = Paint()..color = const Color(0xFFE51D35);
  static final Paint _cockpitPaint = Paint()..color = const Color(0xFF70A1FF).withValues(alpha: 0.85);
  static final Paint _wingPaint = Paint()..color = const Color(0xFFC0152B);
  static final Paint _tailPaint = Paint()..color = const Color(0xFF990E1F);
  static final Paint _propPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.75)
    ..strokeWidth = 2.0;
  static final Paint _nosePaint = Paint()..color = const Color(0xFFFFD32A);

  AviatorFlightPainter({
    required this.progress,
    required this.multiplier,
    required this.isCrashed,
    required this.isWaiting,
    this.countdownProgress = 0.0,
    required this.flightTimeSec,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Draw Grid Lines & Coordinates
    _drawGrid(canvas, size);

    if (isWaiting) {
      // Draw idle runway line
      _drawRunway(canvas, size);
      return;
    }

    // 2. Calculate flight curve path
    final path = Path();
    final fillPath = Path();

    final startX = 20.0;
    final startY = h - 25.0;

    path.moveTo(startX, startY);
    fillPath.moveTo(startX, startY);

    // Current plane position along parabolic curve
    final clampedProg = progress.clamp(0.0, 1.0);
    final targetX = startX + (w - startX - 70.0) * clampedProg;
    // Parabolic upward curve
    final curveFactor = pow(clampedProg, 1.35).toDouble();
    final targetY = startY - (h - 75.0) * curveFactor;

    // Cubic Bézier curve
    final controlX = startX + (targetX - startX) * 0.45;
    final controlY = startY;

    path.quadraticBezierTo(controlX, controlY, targetX, targetY);

    fillPath.quadraticBezierTo(controlX, controlY, targetX, targetY);
    fillPath.lineTo(targetX, startY);
    fillPath.lineTo(startX, startY);
    fillPath.close();

    // 3. Draw gradient trail fill under the flight curve
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isCrashed
          ? [
              Colors.red.withValues(alpha: 0.25),
              Colors.red.withValues(alpha: 0.02),
            ]
          : [
              const Color(0xFFE51D35).withValues(alpha: 0.35),
              const Color(0xFFE51D35).withValues(alpha: 0.05),
            ],
    );

    _fillPaint.shader = fillGradient.createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, _fillPaint);

    // 4. Draw Red Flight Path Line
    canvas.drawPath(path, isCrashed ? _linePaintCrashed : _linePaintFlying);

    // 5. Draw Glowing trail line on top
    if (!isCrashed) {
      canvas.drawPath(path, _glowPaint);
    }

    // 6. Draw the Red Aviator Propeller Airplane at targetX, targetY
    if (!isCrashed) {
      _drawAirplane(canvas, Offset(targetX, targetY), clampedProg, flightTimeSec);
    } else {
      _drawCrashExplosion(canvas, Offset(targetX, targetY));
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Horizontal grid lines
    const hDivisions = 5;
    for (int i = 1; i < hDivisions; i++) {
      final y = (h / hDivisions) * i;
      canvas.drawLine(Offset(0, y), Offset(w, y), _gridPaint);
    }

    // Vertical grid lines
    const vDivisions = 6;
    for (int i = 1; i < vDivisions; i++) {
      final x = (w / vDivisions) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, h - 20), _gridPaint);
    }

    // Base ground line
    canvas.drawLine(Offset(10, h - 25), Offset(w - 10, h - 25), _baseLinePaint);
  }

  void _drawRunway(Canvas canvas, Size size) {
    final h = size.height;
    final planeOffset = Offset(35, h - 35);
    _drawAirplane(canvas, planeOffset, 0.0, 0.0, isIdle: true);
  }

  void _drawAirplane(Canvas canvas, Offset pos, double prog, double timeSec, {bool isIdle = false}) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    // Dynamic pitch angle based on climb rate
    final angle = isIdle ? 0.0 : (-0.22 - 0.25 * pow(prog, 0.8)).toDouble();
    // subtle engine vibration
    final vibration = isIdle ? 0.0 : sin(timeSec * 40) * 1.5;
    canvas.rotate(angle);
    canvas.translate(0, vibration);

    // Jet / Engine fire exhaust
    if (!isIdle) {
      final exhaustPaint = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFDF00), Color(0xFFFF4757), Colors.transparent],
        ).createShader(Rect.fromCircle(center: const Offset(-24, 2), radius: 14));
      canvas.drawCircle(const Offset(-22, 2), 10 + sin(timeSec * 30) * 3, exhaustPaint);
    }

    // Fuselage (Red Aerodynamic Body)
    final bodyPaint = Paint()..color = const Color(0xFFE51D35);
    final bodyPath = Path()
      ..moveTo(22, 0)
      ..quadraticBezierTo(24, 2, 26, 3) // Nose cone
      ..lineTo(-18, 5)
      ..lineTo(-24, -2) // Tail
      ..lineTo(-18, -4)
      ..quadraticBezierTo(8, -5, 22, 0)
      ..close();
    canvas.drawPath(bodyPath, bodyPaint);

    // Canopy / Cockpit glass
    final cockpitPaint = Paint()..color = const Color(0xFF70A1FF).withValues(alpha: 0.85);
    final cockpitPath = Path()
      ..moveTo(6, -4)
      ..quadraticBezierTo(14, -4, 16, -1)
      ..lineTo(4, -1)
      ..close();
    canvas.drawPath(cockpitPath, cockpitPaint);

    // Main Wings (Red with highlight)
    final wingPaint = Paint()..color = const Color(0xFFC0152B);
    final wingPath = Path()
      ..moveTo(4, -2)
      ..lineTo(-6, -18)
      ..lineTo(-12, -18)
      ..lineTo(-4, 0)
      ..close();
    canvas.drawPath(wingPath, wingPaint);

    // Tail Wing
    final tailPaint = Paint()..color = const Color(0xFF990E1F);
    final tailPath = Path()
      ..moveTo(-16, -2)
      ..lineTo(-22, -12)
      ..lineTo(-26, -12)
      ..lineTo(-22, 0)
      ..close();
    canvas.drawPath(tailPath, tailPaint);

    // Spinning Propeller at front nose
    final propAngle = timeSec * 50;
    final propPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(26 + cos(propAngle) * 8, 3 + sin(propAngle) * 8),
      Offset(26 - cos(propAngle) * 8, 3 - sin(propAngle) * 8),
      propPaint,
    );

    // Front Nose Cap
    final nosePaint = Paint()..color = const Color(0xFFFFD32A);
    canvas.drawCircle(const Offset(26, 3), 2.5, nosePaint);

    canvas.restore();
  }

  void _drawCrashExplosion(Canvas canvas, Offset pos) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    final glowPaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset.zero, 24, glowPaint);

    final burstPaint = Paint()
      ..color = const Color(0xFFFF3838)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 12, burstPaint);

    final innerPaint = Paint()
      ..color = const Color(0xFFFFD32A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 6, innerPaint);

    // Explosion spark lines
    final sparkPaint = Paint()
      ..color = const Color(0xFFFF9F1A)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 8; i++) {
      final a = (i * pi / 4);
      final x1 = cos(a) * 10;
      final y1 = sin(a) * 10;
      final x2 = cos(a) * 22;
      final y2 = sin(a) * 22;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), sparkPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AviatorFlightPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.multiplier != multiplier ||
        oldDelegate.isCrashed != isCrashed ||
        oldDelegate.isWaiting != isWaiting ||
        oldDelegate.countdownProgress != countdownProgress ||
        oldDelegate.flightTimeSec != flightTimeSec;
  }
}
