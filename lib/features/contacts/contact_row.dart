import 'package:flutter/material.dart';

import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import 'contact_widgets.dart';
import '../../theme/tokens.dart';

/// One contact in the list (design `.item`): avatar, name with nickname, company line, role badge.
class ContactRow extends StatelessWidget {
  const ContactRow({super.key, required this.summary, required this.onTap, this.onLongPress, this.picked = false, this.outlined = false});
  final bool picked;

  /// Blue outline while its press-and-hold menu is open.
  final bool outlined;
  final ContactSummary summary;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final c = summary.contact;
    final extra = summary.roles.length - 1;
    // Line 2: position and department; line 3: company. A line without data is left out.
    final role = [c.jobTitle.trim(), c.department.trim()].where((x) => x.isNotEmpty).join(' · ');
    final company = summary.displayName == c.company ? '' : c.company.trim();
    final lines = <String>[
      if (summary.isIncomplete) l.completeContact else ...[if (role.isNotEmpty) role, if (company.isNotEmpty) company],
    ];
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(border: outlined ? Border.all(color: p.primary, width: 2) : null, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Ink(
        color: picked ? p.primaryContainer : null,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
        child: Row(
          children: [
            ContactAvatar(summary: summary, size: 40, fontSize: AppFont.label),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: summary.displayName),
                      if (c.nickname.trim().isNotEmpty)
                        TextSpan(
                          text: ' · ${c.nickname}',
                          style: TextStyle(color: p.text2, fontWeight: FontWeight.w400, fontSize: AppFont.meta),
                        ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w500, height: AppLine.normal, color: p.text),
                      ),
                    ),
                    // The role is colour coded and sits on the name row, so the lines below keep the full width.
                    if (summary.roles.isNotEmpty) ...[
                      const SizedBox(width: AppSpace.sm),
                      TagPill(roleShortLabel(l, summary.roles.first) + (extra > 0 ? ' +$extra' : ''), bg: roleBg(p, summary.roles.first), fg: roleFg(p, summary.roles.first)),
                    ],
                  ]),
                  for (final line in lines)
                    Text(line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }
}
