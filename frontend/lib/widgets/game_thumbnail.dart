import 'dart:math';
import 'package:flutter/material.dart';

enum GameThumbnailType {
  aviator,
  mines,
  wheel,
  dice,
  plinko,
  dragonTiger,
  penalty,
  jetX,
}

class GameThumbnail extends StatelessWidget {
  final GameThumbnailType type;
  final double height;
  final double width;

  const GameThumbnail({
    super.key,
    required this.type,
    this.height = 110,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _ThumbnailPainter(type: type),
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  final GameThumbnailType type;

  _ThumbnailPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case GameThumbnailType.aviator:
        _drawAviator(canvas, size);
        break;
      case GameThumbnailType.mines:
        _drawMines(canvas, size);
        break;
      case GameThumbnailType.wheel:
        _drawWheel(canvas, size);
        break;
      case GameThumbnailType.dice:
        _drawDice(canvas, size);
        break;
      case GameThumbnailType.plinko:
        _drawPlinko(canvas, size);
        break;
      case GameThumbnailType.dragonTiger:
        _drawDragonTiger(canvas, size);
        break;
      case GameThumbnailType.penalty:
        _drawPenalty(canvas, size);
        break;
      case GameThumbnailType.jetX:
        _drawJetX(canvas, size);
        break;
    }
  }

