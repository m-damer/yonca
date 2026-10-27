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
  const ContactAvatar({super.key, required this.summary, this.size = 44, this.showBadges = true, this.onHeader = false});

  /// On the green header band: mint tile with dark initials, so it stays visible.
  final bool onHeader;
  final ContactSummary summary;
  final double size;
  final bool showBadges;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = AppLocalizations.of(context);
    final rating = ratingFromName(summary.contact.rating);
    final scale = size / 44;
    final leaf = summary.contact.id % 4;
    final avBg = onHeader ? p.accent : p.leaves[leaf];
    // Mint (index 1) takes dark text; the other three take white (or dark ink in dark mode).
    final avFg = onHeader || leaf == 1 || Theme.of(context).brightness == Brightness.dark ? p.onAccent : Colors.white;
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
            decoration: BoxDecoration(color: avBg, borderRadius: BorderRadius.circular(size * 16 / 44)),
            child: Text(
              initials,
              style: TextStyle(color: avFg, fontWeight: FontWeight.w700, fontSize: 16 * scale),
            ),
          ),
          if (showBadges && rating != Rating.none)
            PositionedDirectional(
              end: -4 * scale,
              bottom: -4 * scale,
              child: Container(
                width: 20 * scale,
                height: 20 * scale,
                decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle),
                child: Icon(ratingIcon(rating), size: 13 * scale, color: p.primary),
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
