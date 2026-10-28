import 'package:flutter/material.dart';

import '../../core/text_normalize.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';

const tagColors = [
  Color(0xFFF4B8B0),
  Color(0xFFF6CFA3),
  Color(0xFFF3E3A0),
  Color(0xFFC9E4A8),
  Color(0xFFA8DDC4),
  Color(0xFFA5DDE0),
  Color(0xFFA8C8F0),
  Color(0xFFC3BCF0),
  Color(0xFFE0B8EC),
  Color(0xFFF0B6D2),
  Color(0xFFCFC2B2),
  Color(0xFFB9C6CE),
];

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
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: p.glass,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.glassBorder),
              ),
              child: Row(children: [
                Icon(Icons.search, color: p.text2),
                const SizedBox(width: 10),
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
            const SizedBox(height: 8),
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
                      leading: Icon(Icons.add, color: p.primary, size: 24),
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
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: selected.contains(t) ? p.primary : sheetLine(ctx), width: 2),
                          ),
                          child: selected.contains(t) ? Icon(Icons.check, size: 16, color: p.onPrimary) : null,
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(color: tagColors[all.indexOf(t) % tagColors.length], shape: BoxShape.circle),
                        ),
                      ]),
                      title: t,
                      onTap: () => setSheet(() => selected.contains(t) ? selected.remove(t) : selected.add(t)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
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
