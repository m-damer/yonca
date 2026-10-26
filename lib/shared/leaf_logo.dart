import 'package:flutter/material.dart';

/// The YONCA mark: four leaves in the four logo greens (2 by 2).
class LeafLogo extends StatelessWidget {
  const LeafLogo({super.key, this.size = 52});
  final double size;

  @override
  Widget build(BuildContext context) {
    final tile = (size - 2) / 2;
    final r = tile * 0.42;
    Widget leaf(List<Color> colors, BorderRadius radius) => Container(
          width: tile,
          height: tile,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          ),
        );
    final a = BorderRadius.only(topRight: Radius.circular(r), bottomLeft: Radius.circular(r));
    final b = BorderRadius.only(topLeft: Radius.circular(r), bottomRight: Radius.circular(r));
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: size,
        height: size,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            leaf(const [Color(0xFF226B36), Color(0xFF2E7845)], a),
            const SizedBox(width: 2),
            leaf(const [Color(0xFF2F8A7A), Color(0xFF4AA68E)], b),
          ]),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            leaf(const [Color(0xFF0D8A78), Color(0xFF2BAA80)], b),
            const SizedBox(width: 2),
            leaf(const [Color(0xFF8DE5C0), Color(0xFF6FCB9C)], a),
          ]),
        ]),
      ),
    );
  }
}
