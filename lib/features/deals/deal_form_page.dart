import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../data/app_database.dart';
import '../../data/contacts_repository.dart';
import '../../data/deals_repository.dart';
import '../../domain/deal_models.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../activities/contact_picker.dart';
import '../../data/fields_repository.dart';
import '../../domain/field_models.dart';
import '../fields/field_values.dart';
import '../settings/settings_widgets.dart' show SettingsGroup, SettingsRow;
import 'deal_document_dialog.dart';
import 'deal_widgets.dart';

/// New or edit deal. [contactId] pre-fills (and locks) the contact; [stageId] pre-selects the stage.
/// Pops with the deal id, or -1 when deleted.
class DealFormPage extends StatefulWidget {
  const DealFormPage({super.key, required this.deals, required this.contacts, this.fields, this.contactId, this.stageId, this.id});
  final FieldsRepository? fields;
  final DealsRepository deals;
  final ContactsRepository contacts;
  final int? contactId;
  final int? stageId;
  final int? id;

  @override
  State<DealFormPage> createState() => _DealFormPageState();
}

class _DealFormPageState extends State<DealFormPage> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  int? _contactId;
  String _contactName = '';
  String _currency = defaultDealCurrency;
  int? _stageId;
  DateTime? _close;
  List<DealStage> _stages = const [];
  bool _loading = true;
  bool _saving = false;
  String? _problem;
  String _initial = '';
  final _inputs = GlobalKey<FieldInputsState>();
  var _docs = <DocDraft>[];
  final _removedDocs = <DocDraft>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _stages = await widget.deals.openStages();
    final id = widget.id;
    if (id != null) {
      final item = await widget.deals.getDeal(id);
      if (item != null) {
        final d = item.deal;
        _title.text = d.title;
        _amount.text = d.amount == null ? '' : (d.amount == d.amount!.roundToDouble() ? d.amount!.toStringAsFixed(0) : '${d.amount}');
        _description.text = d.description;
        _contactId = d.contactId;
        _contactName = item.contactName;
        _currency = d.currency;
        _stageId = d.stageId;
        _close = d.expectedClose;
        if (!item.isOpen) _stages = [..._stages, item.stage];
        _docs = [
          for (final x in await widget.deals.documents(id))
            DocDraft(id: x.id, reference: x.reference, amount: x.amount, date: x.date, path: x.path, name: x.name),
        ];
      }
    } else {
      _contactId = widget.contactId;
      if (_contactId != null) _contactName = (await widget.contacts.get(_contactId!))?.displayName ?? '';
      _stageId = _stages.any((s) => s.id == widget.stageId) ? widget.stageId : _stages.first.id;
    }
    _initial = _signature();
    if (mounted) setState(() => _loading = false);
  }

  String _signature() => [_title.text, _amount.text, _description.text, _contactId, _currency, _stageId, _close?.toIso8601String(), _inputs.currentState?.signature ?? '', _docs.map((d) => d.id ?? 'new${d.hashCode}').join(','), _removedDocs.length].join('|');

  bool get _dirty => !_loading && _signature() != _initial;

  @override
  void dispose() {
    for (final c in [_title, _amount, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _amountValue {
    final t = _amount.text.trim().replaceAll(',', '');
    return t.isEmpty ? null : double.tryParse(t);
  }

  Future<void> _pickContact() async {
    final c = await pickContact(context, widget.contacts);
    if (c == null || c.id == null) return;
    setState(() {
      _contactId = c.id;
      _contactName = c.name;
      _problem = null;
    });
  }

  Future<void> _pickCurrency() async {
    final c = await showGlassSheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(AppLocalizations.of(context).fieldCurrency),
        for (final (i, code) in allCurrencyCodes().indexed)
          SheetItem(first: i == 0, title: code, bold: code == _currency, selected: code == _currency, onTap: () => Navigator.of(ctx).pop(code)),
      ]),
    );
    if (c != null) setState(() => _currency = c);
  }

  Future<void> _pickClose() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _close ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _close = d);
  }

  Future<void> _save() async {
    if (_saving) return;
    final raw = _amount.text.trim();
    final amount = _amountValue;
    final input = DealInput(
      title: _title.text,
      contactId: _contactId,
      amount: amount,
      currency: _currency,
      stageId: _stageId ?? _stages.first.id,
      expectedClose: _close,
      description: _description.text,
    );
    final problem = (raw.isNotEmpty && amount == null) ? 'amount' : input.problem();
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _saving = true);
    final id = await widget.deals.saveDeal(input, id: widget.id);
    await _inputs.currentState?.save(id);
    for (final d in _removedDocs) {
      final path = await widget.deals.deleteDocument(d.id!);
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    }
    for (final d in _docs.where((d) => d.id == null)) {
      await widget.deals.saveDocument(id, reference: d.reference, amount: d.amount, currency: _currency, date: d.date, path: d.path, name: d.name);
    }
    _initial = _signature();
    if (mounted) Navigator.of(context).pop(id);
  }

  Future<void> _addDoc() async {
    final d = await showDealDocumentDialog(context, currency: _currency);
    if (d != null) setState(() => _docs = [..._docs, d]);
  }

  Future<void> _docMenu(DocDraft d) async {
    final l = AppLocalizations.of(context);
    final remove = await showGlassSheet<bool>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(d.reference.isEmpty ? l.documentsTitle : d.reference),
        SheetItem(first: true, icon: Icons.delete_outline, title: l.removeBtn, onTap: () => Navigator.of(ctx).pop(true)),
      ]),
    );
    if (remove != true) return;
    setState(() {
      _docs = _docs.where((x) => !identical(x, d)).toList();
      if (d.id != null) _removedDocs.add(d);
      if (d.id == null && d.path != null) {
        try {
          File(d.path!).deleteSync();
        } catch (_) {}
      }
    });
  }

  Future<bool> _confirmDiscard() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.discardTitle),
        content: Text(l.discardBody),
        actions: [
          DialogCancel(l.keepEditing, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.discard, onPressed: () => Navigator.of(ctx).pop(true), danger: true),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    Widget error(String key, String text) => _problem == key
        ? Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(text, style: TextStyle(color: pal.error, fontSize: 13)))
        : const SizedBox.shrink();
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) {
          _initial = _signature();
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GlassBackdrop(
          child: _loading
              ? const SafeArea(child: LoadingView())
              : Column(children: [
                  HeaderBand(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Row(children: [
                      GlassIconButton(icon: Icons.close, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(widget.id == null ? l.newDeal : l.editDeal,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: pal.onHeader)),
                      ),
                      SizedBox(width: 77.5, child: PillButton(label: l.save, height: 44, accent: true, onPressed: _saving ? null : _save)),
                    ]),
                  ),
                  Expanded(
                    child: ListView(padding: const EdgeInsets.fromLTRB(24, 31, 24, 40), children: [
                      GlassField(
                        controller: _title,
                        label: l.fieldDealTitle,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) {
                          if (_problem == 'title') setState(() => _problem = null);
                        },
                      ),
                      error('title', l.errTitleRequired),
                      const SizedBox(height: 15),
                      GlassSelectField(
                        label: l.fieldContact,
                        value: _contactId != null ? _contactName : ' ',
                        onTap: widget.contactId != null ? () {} : _pickContact,
                      ),
                      error('contact', l.errContactRequired),
                      const SizedBox(height: 27),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          flex: 13,
                          child: GlassField(
                            controller: _amount,
                            label: l.fieldAmount,
                            hint: l.optionalHint,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) {
                              if (_problem == 'amount') setState(() => _problem = null);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 10,
                          child: GlassSelectField(label: l.fieldCurrency, value: _currency, onTap: _pickCurrency),
                        ),
                      ]),
                      error('amount', l.errAmountNegative),
                      const SizedBox(height: 12),
                      SectionLabel(l.fieldStage, padding: const EdgeInsets.fromLTRB(0, 16, 0, 8)),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final st in _stages.where((x) => x.kind == 'open' || x.id == _stageId))
                          PillChip(label: stageLabel(l, st), selected: _stageId == st.id, onTap: () => setState(() => _stageId = st.id)),
                      ]),
                      const SizedBox(height: 27),
                      GlassSelectField(
                        label: l.fieldExpectedClose,
                        value: _close == null ? ' ' : dfmt(DateFormat('d MMM', Localizations.localeOf(context).toString()), _close!),
                        onTap: _pickClose,
                        trailing: _close == null ? const SizedBox.shrink() : IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _close = null)),
                      ),
                      const SizedBox(height: 15),
                      GlassField(
                        controller: _description,
                        label: l.fieldDescriptionDeal,
                        hint: l.optionalHint,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      if (widget.fields != null) ...[
                        const SizedBox(height: 15),
                        FieldInputs(
                          key: _inputs,
                          fields: widget.fields!,
                          scope: FieldScope.deal,
                          ownerId: widget.id,
                          onLoaded: () {
                            _initial = _signature();
                          },
                          onChanged: () {
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                      SectionLabel(l.documentsTitle, padding: const EdgeInsets.fromLTRB(0, 16, 0, 8)),
                      if (_docs.isNotEmpty)
                        SettingsGroup(children: [
                          for (final doc in _docs)
                            SettingsRow(
                              icon: Icons.description_outlined,
                              title: doc.reference.isEmpty ? (doc.name.isEmpty ? l.documentsTitle : doc.name) : doc.reference,
                              subtitle: [
                                if (doc.amount != null) formatMoney(context, doc.amount!, _currency),
                                dfmt(DateFormat('d MMM', Localizations.localeOf(context).toString()), doc.date),
                                if (doc.name.contains('.')) doc.name.split('.').last.toUpperCase(),
                              ].join(' · '),
                              chevron: true,
                              onTap: () => _docMenu(doc),
                            ),
                        ]),
                      const SizedBox(height: 10),
                      PillButton(label: l.addDocument, icon: Icons.add, height: 52, outlined: true, onPressed: _addDoc),
                    ]),
                  ),
                ]),
        ),
      ),
    );
  }
}