  // --- 1. AVIATOR THUMBNAIL ---
  void _drawAviator(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF800A17), Color(0xFF2C0B12), Color(0xFF0F141C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Grid Radar Lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;
    for (double i = 0; i < w; i += 24) {
      canvas.drawLine(Offset(i, 0), Offset(i, h), gridPaint);
    }
    for (double i = 0; i < h; i += 24) {
      canvas.drawLine(Offset(0, i), Offset(w, i), gridPaint);
    }

    // Parabolic Flight Curve
    final curvePath = Path()
      ..moveTo(10, h - 15)
      ..quadraticBezierTo(w * 0.45, h - 20, w * 0.72, h * 0.32);

    final fillPath = Path()
      ..moveTo(10, h - 15)
      ..quadraticBezierTo(w * 0.45, h - 20, w * 0.72, h * 0.32)
      ..lineTo(w * 0.72, h - 15)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFE51D35).withValues(alpha: 0.45), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFFE51D35)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(curvePath, linePaint);

    // Glowing Trail
    final glowPaint = Paint()
      ..color = const Color(0xFFFF4757).withValues(alpha: 0.5)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(curvePath, glowPaint);

    // Red Monoplane
    canvas.save();
    canvas.translate(w * 0.72, h * 0.32);
    canvas.rotate(-0.35);

    // Jet fire exhaust
    final firePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFDF00), Color(0xFFFF4757), Colors.transparent],
      ).createShader(Rect.fromCircle(center: const Offset(-18, 2), radius: 10));
    canvas.drawCircle(const Offset(-18, 2), 8, firePaint);

    // Plane body
    final bodyPaint = Paint()..color = const Color(0xFFE51D35);
    final bodyPath = Path()
      ..moveTo(16, 0)
      ..lineTo(-14, 4)
      ..lineTo(-18, -2)
      ..lineTo(-14, -4)
      ..close();
    canvas.drawPath(bodyPath, bodyPaint);

    // Wing
    final wingPaint = Paint()..color = const Color(0xFFB31224);
    final wingPath = Path()
      ..moveTo(2, -2)
      ..lineTo(-6, -14)
      ..lineTo(-10, -14)
      ..lineTo(-3, 0)
      ..close();
    canvas.drawPath(wingPath, wingPaint);

    // Cockpit
    final glassPaint = Paint()..color = const Color(0xFF70A1FF);
    canvas.drawOval(Rect.fromCenter(center: const Offset(4, -2), width: 8, height: 4), glassPaint);

    canvas.restore();

    // Multiplier Text Badge
    _drawBadge(canvas, Offset(w * 0.22, h * 0.35), '100x', const Color(0xFFFFD32A));
  }

  // --- 2. MINES GOLD THUMBNAIL ---
  void _drawMines(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 3x3 Grid Cells
    final cellPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final cellBorder = Paint()
      ..color = const Color(0xFF00D2D3).withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final cellW = (w - 60) / 4;
    final cellH = (h - 30) / 3;

    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 4; c++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(20 + c * (cellW + 6), 12 + r * (cellH + 4), cellW, cellH),
          const Radius.circular(6),
        );
        canvas.drawRRect(rect, cellPaint);
        canvas.drawRRect(rect, cellBorder);
      }
    }

    // Sparkling Diamonds in Center
    _drawDiamond(canvas, Offset(w * 0.40, h * 0.50), 16, const Color(0xFF00D2D3));
    _drawDiamond(canvas, Offset(w * 0.65, h * 0.45), 20, const Color(0xFFFFD32A));
    _drawDiamond(canvas, Offset(w * 0.22, h * 0.65), 14, const Color(0xFFFF6B6B));

    // Gold Sparkles
    _drawSparkle(canvas, Offset(w * 0.78, h * 0.25), 6, const Color(0xFFFFD32A));
    _drawSparkle(canvas, Offset(w * 0.15, h * 0.35), 5, const Color(0xFF00D2D3));
  }

  void _drawDiamond(Canvas canvas, Offset center, double rad, Color color) {
    // Glow
    final glow = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, rad * 0.9, glow);

    final dPath = Path()
      ..moveTo(center.dx, center.dy - rad)
      ..lineTo(center.dx + rad * 0.8, center.dy)
      ..lineTo(center.dx, center.dy + rad)
      ..lineTo(center.dx - rad * 0.8, center.dy)
      ..close();

    final dPaint = Paint()..color = color;
    canvas.drawPath(dPath, dPaint);

    final innerPath = Path()
      ..moveTo(center.dx, center.dy - rad * 0.6)
      ..lineTo(center.dx + rad * 0.4, center.dy)
      ..lineTo(center.dx, center.dy + rad * 0.6)
      ..lineTo(center.dx - rad * 0.4, center.dy)
      ..close();
    final innerPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawPath(innerPath, innerPaint);
  }

  // --- 3. LUCKY WHEEL THUMBNAIL ---
  void _drawWheel(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Neon Roulette Wheel
    final center = Offset(w * 0.5, h * 0.55);
    final radius = h * 0.42;

    // Outer rim glow
    final rimGlow = Paint()
      ..color = const Color(0xFFFFD32A).withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, radius + 4, rimGlow);

    // Segments
    final colors = [
      const Color(0xFFE51D35),
      const Color(0xFFFF9F1A),
      const Color(0xFF2ED573),
      const Color(0xFF3742FA),
      const Color(0xFF9C88FF),
      const Color(0xFFFF4757),
      const Color(0xFF00CEC9),
      const Color(0xFFFFA502),
    ];

    const count = 8;
    for (int i = 0; i < count; i++) {
      final sweep = (2 * pi) / count;
      final startAngle = i * sweep;
      final segPaint = Paint()..color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        segPaint,
      );
    }

    // Outer Border Ring
    final ringPaint = Paint()
      ..color = const Color(0xFFFFD32A)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, ringPaint);

    // Center Gold Hub
    final hubPaint = Paint()..color = const Color(0xFF1E272E);
    canvas.drawCircle(center, 12, hubPaint);
    final innerHub = Paint()..color = const Color(0xFFFFD32A);
    canvas.drawCircle(center, 6, innerHub);

    // Top Pointer Arrow
    final pointerPath = Path()
      ..moveTo(center.dx, center.dy - radius - 6)
      ..lineTo(center.dx + 7, center.dy - radius + 6)
      ..lineTo(center.dx - 7, center.dy - radius + 6)
      ..close();
    final pPaint = Paint()..color = const Color(0xFFFFD32A);
    canvas.drawPath(pointerPath, pPaint);
  }

  // --- 4. DICE ROLL THUMBNAIL ---
  void _drawDice(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF240B36), Color(0xFFC31432)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 3D Isometric / Angled Dice 1
    canvas.save();
    canvas.translate(w * 0.35, h * 0.48);
    canvas.rotate(-0.25);
    _drawSingleDice(canvas, 38, const Color(0xFFFFFFFF), [1, 3, 5]);
    canvas.restore();

    // 3D Angled Dice 2
    canvas.save();
    canvas.translate(w * 0.65, h * 0.52);
    canvas.rotate(0.32);
    _drawSingleDice(canvas, 34, const Color(0xFFFFD32A), [6, 2, 4]);
    canvas.restore();

    // Glowing Stars / Sparkles
    _drawSparkle(canvas, Offset(w * 0.18, h * 0.25), 6, Colors.white);
    _drawSparkle(canvas, Offset(w * 0.85, h * 0.30), 7, const Color(0xFFFFD32A));
  }

  void _drawSingleDice(Canvas canvas, double s, Color baseColor, List<int> dots) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s, height: s),
      const Radius.circular(8),
    );

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(rect, shadowPaint);

    // Body
    final bodyPaint = Paint()..color = baseColor;
    canvas.drawRRect(rect, bodyPaint);

    // Dot paint
    final dotPaint = Paint()..color = baseColor == Colors.white ? const Color(0xFFE51D35) : const Color(0xFF1E272E);
    // Draw center pip
    canvas.drawCircle(Offset.zero, 3.5, dotPaint);
    canvas.drawCircle(const Offset(-10, -10), 3.5, dotPaint);
    canvas.drawCircle(const Offset(10, 10), 3.5, dotPaint);
    canvas.drawCircle(const Offset(-10, 10), 3.5, dotPaint);
    canvas.drawCircle(const Offset(10, -10), 3.5, dotPaint);
  }

  // --- 5. PLINKO THUMBNAIL ---
  void _drawPlinko(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0A192F), Color(0xFF0F3460), Color(0xFF16213E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Peg Pyramid
    final pegPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    const rows = 4;
    for (int r = 0; r < rows; r++) {
      final count = r + 2;
      final y = 18.0 + r * 16.0;
      final startX = (w / 2) - ((count - 1) * 14.0) / 2;
      for (int c = 0; c < count; c++) {
        final x = startX + c * 14.0;
        canvas.drawCircle(Offset(x, y), 2.2, pegPaint);
      }
    }

    // Falling Golden Plinko Ball
    final ballCenter = Offset(w * 0.53, h * 0.45);
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD32A).withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(ballCenter, 8, glowPaint);

    final ballPaint = Paint()..color = const Color(0xFFFFD32A);
    canvas.drawCircle(ballCenter, 6, ballPaint);

    // Bottom Multiplier Buckets
    const buckets = ['10x', '2x', '0.5', '2x', '10x'];
    final bColors = [
      const Color(0xFFE51D35),
      const Color(0xFFFF9F1A),
      const Color(0xFF2ED573),
      const Color(0xFFFF9F1A),
      const Color(0xFFE51D35),
    ];
    final bW = (w - 40) / buckets.length;
    for (int i = 0; i < buckets.length; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(20 + i * bW, h - 18, bW - 3, 14),
        const Radius.circular(3),
      );
      final p = Paint()..color = bColors[i];
      canvas.drawRRect(rect, p);
    }
  }

  // --- 6. DRAGON TIGER / CARD CLASH THUMBNAIL ---
  void _drawDragonTiger(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Dragon Card (Red)
    canvas.save();
    canvas.translate(w * 0.35, h * 0.5);
    canvas.rotate(-0.15);
    _drawPlayingCard(canvas, 'K', const Color(0xFFE51D35), isHeart: true);
    canvas.restore();

    // Tiger Card (Gold)
    canvas.save();
    canvas.translate(w * 0.65, h * 0.5);
    canvas.rotate(0.18);
    _drawPlayingCard(canvas, 'A', const Color(0xFFFF9F1A), isSpade: true);
    canvas.restore();

    // VS Badge in Center
    _drawBadge(canvas, Offset(w * 0.50, h * 0.50), 'VS', Colors.white);
  }

  void _drawPlayingCard(Canvas canvas, String label, Color accentColor, {bool isHeart = false, bool isSpade = false}) {
    const cardW = 36.0;
    const cardH = 52.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
      const Radius.circular(6),
    );

    // Glow
    final glow = Paint()
      ..color = accentColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(rect, glow);

    // Face
    final face = Paint()..color = Colors.white;
    canvas.drawRRect(rect, face);

    // Border
    final border = Paint()
      ..color = accentColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rect, border);

    // Suit icon symbol
    final iconPaint = Paint()..color = accentColor;
    canvas.drawCircle(const Offset(0, 2), 6, iconPaint);
  }

  // --- 7. PENALTY SHOOTOUT THUMBNAIL ---
  void _drawPenalty(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient (Pitch stadium under floodlights)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF093028), Color(0xFF237A57)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Goal Post Net Lines
    final netPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;
    for (double i = 20; i < w - 20; i += 12) {
      canvas.drawLine(Offset(i, 10), Offset(i, h * 0.6), netPaint);
    }
    for (double i = 10; i < h * 0.6; i += 10) {
      canvas.drawLine(Offset(20, i), Offset(w - 20, i), netPaint);
    }

    // Goal Frame White Bars
    final framePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(18, 8, w - 36, h * 0.55), const Radius.circular(4)),
      framePaint,
    );

    // Streaking Soccer Ball
    final ballCenter = Offset(w * 0.68, h * 0.35);

    // Speed lines
    final speedPaint = Paint()
      ..color = const Color(0xFFFFD32A).withValues(alpha: 0.6)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.25, h * 0.75), ballCenter, speedPaint);

    // Ball
    final ballPaint = Paint()..color = Colors.white;
    canvas.drawCircle(ballCenter, 10, ballPaint);
    final patchPaint = Paint()..color = const Color(0xFF1E272E);
    canvas.drawCircle(ballCenter, 4, patchPaint);
  }

  // --- 8. JETX / SPACE CRASH THUMBNAIL ---
  void _drawJetX(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Cosmic Galaxy Background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF000428), Color(0xFF004E92)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Cosmic Nebula
    final nebula = Paint()
      ..color = const Color(0xFF8E44AD).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(Offset(w * 0.7, h * 0.4), 28, nebula);

    // Stars
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(w * 0.15, h * 0.2), 1.5, starPaint);
    canvas.drawCircle(Offset(w * 0.35, h * 0.7), 1.2, starPaint);
    canvas.drawCircle(Offset(w * 0.85, h * 0.25), 1.8, starPaint);
    canvas.drawCircle(Offset(w * 0.90, h * 0.65), 1.0, starPaint);

    // Supersonic Shuttle Rocket
    canvas.save();
    canvas.translate(w * 0.58, h * 0.40);
    canvas.rotate(-0.45);

    // Blue Plasma Flame
    final flamePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF00D2D3), Color(0xFF54A0FF), Colors.transparent],
      ).createShader(Rect.fromCircle(center: const Offset(-20, 0), radius: 12));
    canvas.drawCircle(const Offset(-20, 0), 10, flamePaint);

    // Shuttle Body
    final sBody = Paint()..color = Colors.white;
    final sPath = Path()
      ..moveTo(18, 0)
      ..lineTo(-14, 5)
      ..lineTo(-18, -5)
      ..lineTo(-14, -5)
      ..close();
    canvas.drawPath(sPath, sBody);

    // Jet Wings
    final wPaint = Paint()..color = const Color(0xFF00D2D3);
    final wPath = Path()
      ..moveTo(2, -4)
      ..lineTo(-8, -16)
      ..lineTo(-12, -16)
      ..lineTo(-4, 0)
      ..close();
    canvas.drawPath(wPath, wPaint);

    canvas.restore();
  }

  void _drawSparkle(Canvas canvas, Offset pos, double size, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(pos.dx - size, pos.dy), Offset(pos.dx + size, pos.dy), p);
    canvas.drawLine(Offset(pos.dx, pos.dy - size), Offset(pos.dx, pos.dy + size), p);
  }

  void _drawBadge(Canvas canvas, Offset pos, String text, Color color) {
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pos, width: 34, height: 18),
      const Radius.circular(6),
    );
    final bgP = Paint()..color = Colors.black.withValues(alpha: 0.6);
    canvas.drawRRect(bgRect, bgP);

    final borderP = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(bgRect, borderP);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ThumbnailPainter oldDelegate) => oldDelegate.type != type;
}
