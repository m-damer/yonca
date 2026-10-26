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
import '../schedule/schedule_labels.dart';
import 'deal_form_page.dart';
import 'deal_widgets.dart';

/// Deal detail (design S19): facts, stage actions, history and documents.
/// Pops with true when the deal was deleted.
class DealDetailPage extends StatefulWidget {
  const DealDetailPage({super.key, required this.deals, required this.contacts, required this.id});
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
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: pal.onHeader)),
                        ),
                        GlassIconButton(icon: Icons.edit_outlined, onHeader: true, onTap: _edit),
                        const SizedBox(width: 8),
                        GlassIconButton(icon: Icons.delete_outline, onHeader: true, onTap: _delete),
                      ]),
                    ),
                    Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: _body(l, pal, item))),
                  ]),
      ),
    );
  }

  List<Widget> _body(AppLocalizations l, YoncaPalette pal, DealItem item) {
    final d = item.deal;
    return [
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.amount == null ? l.noAmount : formatMoney(context, d.amount!, d.currency),
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: d.amount == null ? pal.text2 : pal.primary)),
          const SizedBox(height: 6),
          Text(item.contactName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: stageTintColor(context, item.stage.tint), borderRadius: BorderRadius.circular(20)),
            child: Text(stageLabel(l, item.stage), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (d.expectedClose != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('${l.fieldExpectedClose}: ${formatDay(context, d.expectedClose!)}', style: TextStyle(color: pal.text2)),
            ),
          if (item.pastClose)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule, size: 16, color: pal.error),
                const SizedBox(width: 4),
                Text(l.pastClose, style: TextStyle(color: pal.error, fontWeight: FontWeight.w600)),
              ]),
            ),
          if (item.isOpen)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.daysInStage(item.daysInStage), style: TextStyle(color: pal.text2))),
          if (!item.isOpen && d.closedAt != null)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('${l.closedOn} ${formatDay(context, d.closedAt!)}', style: TextStyle(color: pal.text2))),
          if (item.kind == StageKind.lost && d.lostReason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${l.fieldLostReason}: ${lostReasonLabel(l, d.lostReason)}${d.lostNote.isEmpty ? '' : ' · ${d.lostNote}'}'),
            ),
          if (d.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(d.description)),
        ]),
      ),
      const SizedBox(height: 12),
      if (item.isOpen) ...[
        PillButton(label: l.moveToStage, outlined: true, height: 50, onPressed: _move),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: PillButton(label: l.markWon, height: 50, onPressed: _won)),
          const SizedBox(width: 8),
          Expanded(child: PillButton(label: l.markLost, outlined: true, height: 50, onPressed: _lost)),
        ]),
      ] else
        PillButton(label: l.reopenDeal, outlined: true, height: 50, onPressed: _reopen),
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
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(onPressed: _addDocument, icon: const Icon(Icons.add), label: Text(l.addDocument)),
      ),
      SectionLabel(l.stageHistory),
      for (final h in _history)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
              child: Text(h.fromStage == null
                  ? l.dealStarted(stageLabel(l, h.toStage))
                  : l.dealMoved(stageLabel(l, h.fromStage!), stageLabel(l, h.toStage))),
            ),
            Text(formatDay(context, h.at), style: TextStyle(color: pal.text2, fontSize: 13)),
          ]),
        ),
    ];
  }
}
