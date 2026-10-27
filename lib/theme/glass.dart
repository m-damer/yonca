import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

/// Plain page background (the old blurred blobs are gone).
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});
  final Widget child;

  @override
  // A Material (not a ColoredBox) so list tiles and buttons inside can paint their ink.
  Widget build(BuildContext context) => Material(color: context.palette.bg, child: child);
}

/// Flat card: surface fill, radius 8, no border or shadow.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.glass,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Top bar area: same colour as the page, with the status bar inside it.
class HeaderBand extends StatelessWidget {
  const HeaderBand({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 8), this.square = false});
  final Widget child;

  /// Kept for existing callers; the bar is always flat now.
  final bool square;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent),
      child: Container(
        color: p.header,
        child: SafeArea(bottom: false, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}
