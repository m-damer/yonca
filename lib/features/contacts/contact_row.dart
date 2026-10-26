import 'package:flutter/material.dart';

import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/palette.dart';
import 'contact_widgets.dart';

/// One contact in the list: avatar, name, nickname/company line, role badge, note dot.
class ContactRow extends StatelessWidget {
  const ContactRow({super.key, required this.summary, required this.showRating, required this.onTap});
  final ContactSummary summary;
  final bool showRating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final c = summary.contact;
    final sub = [c.nickname, if (summary.displayName != c.company) c.company]
        .where((s) => s.trim().isNotEmpty)
        .join(' · ');
    final extra = summary.roles.length - 1;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: contactCardHeight(context) - 2,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ContactAvatar(summary: summary, showRating: showRating),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(summary.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (sub.isNotEmpty)
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text2)),
                ],
              ),
            ),
            if (c.temporaryNote.trim().isNotEmpty)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsetsDirectional.only(end: 8),
                decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
              ),
            if (summary.roles.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  roleLabel(l, summary.roles.first) + (extra > 0 ? ' +$extra' : ''),
                  style: TextStyle(color: p.onPrimaryContainer, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
