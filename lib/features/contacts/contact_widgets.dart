import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/palette.dart';

Color ratingBg(YoncaPalette p, Rating r) => switch (r) { Rating.hot => p.hotBg, Rating.warm => p.warmBg, _ => p.coldBg };
Color ratingFg(YoncaPalette p, Rating r) => switch (r) { Rating.hot => p.hotFg, Rating.warm => p.warmFg, _ => p.coldFg };

/// Rating glyphs from the design: flame, sun, moon (all in the accent colour).
IconData ratingIcon(Rating r) => switch (r) {
      Rating.hot => Icons.local_fire_department_outlined,
      Rating.warm => Icons.wb_sunny_outlined,
      Rating.cold => Icons.dark_mode_outlined,
      Rating.none => Icons.remove,
    };

String ratingLabel(AppLocalizations l, Rating r) => switch (r) {
      Rating.hot => l.ratingHot,
      Rating.warm => l.ratingWarm,
      Rating.cold => l.ratingCold,
      Rating.none => l.ratingNone,
    };

String roleLabel(AppLocalizations l, Role r) => switch (r) {
      Role.lead => l.roleLead,
      Role.client => l.roleClient,
      Role.supplier => l.roleSupplier,
    };

String phoneLabelText(AppLocalizations l, String label) => switch (label) {
      'work' => l.labelWork,
      'home' => l.labelHome,
      'whatsapp' => l.labelWhatsapp,
      'other' => l.labelOther,
      _ => l.labelMobile,
    };

/// Up to two letters: first letters of the first and last word of the name (or company).
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '';
  String first(String w) => String.fromCharCode(w.runes.first).toUpperCase();
  if (words.length == 1) return first(words.first);
  return first(words.first) + first(words.last);
}

/// Rounded-square avatar (design `.av`): initials, rating badge at the bottom corner,
/// orange dot at the top corner when the contact has a temporary note.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.summary, this.size = 44, this.showBadges = true, this.onHeader = false, this.fontSize});

  /// Initials size; defaults to 14 scaled with [size].
  final double? fontSize;

  /// On the top bar (kept so existing callers compile).
  final bool onHeader;
  final ContactSummary summary;
  final double size;
  final bool showBadges;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = AppLocalizations.of(context);
    final scale = size / 44;
    final avBg = p.avBg;
    final avFg = p.avFg;
    final pp = summary.contact.photoPath;
    final photo = (pp != null && pp.isNotEmpty && File(pp).existsSync()) ? File(pp) : null;
    final initials = summary.isIncomplete ? l.numberInitial : initialsOf(summary.displayName);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: avBg, borderRadius: BorderRadius.circular(8)),
            child: photo != null
                ? Image.file(photo, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Text(initials, style: TextStyle(color: avFg, fontWeight: FontWeight.w600, fontSize: fontSize ?? 14 * scale)))
                : Text(
                    initials,
                    style: TextStyle(color: avFg, fontWeight: FontWeight.w600, fontSize: fontSize ?? 14 * scale),
                  ),
          ),
          if (showBadges && summary.contact.temporaryNote.trim().isNotEmpty)
            PositionedDirectional(
              start: -3 * scale,
              top: -3 * scale,
              child: Container(
                width: 12 * scale,
                height: 12 * scale,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9822B),
                  shape: BoxShape.circle,
                  border: Border.all(color: p.bg, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
