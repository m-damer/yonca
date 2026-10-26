import 'dart:ui';

import 'package:flutter/material.dart';

import 'palette.dart';

/// Soft green background with blurred colour blobs (design: glass style).
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget blob(double size, Color c, {double? left, double? right, double? top, double? bottom}) {
      return Positioned(
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        child: IgnorePointer(
          child: Opacity(
            opacity: p.blobOpacity,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c),
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: p.bg,
      child: Stack(
        children: [
          blob(300, const Color.fromRGBO(13, 138, 120, .28), right: -100, top: -60),
          blob(260, const Color.fromRGBO(34, 107, 54, .20), left: -120, bottom: 120),
          blob(280, const Color.fromRGBO(13, 138, 120, .22), right: -60, bottom: -100),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// Translucent card with a light border (radius 26, blur 10).
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = BorderRadius.circular(26);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: p.glass,
            borderRadius: radius,
            border: Border.all(color: p.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}
