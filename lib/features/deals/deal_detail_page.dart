import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/app_database.dart';
import '../../data/contacts_repository.dart';
import '../../data/deals_repository.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../../data/fields_repository.dart';
import '../../domain/field_models.dart';
import '../fields/field_values.dart';
import '../schedule/schedule_labels.dart';
import '../contacts/contact_details_page.dart';
import '../contacts/contact_widgets.dart' show initialsOf;
import 'package:intl/intl.dart' show DateFormat;
import '../../core/format.dart';
import 'deal_form_page.dart';
import 'deal_widgets.dart';

/// Deal detail (design S19): facts, stage actions, history and documents.
/// Pops with true when the deal was deleted.
class DealDetailPage extends StatefulWidget {
  const DealDetailPage({super.key, required this.deals, required this.contacts, required this.id, this.fields});
  final FieldsRepository? fields;
  final DealsRepository deals;
  final ContactsRepository contacts;
  final int id;

  @override
  State<DealDetailPage> createState() => _DealDetailPageState();
}

class _DealDetailPageState extends State<DealDetailPage> {
  DealItem? _item;
  List<StageMove> _history = const [];
  List<DealDocument> _docs = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.deals.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.deals.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final item = await widget.deals.getDeal(widget.id);
    final h = await widget.deals.history(widget.id);
    final d = await widget.deals.documents(widget.id);
    if (!mounted) return;
    setState(() {
      _item = item;
      _history = h;
      _docs = d;
      _loaded = true;
    });
  }

  Future<void> _edit() async {
    await Navigator.of(context).push<int>(MaterialPageRoute(
      builder: (_) => DealFormPage(deals: widget.deals, contacts: widget.contacts, id: widget.id),
    ));
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteDealTitle),
        content: Text(l.deleteDealBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    final paths = await widget.deals.deleteDeal(widget.id);
    for (final path in paths) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    nav.pop(true);
  }

  Future<void> _move() async {
    final stages = await widget.deals.openStages();
    if (!mounted) return;
    final s = await pickStage(context, stages, current: _item?.stage.id, title: AppLocalizations.of(context).moveToStage);
    if (s != null) await widget.deals.moveDeal(widget.id, s.id);
  }

  Future<void> _reopen() async {
    final l = AppLocalizations.of(context);
    final stages = await widget.deals.openStages();
    if (!mounted) return;
    final s = await pickStage(context, stages, title: l.reopenToStage);
    if (s != null) await widget.deals.moveDeal(widget.id, s.id);
  }

  Future<void> _won() async {
    final l = AppLocalizations.of(context);
    final item = _item!;
    final amount = TextEditingController(
        text: item.deal.amount == null ? '' : (item.deal.amount == item.deal.amount!.roundToDouble() ? item.deal.amount!.toStringAsFixed(0) : '${item.deal.amount}'));
    var date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l.markWon),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '${l.finalAmount} (${item.deal.currency})'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.closedOn),
              subtitle: Text(formatDay(ctx, date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setS(() => date = d);
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.save)),
          ],
        ),
      ),
    );
    final text = amount.text.trim().replaceAll(',', '');
    if (ok == true) await widget.deals.winDeal(widget.id, finalAmount: text.isEmpty ? null : double.tryParse(text), date: date);
  }

  Future<void> _lost() async {
    final l = AppLocalizations.of(context);
    var reason = lostReasonKeys.first;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l.markLost),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.fieldLostReason, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in lostReasonKeys)
                  PillChip(label: lostReasonLabel(l, k), selected: reason == k, check: true, onTap: () => setS(() => reason = k)),
              ]),
              const SizedBox(height: 12),
              TextField(controller: note, decoration: InputDecoration(labelText: l.fieldLostNote), maxLines: 3),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok == true) await widget.deals.loseDeal(widget.id, reason: reason, note: note.text);
  }

  Future<void> _addDocument() async {
    final l = AppLocalizations.of(context);
    final item = _item!;
    final ref = TextEditingController();
    final amount = TextEditingController();
    var date = DateTime.now();
    String? path;
    var name = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l.addDocument),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: ref, decoration: InputDecoration(labelText: l.fieldReference)),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: '${l.fieldAmount} (${item.deal.currency})'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.fieldDocDate),
                subtitle: Text(formatDay(ctx, date)),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setS(() => date = d);
                },
              ),
              TextButton.icon(
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles();
                  final f = res?.files.single;
                  if (f?.path == null) return;
                  final dir = await getApplicationDocumentsDirectory();
                  final folder = Directory(p.join(dir.path, 'deal_files'))..createSync(recursive: true);
                  final dest = p.join(folder.path, '${DateTime.now().microsecondsSinceEpoch}_${f!.name}');
                  await File(f.path!).copy(dest);
                  setS(() {
                    path = dest;
                    name = f.name;
                  });
                },
                icon: const Icon(Icons.attach_file),
                label: Text(name.isEmpty ? l.addFile : name, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final text = amount.text.trim().replaceAll(',', '');
    await widget.deals.saveDocument(widget.id,
        reference: ref.text,
        amount: text.isEmpty ? null : double.tryParse(text),
        currency: item.deal.currency,
        date: date,
        path: path,
        name: name);
  }

  Future<void> _openDoc(DealDocument d) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).fileOpenFailed;
    if (d.path == null) return;
    final r = await OpenFilex.open(d.path!);
    if (r.type != ResultType.done) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  Future<void> _deleteDoc(DealDocument d) async {
    final path = await widget.deals.deleteDocument(d.id);
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final item = _item;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: !_loaded
            ? const SafeArea(child: LoadingView())
            : item == null
                ? SafeArea(child: EmptyState(icon: Icons.paid_outlined, title: l.noDealsYet))
                : Column(children: [
                    HeaderBand(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      child: Row(children: [
                        GlassIconButton(icon: Icons.arrow_back, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(item.deal.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: pal.onHeader)),
                        ),
                        GlassIconButton(icon: Icons.more_vert, onHeader: true, onTap: _menu),
                      ]),
                    ),
                    Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: _body(l, pal, item))),
                  ]),
      ),
      bottomNavigationBar: (!_loaded || item == null) ? null : _actionBar(l, pal, item),
    );
  }

  /// Fixed bar at the bottom: Mark as lost and Mark as won while open, Reopen once closed.
  Widget _actionBar(AppLocalizations l, YoncaPalette pal, DealItem item) {
    return Container(
      decoration: BoxDecoration(color: pal.glass, border: Border(top: BorderSide(color: pal.separator))),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      child: item.isOpen
          ? Row(children: [
              Expanded(child: PillButton(label: l.markLost, danger: true, onPressed: _lost)),
              const SizedBox(width: 10),
              Expanded(child: PillButton(label: l.markWon, onPressed: _won)),
            ])
          : PillButton(label: l.reopenDeal, outlined: true, onPressed: _reopen),
    );
  }

  Future<void> _menu() async {
    final l = AppLocalizations.of(context);
    final act = await showGlassSheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.edit), onTap: () => Navigator.of(ctx).pop('edit')),
        ListTile(leading: Icon(Icons.delete_outline, color: ctx.palette.error), title: Text(l.delete), onTap: () => Navigator.of(ctx).pop('delete')),
      ]),
    );
    if (act == 'edit') {
      await _edit();
    } else if (act == 'delete') {
      await _delete();
    }
  }

  Widget _stageSteps(AppLocalizations l, YoncaPalette pal) {
    final steps = <(DealStage, DateTime)>[];
    for (final h in _history) {
      if (steps.isEmpty && h.fromStage != null) steps.add((h.fromStage!, h.at));
      steps.add((h.toStage, h.at));
    }
    if (steps.isEmpty) return const SizedBox.shrink();
    final shown = steps.length > 4 ? steps.sublist(steps.length - 4) : steps;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Icon(Icons.chevron_right, size: 18, color: pal.text2)),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: i == shown.length - 1 ? pal.primary : pal.glass,
                borderRadius: BorderRadius.circular(8),
                border: i == shown.length - 1 ? null : Border.all(color: pal.glassBorder),
              ),
              child: Column(children: [
                Text(stageLabel(l, shown[i].$1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: i == shown.length - 1 ? pal.onPrimary : pal.text)),
                const SizedBox(height: 2),
                Text(dfmt(DateFormat.MMMd(Localizations.localeOf(context).toString()), shown[i].$2),
                    style: TextStyle(fontSize: 11, color: i == shown.length - 1 ? pal.onPrimary.withValues(alpha: .85) : pal.text2)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _infoRow(IconData icon, String title, String? sub, YoncaPalette pal) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: pal.primaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 22, color: pal.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              if (sub != null) Text(sub, style: TextStyle(fontSize: 12.5, color: pal.text2)),
            ]),
          ),
        ]),
      );

  List<Widget> _body(AppLocalizations l, YoncaPalette pal, DealItem item) {
    final d = item.deal;
    final tint = stageTintColor(context, item.stage.tint);
    final money = d.amount == null ? null : formatMoney(context, d.amount!, d.currency);
    final info = <Widget>[
      if (d.expectedClose != null)
        _infoRow(Icons.event_outlined, '${l.fieldExpectedClose} ${dfmt(DateFormat.MMMd(Localizations.localeOf(context).toString()), d.expectedClose!)}',
            item.isOpen ? l.daysInStage(item.daysInStage) : null, pal),
      if (!item.isOpen && d.closedAt != null) _infoRow(Icons.event_available_outlined, '${l.closedOn} ${formatDay(context, d.closedAt!)}', null, pal),
      if (item.kind == StageKind.lost && d.lostReason.isNotEmpty)
        _infoRow(Icons.thumb_down_alt_outlined, '${l.fieldLostReason}: ${lostReasonLabel(l, d.lostReason)}', d.lostNote.isEmpty ? null : d.lostNote, pal),
      if (d.description.isNotEmpty) _infoRow(Icons.description_outlined, d.description, null, pal),
    ];
    return [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(8)),
          child: Text(stageLabel(l, item.stage), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(height: 10),
      if (money == null)
        Text(l.noAmount, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: pal.text2))
      else
        Text(money, style: TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w700, color: pal.text)),
      if (item.pastClose)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.schedule, size: 16, color: pal.error),
            const SizedBox(width: 4),
            Text(l.pastClose, style: TextStyle(color: pal.error, fontWeight: FontWeight.w600)),
          ]),
        ),
      const SizedBox(height: 14),
      _stageSteps(l, pal),
      if (item.isOpen) ...[
        PillButton(label: l.moveToStage, icon: Icons.swap_horiz, outlined: true, height: 48, onPressed: _move),
        const SizedBox(height: 12),
      ],
      GlassCard(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: Column(children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ContactDetailsPage(repo: widget.contacts, id: d.contactId))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: pal.avBg, borderRadius: BorderRadius.circular(8)),
                    child: Text(initialsOf(item.contactName), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: pal.avFg)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item.contactName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                  Icon(Icons.chevron_right, color: pal.text2),
                ]),
              ),
            ),
            for (final w in info) ...[Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: pal.separator), w],
          ]),
        ),
      ),
      if (widget.fields != null) FieldValuesCard(fields: widget.fields!, scope: FieldScope.deal, ownerId: widget.id),
      SectionLabel(l.documentsTitle),
      if (_docs.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l.noDocuments, style: TextStyle(color: pal.text2))),
      for (final doc in _docs)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.description_outlined, color: pal.primary),
          title: Text(doc.reference.isEmpty ? (doc.name.isEmpty ? l.documentsTitle : doc.name) : doc.reference),
          subtitle: Text([formatDay(context, doc.date), if (doc.amount != null) formatMoney(context, doc.amount!, doc.currency)].join(' · ')),
          onTap: doc.path == null ? null : () => _openDoc(doc),
          trailing: IconButton(icon: Icon(Icons.remove_circle_outline, color: pal.error.withValues(alpha: .8)), onPressed: () => _deleteDoc(doc)),
        ),
      PillButton(label: l.addDocument, outlined: true, height: 48, onPressed: _addDocument),
    ];
  }
}
