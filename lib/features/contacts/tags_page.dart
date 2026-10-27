import 'package:flutter/material.dart';

import '../../data/app_database.dart' show Tag;
import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../settings/settings_widgets.dart';
import 'contact_details_page.dart';
import 'contact_row.dart';
import 'tags_sheet.dart';

/// Tags (design Org Tags): every tag with its contact count; tap one to see its contacts, add with New tag.
class TagsPage extends StatefulWidget {
  const TagsPage({super.key, required this.repo});
  final ContactsRepository repo;

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  List<Tag> _tags = const [];
  Map<int, int> _counts = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await widget.repo.allTags();
    final c = await widget.repo.tagCounts();
    if (mounted) {
      setState(() {
        _tags = t;
        _counts = c;
      });
    }
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final name = TextEditingController();
    var colour = _tags.length % tagColors.length;
    final ok = await showGlassSheet<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 12), child: Text(l.newTag, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
            GlassField(controller: name, label: l.tagNameLabel, autofocus: true),
            const SizedBox(height: 16),
            SectionLabel(l.tagColourLabel),
            Wrap(spacing: 14, runSpacing: 12, children: [
              for (var i = 0; i < tagColors.length; i++)
                GestureDetector(
                  onTap: () => setSheet(() => colour = i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tagColors[i],
                      shape: BoxShape.circle,
                      border: colour == i ? Border.all(color: ctx.palette.text, width: 2.5) : null,
                    ),
                    child: colour == i ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                  ),
                ),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: PillButton(label: l.cancel, outlined: true, height: 52, onPressed: () => Navigator.of(ctx).pop(false))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: PillButton(label: l.save, height: 52, onPressed: () => Navigator.of(ctx).pop(true))),
            ]),
          ],
        ),
      ),
    );
    final text = name.text.trim();
    if (ok == true && text.isNotEmpty) {
      await widget.repo.addTag(text, colour);
      await _load();
    }
  }

  Future<void> _open(Tag t) async {
    final list = await widget.repo.list(tagId: t.id);
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SettingsScaffold(
        title: t.name,
        children: [
          if (list.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(l.noTagContacts, textAlign: TextAlign.center)),
          if (list.isNotEmpty)
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final s in list)
                  ContactRow(
                    summary: s,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ContactDetailsPage(repo: widget.repo, id: s.contact.id))),
                  ),
              ]),
            ),
        ],
      ),
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return Stack(children: [
      SettingsScaffold(
        title: l.tagsTitle,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 12), child: Text(l.tagsHint2, style: TextStyle(color: p.text2))),
          SettingsGroup(children: [
            for (final t in _tags)
              SettingsRow(
                title: t.name,
                chevron: true,
                leadingWidget: Container(width: 24, height: 24, decoration: BoxDecoration(color: tagColors[t.colorIndex % tagColors.length], shape: BoxShape.circle)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(10)),
                  child: Text('${_counts[t.id] ?? 0}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.onPrimaryContainer)),
                ),
                onTap: () => _open(t),
              ),
          ]),
        ],
      ),
      PositionedDirectional(
        end: 20,
        bottom: 28,
        child: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: Text(l.newTag)),
      ),
    ]);
  }
}
