import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

/// Plain page background (the old blurred blobs are gone).
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: context.palette.bg, child: child);
}

/// Solid card with a hairline border (radius 16).
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.glassBorder),
      ),
      child: child,
    );
  }
}

/// Coloured band at the top of a screen (forest green), with the status bar inside it.
class HeaderBand extends StatelessWidget {
  const HeaderBand({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 20), this.square = false});
  final Widget child;

  /// No rounded bottom edge, for a bar that joins a taller header below it.
  final bool square;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Container(
      decoration: BoxDecoration(
        color: p.header,
        borderRadius: square ? null : const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(bottom: false, child: Padding(padding: padding, child: child)),
    ));
  }
}
