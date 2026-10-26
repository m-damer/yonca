import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../data/deals_repository.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../activities/contact_picker.dart';
import '../schedule/schedule_labels.dart';
import 'deal_widgets.dart';

/// New or edit deal. [contactId] pre-fills (and locks) the contact; [stageId] pre-selects the stage.
/// Pops with the deal id, or -1 when deleted.
class DealFormPage extends StatefulWidget {
  const DealFormPage({super.key, required this.deals, required this.contacts, this.contactId, this.stageId, this.id});
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
  String _currency = 'USD';
  int? _stageId;
  DateTime? _close;
  List<DealStage> _stages = const [];
  bool _loading = true;
  bool _saving = false;
  String? _problem;
  String _initial = '';

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
      }
    } else {
      _contactId = widget.contactId;
      if (_contactId != null) _contactName = (await widget.contacts.get(_contactId!))?.displayName ?? '';
      _stageId = _stages.any((s) => s.id == widget.stageId) ? widget.stageId : _stages.first.id;
    }
    _initial = _signature();
    if (mounted) setState(() => _loading = false);
  }

  String _signature() => [_title.text, _amount.text, _description.text, _contactId, _currency, _stageId, _close?.toIso8601String()].join('|');

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

  Future<void> _pickStageField() async {
    final s = await pickStage(context, _stages, current: _stageId);
    if (s != null) setState(() => _stageId = s.id);
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
    _initial = _signature();
    if (mounted) Navigator.of(context).pop(id);
  }

  Future<bool> _confirmDiscard() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.discardTitle),
        content: Text(l.discardBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.keepEditing)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.discard)),
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Row(children: [
                      GlassIconButton(icon: Icons.close, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(widget.id == null ? l.newDeal : l.editDeal,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: pal.onHeader)),
                      ),
                      SizedBox(width: 88, child: PillButton(label: l.save, height: 44, accent: true, onPressed: _saving ? null : _save)),
                    ]),
                  ),
                  Expanded(
                    child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: [
                      GlassField(
                        controller: _title,
                        label: l.fieldDealTitle,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) {
                          if (_problem == 'title') setState(() => _problem = null);
                        },
                      ),
                      error('title', l.errTitleRequired),
                      const SizedBox(height: 12),
                      GlassSelectField(
                        label: l.fieldContact,
                        value: _contactId != null ? _contactName : ' ',
                        onTap: widget.contactId != null ? () {} : _pickContact,
                      ),
                      error('contact', l.errContactRequired),
                      const SizedBox(height: 12),
                      GlassField(
                        controller: _amount,
                        label: l.fieldAmount,
                        hint: l.optionalHint,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) {
                          if (_problem == 'amount') setState(() => _problem = null);
                        },
                      ),
                      error('amount', l.errAmountNegative),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final c in dealCurrencies)
                          PillChip(label: c, selected: _currency == c, check: true, onTap: () => setState(() => _currency = c)),
                      ]),
                      const SizedBox(height: 16),
                      GlassSelectField(
                        label: l.fieldStage,
                        value: _stages.where((s) => s.id == _stageId).map((s) => stageLabel(l, s)).firstOrNull ?? ' ',
                        onTap: _pickStageField,
                      ),
                      const SizedBox(height: 12),
                      GlassSelectField(label: l.fieldExpectedClose, value: _close == null ? ' ' : formatDay(context, _close!), onTap: _pickClose),
                      if (_close != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(onPressed: () => setState(() => _close = null), child: Text(l.clear)),
                        ),
                      const SizedBox(height: 12),
                      GlassField(
                        controller: _description,
                        label: l.fieldDescriptionDeal,
                        hint: l.optionalHint,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ]),
                  ),
                ]),
        ),
      ),
    );
  }
}
