import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

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
import '../settings/settings_widgets.dart' show SettingsRow, SettingsGroup;
import '../schedule/schedule_labels.dart';
import '../contacts/contact_details_page.dart';
import '../contacts/contact_widgets.dart' show initialsOf;
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import '../../core/format.dart';
import 'deal_form_page.dart';
import 'deal_document_dialog.dart';
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
  String _company = '';

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
    final contact = item == null ? null : await widget.contacts.get(item.deal.contactId);
    if (!mounted) return;
    setState(() {
      _company = contact?.contact.company ?? '';
      _item = item;
      _history = h;
      _docs = d;
      _loaded = true;
    });
  }

  Future<void> _edit() async {
    await Navigator.of(context).push<int>(MaterialPageRoute(
      builder: (_) => DealFormPage(deals: widget.deals, contacts: widget.contacts, fields: widget.fields, id: widget.id),
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
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.delete, onPressed: () => Navigator.of(ctx).pop(true), danger: true),
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
    final s = await pickStage(context, stages, current: _item?.stage.id, title: AppLocalizations.of(context).moveToStage, radio: true, footnote: AppLocalizations.of(context).moveFootnote);
    if (s != null) await widget.deals.moveDeal(widget.id, s.id);
  }

  Future<void> _reopen() async {
    final stages = await widget.deals.openStages();
    if (!mounted) return;
    final s = await showReopenSheet(context, stages);
    if (s != null) await widget.deals.moveDeal(widget.id, s.id);
  }

  Future<void> _won() async {
    final l = AppLocalizations.of(context);
    final item = _item!;
    final amount = TextEditingController(
        text: item.deal.amount == null ? '' : (item.deal.amount == item.deal.amount!.roundToDouble() ? item.deal.amount!.toStringAsFixed(0) : '${item.deal.amount}'));
    var date = DateTime.now();
    var currency = item.deal.currency;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l.markWon),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l.wonSub(item.deal.title, item.contactName)),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 170, child: GlassField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), label: l.finalAmount)),
                const SizedBox(width: 10),
                Expanded(
                  flex: 130,
                  child: GlassSelectField(
                    label: l.fieldCurrency,
                    value: currency,
                    onTap: () async {
                      final v = await showGlassSheet<String>(
                        ctx,
                        builder: (c2) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          SheetTitle(l.fieldCurrency),
                          for (final (i, code) in pickableCurrencyCodes(keep: currency).indexed) SheetItem(first: i == 0, title: code, bold: code == currency, selected: code == currency, onTap: () => Navigator.of(c2).pop(code)),
                        ]),
                      );
                      if (v != null) setS(() => currency = v);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              GlassSelectField(
                label: l.closedOn,
                value: formatDay(ctx, date),
                trailing: const Icon(Icons.calendar_today_outlined, size: 22),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setS(() => date = d);
                },
              ),
            ]),
          ),
          actions: [
            DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
            DialogConfirm(l.markWonBtn, onPressed: () => Navigator.of(ctx).pop(true)),
          ],
        ),
      ),
    );
    final text = amount.text.trim().replaceAll(',', '');
    if (ok == true) await widget.deals.winDeal(widget.id, finalAmount: text.isEmpty ? null : double.tryParse(text), date: date, currency: currency);
  }

  Future<void> _lost() async {
    final l = AppLocalizations.of(context);
    final item = _item!;
    var reason = lostReasonKeys.first;
    final note = TextEditingController();
    final ok = await showGlassSheet<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SheetTitle(l.lostSheetTitle),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text('${item.deal.title} · ${item.contactName}', style: TextStyle(fontSize: 15, height: 29 / 15, color: ctx.palette.text2)),
            ),
            for (var i = 0; i < lostReasonKeys.length; i++)
              SheetItem(
                first: i == 0,
                vpad: 12.6,
                title: lostReasonLabel(l, lostReasonKeys[i]),
                bold: reason == lostReasonKeys[i],
                selected: reason == lostReasonKeys[i],
                onTap: () => setS(() => reason = lostReasonKeys[i]),
              ),
            if (reason == lostReasonKeys.last) Padding(padding: const EdgeInsets.only(top: 12), child: GlassField(controller: note, label: l.fieldLostNote, maxLines: 3)),
            const SizedBox(height: 16),
            PillButton(label: l.markLost, danger: true, onPressed: () => Navigator.of(ctx).pop(true)),
          ]),
        ),
      ),
    );
    if (ok == true) await widget.deals.loseDeal(widget.id, reason: reason, note: reason == lostReasonKeys.last ? note.text : '');
  }

  Future<void> _addDocument() async {
    final item = _item!;
    final d = await showDealDocumentDialog(context, currency: item.deal.currency);
    if (d == null) return;
    await widget.deals.saveDocument(widget.id,
        reference: d.reference, amount: d.amount, currency: item.deal.currency, date: d.date, path: d.path, name: d.name);
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
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Row(children: [
                        GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(item.deal.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: pal.onHeader)),
                        ),
                        GlassIconButton(icon: Icons.more_vert, onHeader: true, onTap: _menu),
                      ]),
                    ),
                    Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 40), children: _body(l, pal, item))),
                  ]),
      ),
    );
  }

  Future<void> _menu() async {
    final l = AppLocalizations.of(context);
    final act = await showGlassSheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetItem(first: true, icon: Icons.edit_outlined, title: l.edit, onTap: () => Navigator.of(ctx).pop('edit')),
        SheetItem(icon: Icons.attach_file, title: l.addDocument, onTap: () => Navigator.of(ctx).pop('doc')),
        SheetItem(icon: Icons.delete_outline, title: l.delete, danger: true, onTap: () => Navigator.of(ctx).pop('delete')),
      ]),
    );
    if (act == 'edit') {
      await _edit();
    } else if (act == 'doc') {
      await _addDocument();
    } else if (act == 'delete') {
      await _delete();
    }
  }

  Widget _stageSteps(AppLocalizations l, YoncaPalette pal) {
    final steps = <(DealStage, DateTime)>[];
    for (final h in _history.reversed) {
      if (steps.isEmpty && h.fromStage != null) steps.add((h.fromStage!, h.at));
      steps.add((h.toStage, h.at));
    }
    if (steps.isEmpty) return const SizedBox.shrink();
    final shown = steps.length > 3 ? steps.sublist(steps.length - 3) : steps;
    final locale = Localizations.localeOf(context).toString();
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 12),
      child: Row(children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) SizedBox(width: 26, child: Icon(Icons.chevron_right, size: 18, color: pal.text2)),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.5, horizontal: 4),
              decoration: BoxDecoration(
                color: i == shown.length - 1 ? pal.primary : pal.glass,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: [
                Text(stageLabel(l, shown[i].$1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, height: 17.5 / 12.5, fontWeight: FontWeight.w600, color: i == shown.length - 1 ? pal.onPrimary : pal.text)),
                Text(dfmt(DateFormat('d MMM', locale), shown[i].$2),
                    style: TextStyle(fontSize: 11.5, height: 15 / 11.5, color: i == shown.length - 1 ? pal.onPrimary.withValues(alpha: .85) : pal.text2)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _infoRow(IconData icon, String title, String? sub, YoncaPalette pal) => SettingsRow(icon: icon, title: title, subtitle: sub);

  List<Widget> _body(AppLocalizations l, YoncaPalette pal, DealItem item) {
    final d = item.deal;
    final locale = Localizations.localeOf(context).toString();
    final whole = d.amount != null && d.amount == d.amount!.roundToDouble();
    final amountText = d.amount == null ? null : (whole ? NumberFormat.decimalPattern(locale) : NumberFormat('#,##0.00', locale)).format(d.amount);
    final info = <Widget>[
      if (d.expectedClose != null)
        _infoRow(Icons.event_outlined, '${l.fieldExpectedClose} ${dfmt(DateFormat('d MMM', locale), d.expectedClose!)}',
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.6),
          decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(4)),
          child: Text(stageLabel(l, item.stage), style: const TextStyle(fontSize: 13, height: 17 / 13, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(height: 6),
      if (amountText == null)
        Text(l.noAmount, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: pal.text2))
      else
        Text.rich(
          TextSpan(children: [
            TextSpan(text: amountText, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600)),
            TextSpan(text: '  ${d.currency}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: pal.text2)),
          ]),
          style: TextStyle(height: 1.4, color: pal.text),
        ),
      if (item.pastClose)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.schedule, size: 16, color: pal.error),
            const SizedBox(width: 4),
            Text(l.pastClose, style: TextStyle(color: pal.error, fontWeight: FontWeight.w600)),
          ]),
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: pal.avBg, borderRadius: BorderRadius.circular(8)),
                    child: Text(initialsOf(item.contactName), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: pal.avFg)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.contactName, style: const TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w500)),
                      if (_company.trim().isNotEmpty && _company != item.contactName)
                        Text(_company, style: TextStyle(fontSize: 13, height: 18 / 13, color: pal.text2)),
                    ]),
                  ),
                  Icon(Icons.chevron_right, size: 22, color: pal.text),
                ]),
              ),
            ),
            for (final w in info) ...[Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: pal.separator), w],
          ]),
        ),
      ),
      if (widget.fields != null) FieldValuesCard(fields: widget.fields!, scope: FieldScope.deal, ownerId: widget.id),
      SectionLabel(l.documentsTitle, padding: const EdgeInsets.fromLTRB(0, 16, 0, 8)),
      if (_docs.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.noDocuments, style: TextStyle(color: pal.text2)))
      else
        SettingsGroup(children: [
          for (final doc in _docs)
            _DocPress(
              onLongPress: () => _deleteDoc(doc),
              child: SettingsRow(
              icon: Icons.description_outlined,
              title: doc.reference.isEmpty ? (doc.name.isEmpty ? l.documentsTitle : doc.name) : doc.reference,
              subtitle: [
                if (doc.amount != null) formatMoney(context, doc.amount!, doc.currency),
                dfmt(DateFormat('d MMM', locale), doc.date),
                if (doc.name.contains('.')) doc.name.split('.').last.toUpperCase(),
              ].join(' · '),
              chevron: true,
              onTap: doc.path == null ? null : () => _openDoc(doc),
            )),
        ]),
      const SizedBox(height: 20),
      if (item.isOpen)
        Row(children: [
          Expanded(child: PillButton(label: l.markLost, danger: true, onPressed: _lost)),
          const SizedBox(width: 10),
          Expanded(child: PillButton(label: l.markWon, onPressed: _won)),
        ])
      else
        PillButton(label: l.reopenDeal, outlined: true, onPressed: _reopen),
    ];
  }
}

class _DocPress extends StatelessWidget {
  const _DocPress({required this.child, required this.onLongPress});
  final Widget child;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) => GestureDetector(onLongPress: onLongPress, child: child);
}
