import 'package:flutter/material.dart';

import '../../core/text_normalize.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';

const tagColors = [
  Color(0xFF0B6E5E),
  Color(0xFF8FBF5A),
  Color(0xFFD9B13B),
  Color(0xFF8A9A92),
  Color(0xFF8A63D2),
  Color(0xFF2F7BD9),
  Color(0xFFD9822B),
  Color(0xFFC2547A),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(l.tagsTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            ),
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
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (canCreate)
                    ListTile(
                      leading: Icon(Icons.add, color: p.primary),
                      title: Text('"$q"'),
                      onTap: () => setSheet(() {
                        all.add(q);
                        selected.add(q);
                        search.clear();
                      }),
                    ),
                  for (final t in visible)
                    InkWell(
                      onTap: () => setSheet(() => selected.contains(t) ? selected.remove(t) : selected.add(t)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                        child: Row(children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: selected.contains(t) ? p.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: selected.contains(t) ? p.primary : p.outline, width: 2),
                            ),
                            child: selected.contains(t) ? Icon(Icons.check, size: 16, color: p.onPrimary) : null,
                          ),
                          const SizedBox(width: 14),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: tagColors[all.indexOf(t) % tagColors.length], shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(t, style: const TextStyle(fontSize: 16))),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: PillButton(label: l.cancel, outlined: true, onPressed: () => Navigator.of(ctx).pop())),
              const SizedBox(width: 12),
              Expanded(
                child: PillButton(
                  label: l.done,
                  onPressed: () => Navigator.of(ctx).pop(all.where(selected.contains).toList()),
                ),
              ),
            ]),
          ],
        );
      },
    ),
  ).whenComplete(search.dispose);
}
