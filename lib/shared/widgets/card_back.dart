import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../app/theme.dart';

/// 牌背：牌面組有牌背圖就用圖，否則畫一張暮光紫底、晨光金太陽與星星的牌背（App 精神：光明）。
class CardBack extends StatelessWidget {
  const CardBack({super.key});

  @override
  Widget build(BuildContext context) {
    final deck = AppServices.maybeOf(context)?.deck.value;
    final back = deck?.backAsset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: back != null
          ? Image.asset(back, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _PaintedBack())
          : const _PaintedBack(),
    );
  }
}

class _PaintedBack extends StatelessWidget {
  const _PaintedBack();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5A4A86), TarotColors.twilight, Color(0xFF6E4E7A)],
        ),
        border: Border.all(color: TarotColors.dawn, width: 1.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: TarotColors.dawn.withValues(alpha: 0.55), width: 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: CustomPaint(painter: _SunPainter(), child: const SizedBox.expand()),
        ),
      ),
    );
  }
}

/// 中央一輪太陽（十二道光芒）、外圈一道細環，四角各一顆小星。
class _SunPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.36;
    final gold = Paint()..color = TarotColors.dawn;
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        TarotColors.dawn.withValues(alpha: 0.45),
        TarotColors.dawn.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: c, radius: r * 1.6));
    canvas.drawCircle(c, r * 1.6, glow);
    final line = Paint()
      ..color = TarotColors.dawn.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawCircle(c, r, line);
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      final long = i.isEven;
      final p1 = c + Offset(cos(a), sin(a)) * r * 0.42;
      final p2 = c + Offset(cos(a), sin(a)) * r * (long ? 0.86 : 0.7);
      canvas.drawLine(p1, p2, line..strokeWidth = long ? 1.4 : 0.9);
    }
    canvas.drawCircle(c, r * 0.3, gold);
    void star(Offset o, double s) {
      final path = Path();
      for (var k = 0; k < 8; k++) {
        final rr = k.isEven ? s : s * 0.35;
        final a = k * pi / 4 - pi / 2;
        final p = o + Offset(cos(a), sin(a)) * rr;
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, gold);
    }

    final s = size.shortestSide * 0.05;
    final m = size.shortestSide * 0.12;
    star(Offset(m, m), s);
    star(Offset(size.width - m, m), s);
    star(Offset(m, size.height - m), s);
    star(Offset(size.width - m, size.height - m), s);
  }

  @override
  bool shouldRepaint(_SunPainter oldDelegate) => false;
}
