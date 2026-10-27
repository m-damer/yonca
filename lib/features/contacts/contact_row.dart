import 'package:flutter/material.dart';

import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import 'contact_widgets.dart';

/// One contact in the list (design `.item`): avatar, name with nickname, company line, role badge.
class ContactRow extends StatelessWidget {
  const ContactRow({super.key, required this.summary, required this.onTap, this.onLongPress, this.picked = false});
  final bool picked;
  final ContactSummary summary;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final c = summary.contact;
    final subtitle = summary.isIncomplete ? l.completeContact : c.company;
    final showCompany = !summary.isIncomplete && summary.displayName != c.company;
    final extra = summary.roles.length - 1;
    final rating = ratingFromName(c.rating);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Ink(
        color: picked ? p.primaryContainer : null,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            ContactAvatar(summary: summary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: summary.displayName),
                      if (c.nickname.trim().isNotEmpty)
                        TextSpan(
                          text: ' · ${c.nickname}',
                          style: TextStyle(color: p.text2, fontWeight: FontWeight.w400, fontSize: 13),
                        ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.4, color: p.text),
                  ),
                  if ((showCompany || summary.isIncomplete) && subtitle.trim().isNotEmpty)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, height: 1.4, color: p.text2)),
                ],
              ),
            ),
            // The design shows the role here; the rating lives on the avatar badge.
            if (summary.roles.isNotEmpty) ...[
              const SizedBox(width: 8),
              TagPill(roleLabel(l, summary.roles.first) + (extra > 0 ? ' +$extra' : '')),
            ] else if (rating != Rating.none) ...[
              const SizedBox(width: 8),
              TagPill(ratingLabel(l, rating), bg: ratingBg(p, rating), fg: ratingFg(p, rating)),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
