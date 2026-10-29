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
  bool _searching = false;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

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
        _tags = [...t]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _counts = c;
      });
    }
  }

  Future<void> _add() async {
    final r = await showTagSheet(context, title: AppLocalizations.of(context).newTag, name: '', colour: _tags.length % tagColors.length);
    if (r == null || r.name.isEmpty) return;
    await widget.repo.addTag(r.name, r.colour);
    await _load();
  }

  Future<void> _open(Tag t) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TagContactsPage(repo: widget.repo, tag: t, others: [for (final x in _tags) if (x.id != t.id) x])));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final q = _query.text.trim().toLowerCase();
    final shown = [for (final t in _tags) if (q.isEmpty || t.name.toLowerCase().contains(q)) t];
    return Stack(children: [
      SettingsScaffold(
        title: l.tagsTitle,
        actions: [
          GlassIconButton(
            icon: _searching ? Icons.close : Icons.search,
            onHeader: true,
            onTap: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query.clear();
            }),
          ),
        ],
        children: [
          if (_searching)
            Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: SearchPill(controller: _query, hint: l.tagsSearch, autofocus: true, onChanged: (_) => setState(() {})))
          else
            Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 10), child: Text(l.tagsHint2, style: TextStyle(fontSize: 15, height: 21 / 15, color: p.text2))),
          SettingsGroup(children: [
            for (final t in shown)
              SettingsRow(
                vpad: 12,
                title: t.name,
                chevron: true,
                leadingWidget: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: tagColors[t.colorIndex % tagColors.length],
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  height: 20.8,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(4)),
                  child: Text('${_counts[t.id] ?? 0}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.text)),
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

/// What the tag sheet hands back.
class TagSheetResult {
  const TagSheetResult({required this.name, required this.colour, this.merge = false});
  final String name;
  final int colour;

  /// The person chose "Merge into…" instead of Save.
  final bool merge;
}

/// New tag / Edit tag sheet (design O2, WK14): a name and one of 12 colours. [withMerge] swaps Cancel for Merge into….
Future<TagSheetResult?> showTagSheet(BuildContext context, {required String title, required String name, required int colour, bool withMerge = false, String? error}) {
  final l = AppLocalizations.of(context);
  final ctl = TextEditingController(text: name);
  var pick = colour;
  var err = error;
  return showGlassSheet<TagSheetResult>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(title),
          GlassField(controller: ctl, label: l.tagNameLabel, autofocus: true, error: err, onChanged: (_) => setS(() => err = null)),
          SectionLabel(l.tagColourLabel, padding: const EdgeInsets.fromLTRB(0, 16, 0, 8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.8),
            child: Column(children: [
              for (var row = 0; row < 2; row++) ...[
                if (row > 0) const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  for (var i = row * 6; i < row * 6 + 6; i++)
                    GestureDetector(
                      onTap: () => setS(() => pick = i),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: tagColors[i], shape: BoxShape.circle),
                        child: pick == i ? const Icon(Icons.check, size: 20, color: Color(0xFF1C1C1E)) : null,
                      ),
                    ),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          if (withMerge)
            Row(children: [
              Expanded(child: PillButton(label: l.mergeInto, outlined: true, onPressed: () => Navigator.of(ctx).pop(TagSheetResult(name: ctl.text.trim(), colour: pick, merge: true)))),
              const SizedBox(width: 10),
              Expanded(child: PillButton(label: l.save, onPressed: () => Navigator.of(ctx).pop(TagSheetResult(name: ctl.text.trim(), colour: pick)))),
            ])
          else
            SheetButtons(
              secondary: l.cancel,
              onSecondary: () => Navigator.of(ctx).pop(),
              primary: l.save,
              onPrimary: () => Navigator.of(ctx).pop(TagSheetResult(name: ctl.text.trim(), colour: pick)),
            ),
        ]),
      ),
    ),
  );
}

