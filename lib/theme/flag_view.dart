import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/countries.dart';
import 'tokens.dart';

/// A country flag. Most flags are the emoji for the country; Syria is drawn here as the current
/// flag (green, white with three red stars, black) because phones still show the old flag.
class FlagView extends StatelessWidget {
  const FlagView.iso(this.iso, {super.key, this.size = AppIcon.lg});
  FlagView.dial(String code, {super.key, this.size = AppIcon.lg}) : iso = countryForCode(code)?.iso;

  final String? iso;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (iso == 'SY') {
      final h = size * 0.85;
      return SizedBox(
        width: h * 1.5,
        height: h,
        child: ClipRRect(borderRadius: BorderRadius.circular(h * 0.12), child: CustomPaint(painter: _SyriaFlagPainter())),
      );
    }
    final emoji = iso == null ? '\u{1F310}' : String.fromCharCodes([for (final u in iso!.codeUnits) 0x1F1E6 + u - 0x41]);
    return Text(emoji, style: TextStyle(fontSize: size, height: 1));
  }
}

class _SyriaFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final band = size.height / 3;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, band), Paint()..color = AppFlag.green);
    canvas.drawRect(Rect.fromLTWH(0, band, size.width, band), Paint()..color = AppFlag.white);
    canvas.drawRect(Rect.fromLTWH(0, band * 2, size.width, band), Paint()..color = AppFlag.black);
    final red = Paint()..color = AppFlag.red;
    final r = band * 0.36;
    for (var i = 0; i < 3; i++) {
      final cx = size.width * (0.28 + 0.22 * i);
      _star(canvas, Offset(cx, band * 1.5), r, red);
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.4;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(c.dx + radius * math.cos(a), c.dy + radius * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
