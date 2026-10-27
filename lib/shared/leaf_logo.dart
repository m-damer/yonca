import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// The YONCA mark: four leaves in the four logo greens (2 by 2).
class LeafLogo extends StatelessWidget {
  const LeafLogo({super.key, this.size = 52});
  final double size;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final tile = (size - 2) / 2;
    final r = tile * 0.42;
    Widget leaf(List<Color> colors, BorderRadius radius) => Container(
          width: tile,
          height: tile,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: colors.first,
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
            leaf([pal.leaves[0]], a),
            const SizedBox(width: 2),
            leaf([pal.leaves[1]], b),
          ]),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            leaf([pal.leaves[2]], b),
            const SizedBox(width: 2),
            leaf([pal.leaves[3]], a),
          ]),
        ]),
      ),
    );
  }
}