/// Merge sheet (design WK15): pick the tag the contacts move to.
Future<Tag?> showMergeTagSheet(BuildContext context, {required Tag from, required int count, required List<Tag> others}) {
  final l = AppLocalizations.of(context);
  Tag? chosen = others.isEmpty ? null : others.first;
  return showGlassSheet<Tag>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.mergeTagTitle(from.name)),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(l.mergeTagBody(count, from.name), style: TextStyle(fontSize: 15, height: 25 / 15, color: ctx.palette.text2)),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 4.5 * 52),
          child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
            for (var i = 0; i < others.length; i++)
              SheetItem(
                first: i == 0,
                title: others[i].name,
                bold: chosen?.id == others[i].id,
                selected: chosen?.id == others[i].id,
                onTap: () => setS(() => chosen = others[i]),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        SheetButtons(secondary: l.cancel, onSecondary: () => Navigator.of(ctx).pop(), primary: l.mergeBtn, onPrimary: chosen == null ? null : () => Navigator.of(ctx).pop(chosen)),
      ]),
    ),
  );
}

/// Contacts with one tag (design WK13), with Edit and Remove.
class TagContactsPage extends StatefulWidget {
  const TagContactsPage({super.key, required this.repo, required this.tag, required this.others});
  final ContactsRepository repo;
  final Tag tag;
  final List<Tag> others;

  @override
  State<TagContactsPage> createState() => _TagContactsPageState();
}

class _TagContactsPageState extends State<TagContactsPage> {
  late Tag _tag = widget.tag;
  List<ContactSummary> _list = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.repo.list(tagId: _tag.id);
    if (mounted) {
      setState(() {
        _list = list;
        _loaded = true;
      });
    }
  }

  Future<void> _edit() async {
    final l = AppLocalizations.of(context);
    String? error;
    while (true) {
      // ignore: use_build_context_synchronously
      final r = await showTagSheet(context, title: l.editTag, name: _tag.name, colour: _tag.colorIndex % tagColors.length, withMerge: widget.others.isNotEmpty, error: error);
      if (r == null || !mounted) return;
      if (r.merge) {
        final into = await showMergeTagSheet(context, from: _tag, count: _list.length, others: widget.others);
        if (into == null || !mounted) return;
        await widget.repo.mergeTag(_tag.id, into.id);
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (r.name.isEmpty) return;
      try {
        await widget.repo.updateTag(_tag.id, name: r.name, colorIndex: r.colour);
      } on TagExistsException {
        error = l.tagExists;
        continue;
      }
      final fresh = (await widget.repo.allTags()).firstWhere((t) => t.id == _tag.id);
      if (mounted) setState(() => _tag = fresh);
      return;
    }
  }

  Future<void> _remove() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.removeTagTitle(_list.length)),
        content: Text(l.removeTagBody(_tag.name)),
        actions: [
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.removeBtn, onPressed: () => Navigator.of(ctx).pop(true), danger: true),
        ],
      ),
    );
    if (ok != true) return;
    await widget.repo.deleteTag(_tag.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return SettingsScaffold(
      title: _tag.name,
      actions: [
        GlassIconButton(icon: Icons.edit_outlined, onHeader: true, tooltip: l.editTag, onTap: _edit),
        GlassIconButton(icon: Icons.delete_outline, onHeader: true, tooltip: l.removeBtn, onTap: _remove),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Row(children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: tagColors[_tag.colorIndex % tagColors.length], shape: BoxShape.circle, border: Border.all(color: const Color(0x1A000000))),
            ),
            const SizedBox(width: 10),
            Text(l.contactsCount(_list.length), style: TextStyle(fontSize: 15, color: p.text2)),
          ]),
        ),
        if (_loaded && _list.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(l.noTagContacts, textAlign: TextAlign.center)),
        if (_list.isNotEmpty)
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final s in _list)
                ContactRow(
                  summary: s,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ContactDetailsPage(repo: widget.repo, id: s.contact.id))),
                ),
            ]),
          ),
      ],
    );
  }
}
