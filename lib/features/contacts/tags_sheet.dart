import 'package:flutter/material.dart';

import '../../core/text_normalize.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

/// Tag picker (design Cf tags sheet): search or create, tick to choose, Cancel and Done.
/// [known] are all existing tag names; returns the chosen names, or null on Cancel.
Future<List<String>?> showTagsSheet(BuildContext context, {required List<String> known, required List<String> chosen}) {
  final l = AppLocalizations.of(context);
  final selected = {...chosen};
  final all = <String>[...known];
  for (final c in chosen) {
    if (!all.any((k) => normalizeText(k) == normalizeText(c))) all.add(c);
  }
  final search = TextEditingController();
  return showGlassSheet<List<String>>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final p = ctx.palette;
        final q = search.text.trim();
        final key = normalizeText(q);
        final visible = all.where((t) => key.isEmpty || normalizeText(t).contains(key)).toList();
        final canCreate = q.isNotEmpty && !all.any((t) => normalizeText(t) == key);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(l.tagsTitle),
            Container(
              height: AppControl.lg,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              decoration: BoxDecoration(
                color: p.glass,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: p.glassBorder),
              ),
              child: Row(children: [
                Icon(Lu.search, color: p.text2),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: TextField(
                    controller: search,
                    onChanged: (_) => setSheet(() {}),
                    cursorColor: p.primary,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: l.tagsSearch,
                      hintStyle: TextStyle(color: p.text2),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 5 * 48),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  if (canCreate)
                    SheetItem(
                      first: true,
                      vpad: 12,
                      leading: Icon(Lu.plus, color: p.primary, size: AppIcon.lg),
                      title: '"$q"',
                      onTap: () => setSheet(() {
                        all.add(q);
                        selected.add(q);
                        search.clear();
                      }),
                    ),
                  for (final t in visible)
                    SheetItem(
                      first: true,
                      vpad: 12,
                      leading: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: selected.contains(t) ? p.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: selected.contains(t) ? p.primary : sheetLine(ctx), width: 2),
                          ),
                          child: selected.contains(t) ? Icon(Lu.check, size: AppIcon.sm, color: p.onPrimary) : null,
                        ),
                        const SizedBox(width: AppSpace.md),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(color: AppTint.tags[all.indexOf(t) % AppTint.tags.length], shape: BoxShape.circle),
                        ),
                      ]),
                      title: t,
                      onTap: () => setSheet(() => selected.contains(t) ? selected.remove(t) : selected.add(t)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            SheetButtons(
              secondary: l.cancel,
              onSecondary: () => Navigator.of(ctx).pop(),
              primary: l.done,
              onPrimary: () => Navigator.of(ctx).pop(all.where(selected.contains).toList()),
            ),
          ],
        );
      },
    ),
  ).whenComplete(search.dispose);
}
