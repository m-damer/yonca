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
import 'deal_detail_page.dart';
import 'deal_form_page.dart';
import 'deal_widgets.dart';
import 'stages_page.dart';

/// Deals tab (design S21): one page per stage, with the stage name, count and totals on top.
class DealsTab extends StatefulWidget {
  const DealsTab({super.key, required this.deals, required this.contacts});
  final DealsRepository? deals;
  final ContactsRepository? contacts;

  @override
  State<DealsTab> createState() => DealsTabState();
}

class DealsTabState extends State<DealsTab> {
  final _pages = PageController();
  List<StageSummary> _summaries = const [];
  Map<int, List<DealItem>> _byStage = const {};
  int _page = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.deals?.revision.addListener(_reload);
    if (widget.deals == null) {
      _loaded = true;
    } else {
      _reload();
    }
  }

  @override
  void dispose() {
    widget.deals?.revision.removeListener(_reload);
    _pages.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final r = widget.deals;
    if (r == null) return;
    final sums = await r.summaries();
    final all = await r.listDeals();
    final by = <int, List<DealItem>>{};
    for (final i in all) {
      (by[i.stage.id] ??= []).add(i);
    }
    if (!mounted) return;
    setState(() {
      _summaries = sums;
      _byStage = by;
      _loaded = true;
      if (_page >= sums.length) _page = 0;
    });
  }

  /// Stage on screen (for "New deal" started from this page); null when it is Won or Lost.
  int? get currentStageId {
    if (_page >= _summaries.length) return null;
    final s = _summaries[_page].stage;
    return s.kind == 'open' ? s.id : null;
  }

  /// Contact first, then the form with the current stage pre-selected.
  Future<void> newDeal() async {
    final deals = widget.deals, contacts = widget.contacts;
    if (deals == null || contacts == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final stage = currentStageId;
    final c = await pickContact(context, contacts);
    if (c == null || c.id == null || !mounted) return;
    final id = await Navigator.of(context).push<int>(MaterialPageRoute(
      builder: (_) => DealFormPage(deals: deals, contacts: contacts, contactId: c.id, stageId: stage),
    ));
    if (id != null && id > 0) messenger.showSnackBar(SnackBar(content: Text(l.dealSaved)));
  }

  Future<void> _open(DealItem i) async {
    final deals = widget.deals, contacts = widget.contacts;
    if (deals == null || contacts == null) return;
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DealDetailPage(deals: deals, contacts: contacts, id: i.deal.id),
    ));
  }

  void _go(int page) {
    if (page < 0 || page >= _summaries.length) return;
    _pages.animateToPage(page, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    if (!_loaded) return const SizedBox.shrink();
    if (_summaries.isEmpty) return EmptyState(icon: Icons.paid_outlined, title: l.dealsTitle, body: l.noDealsYet);
    final cur = _summaries[_page];
    return Column(children: [
      HeaderBand(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(l.dealsTitle, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: pal.onHeader))),
            GlassIconButton(
              icon: Icons.tune,
              onHeader: true,
              onTap: () {
                final d = widget.deals;
                if (d != null) Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StagesPage(deals: d)));
              },
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: pal.glass, borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(children: [
              IconButton(icon: Icon(Icons.navigate_before, color: pal.text), onPressed: _page > 0 ? () => _go(_page - 1) : null),
              Expanded(
                child: InkWell(
                  onTap: _jump,
                  child: Column(children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(stageLabel(l, cur.stage), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: pal.text)),
                      Icon(Icons.keyboard_arrow_down, color: pal.text),
                    ]),
                    Text(
                      [l.dealsInStageCount(cur.count), if (cur.totals.isNotEmpty) formatMoney(context, cur.totals.values.first, cur.totals.keys.first)].join(' · '),
                      style: TextStyle(fontSize: 13, color: pal.text2),
                    ),
                    for (final e in cur.totals.entries.skip(1))
                      Text(formatMoney(context, e.value, e.key), style: TextStyle(fontSize: 13, color: pal.text2)),
                  ]),
                ),
              ),
              IconButton(
                icon: Icon(Icons.navigate_next, color: pal.text),
                onPressed: _page < _summaries.length - 1 ? () => _go(_page + 1) : null,
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _summaries.length; i++)
              Container(
                width: i == _page ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _page ? pal.accent : pal.onHeader.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ]),
        ]),
      ),
      Expanded(
        child: PageView(
          controller: _pages,
          onPageChanged: (i) => setState(() => _page = i),
          children: [
            for (final s in _summaries)
              () {
                final items = _byStage[s.stage.id] ?? const <DealItem>[];
                if (items.isEmpty) {
                  return EmptyState(icon: Icons.paid_outlined, title: l.nothingInStage, body: s.stage.kind == 'open' ? l.nothingInStageBody : null);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [for (final i in items) DealCard(item: i, showStage: false, onTap: () => _open(i))],
                );
              }(),
          ],
        ),
      ),
    ]);
  }

  Future<void> _jump() async {
    final l = AppLocalizations.of(context);
    final s = await pickStage(context, [for (final x in _summaries) x.stage], current: _summaries[_page].stage.id, title: l.jumpToStage);
    if (s == null) return;
    _go(_summaries.indexWhere((x) => x.stage.id == s.id));
  }
}
