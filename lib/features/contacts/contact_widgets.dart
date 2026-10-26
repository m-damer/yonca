import 'package:flutter/material.dart';

import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/palette.dart';

Color ratingColor(Rating r) => switch (r) {
      Rating.hot => const Color(0xFFD9442B),
      Rating.warm => const Color(0xFFE59A12),
      Rating.cold => const Color(0xFF2F7BD9),
      Rating.none => const Color(0xFF7B8B83),
    };

IconData ratingIcon(Rating r) => switch (r) {
      Rating.hot => Icons.local_fire_department,
      Rating.warm => Icons.wb_sunny,
      Rating.cold => Icons.ac_unit,
      Rating.none => Icons.remove,
    };

String ratingLabel(AppLocalizations l, Rating r) => switch (r) {
      Rating.hot => l.ratingHot,
      Rating.warm => l.ratingWarm,
      Rating.cold => l.ratingCold,
      Rating.none => l.ratingAll,
    };

String roleLabel(AppLocalizations l, Role r) => switch (r) {
      Role.lead => l.roleLead,
      Role.client => l.roleClient,
      Role.supplier => l.roleSupplier,
    };

/// Round photo-or-initial avatar; shows a rating icon on its corner when [showRating] is set.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.summary, this.size = 46, this.showRating = false});
  final ContactSummary summary;
  final double size;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = summary.displayName.trim();
    final initial = name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();
    final rating = ratingFromName(summary.contact.rating);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: p.primaryContainer,
            child: Text(initial,
                style: TextStyle(color: p.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: size * .4)),
          ),
          if (showRating && rating != Rating.none)
            PositionedDirectional(
              end: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: p.sheet, shape: BoxShape.circle),
                child: Icon(ratingIcon(rating), size: 13, color: ratingColor(rating)),
              ),
            ),
        ],
      ),
    );
  }
}
