import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

Color roleBg(YoncaPalette p, Role r) => switch (r) { Role.lead => p.leadBg, Role.client => p.wonBg, Role.supplier => p.supplierBg };
Color roleFg(YoncaPalette p, Role r) => switch (r) { Role.lead => p.leadFg, Role.client => p.wonFg, Role.supplier => p.supplierFg };
Color ratingBg(YoncaPalette p, Rating r) => switch (r) { Rating.hot => p.hotBg, Rating.warm => p.warmBg, _ => p.coldBg };
Color ratingFg(YoncaPalette p, Rating r) => switch (r) { Rating.hot => p.hotFg, Rating.warm => p.warmFg, _ => p.coldFg };

/// Rating glyphs from the design: flame, sun, moon (all in the accent colour).
IconData ratingIcon(Rating r) => switch (r) {
      Rating.hot => Lu.flame,
      Rating.warm => Lu.sun,
      Rating.cold => Lu.moon,
      Rating.none => Lu.minus,
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

/// A shorter role name for tight places such as list rows.
String roleShortLabel(AppLocalizations l, Role r) => r == Role.lead ? l.roleLeadShort : roleLabel(l, r);

/// The type shown next to an entry: relations and messenger accounts have their own types;
/// a type the app does not know (typed on another device) is shown as written.
String entryLabelText(AppLocalizations l, String kind, String label) {
  if (kind == 'relation' || kind == 'im') {
    return switch (label) {
      'spouse' => l.labelSpouse,
      'child' => l.labelChild,
      'parent' => l.labelParent,
      'sibling' => l.labelSibling,
      'partner' => l.labelPartner,
      'friend' => l.labelFriend,
      'assistant' => l.labelAssistant,
      'manager' => l.labelManager,
      'telegram' => l.labelTelegram,
      'skype' => l.labelSkype,
      'signal' => l.labelSignal,
      'facebook' => l.labelFacebook,
      'instagram' => l.labelInstagram,
      'linkedin' => l.labelLinkedin,
      'twitter' => l.labelTwitter,
      'whatsapp' => l.labelWhatsapp,
      'other' || '' || 'work' || 'home' => l.labelOther,
      _ => label,
    };
  }
  return phoneLabelText(l, label);
}

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
  const ContactAvatar({super.key, required this.summary, this.size = 40, this.showBadges = true, this.onHeader = false, this.fontSize});

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
    final scale = size / 40;
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
            decoration: BoxDecoration(color: avBg, shape: BoxShape.circle),
            child: photo != null
                ? Image.file(photo, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Text(initials, style: TextStyle(color: avFg, fontWeight: FontWeight.w600, fontSize: fontSize ?? (size >= 64 ? AppFont.lead : AppFont.badge))))
                : Text(
                    initials,
                    style: TextStyle(color: avFg, fontWeight: FontWeight.w600, fontSize: fontSize ?? (size >= 64 ? AppFont.lead : AppFont.badge)),
                  ),
          ),
          if (showBadges && ratingFromName(summary.contact.rating) != Rating.none)
            PositionedDirectional(
              end: -3 * scale,
              bottom: -3 * scale,
              child: Container(
                width: 18 * scale,
                height: 18 * scale,
                decoration: BoxDecoration(
                  color: ratingBg(p, ratingFromName(summary.contact.rating)),
                  shape: BoxShape.circle,
                  border: Border.all(color: p.glass, width: 2),
                ),
                child: Icon(ratingIcon(ratingFromName(summary.contact.rating)), size: AppIcon.sm * scale, color: ratingFg(p, ratingFromName(summary.contact.rating))),
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
                  color: p.noteDot,
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
