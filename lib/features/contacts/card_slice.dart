import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../theme/tokens.dart';

/// Draws the card outline for one slice of a long card: the outline of the whole card is
/// drawn and clipped to this slice, so the slices join without a seam.
class SliceBorder extends CustomPainter {
  const SliceBorder({required this.color, required this.first, required this.last});
  final Color color;
  final bool first;
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    const r = AppRadius.md;
    final rect = RRect.fromLTRBR(.5, first ? .5 : -r - 1, size.width - .5, last ? size.height - .5 : size.height + r + 1, const Radius.circular(r));
    canvas.drawRRect(rect, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(SliceBorder old) => old.color != color || old.first != first || old.last != last;
}


/// One row of a long list that reads as a single rounded card: the card background, the outline for this slice
/// and a divider above every row but the first. Lazy lists use it so a card of thousands of rows stays cheap.
class CardSlice extends StatelessWidget {
  const CardSlice({super.key, required this.first, required this.last, required this.child});
  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const r = Radius.circular(AppRadius.md);
    return CustomPaint(
      foregroundPainter: SliceBorder(color: p.glassBorder, first: first, last: last),
      child: Material(
        color: p.glass,
        borderRadius: BorderRadius.vertical(top: first ? r : Radius.zero, bottom: last ? r : Radius.zero),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!first) Divider(height: AppStroke.hairline, thickness: AppStroke.hairline, indent: AppSpace.lg, endIndent: AppSpace.lg, color: p.separator),
          child,
        ]),
      ),
    );
  }
}
