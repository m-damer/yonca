import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';

import '../../data/app_database.dart';
import '../../data/contacts_repository.dart';
import '../../data/deals_repository.dart';
import '../../domain/contact_models.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../activities/contact_picker.dart';
import '../contacts/contact_widgets.dart';
import 'deal_detail_page.dart';
import 'deal_form_page.dart';
import 'deal_widgets.dart';

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
  final _queryCtl = TextEditingController();
  List<StageSummary> _summaries = const [];
  List<DealItem> _all = const [];
  Map<int, Set<Role>> _roles = const {};
  int _page = 0;
  bool _loaded = false;
  bool _searching = false;
  String _query = '';
  Set<String> _currencies = {};
  Set<Role> _roleFilter = {};

  /// Month shown on the Won and Lost pages; null = all time.
  DateTime? _month = DateTime(DateTime.now().year, DateTime.now().month);

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
    _queryCtl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final r = widget.deals;
    if (r == null) return;
    final sums = await r.summaries();
    final all = await r.listDeals();
    final people = await widget.contacts?.list() ?? const <ContactSummary>[];
    if (!mounted) return;
    setState(() {
      _summaries = sums;
      _all = all;
      _roles = {for (final p in people) p.contact.id: p.roles.toSet()};
      _loaded = true;
      if (_page >= sums.length) _page = 0;
    });
  }

  bool get _filtered => _currencies.isNotEmpty || _roleFilter.isNotEmpty;

  bool _passes(DealItem i) {
    if (_currencies.isNotEmpty && !_currencies.contains(i.deal.currency)) return false;
    if (_roleFilter.isNotEmpty && (_roles[i.deal.contactId] ?? const <Role>{}).intersection(_roleFilter).isEmpty) return false;
    return true;
  }

  bool _inMonth(DealItem i) {
    final m = _month;
    if (m == null || i.isOpen) return true;
    final d = i.deal.closedAt ?? i.deal.stageChangedAt;
    return d.year == m.year && d.month == m.month;
  }

  /// Deals of one stage after the filters (and the month, on Won and Lost).
  List<DealItem> _itemsOf(DealStage s) => [for (final i in _all) if (i.stage.id == s.id && _passes(i) && _inMonth(i)) i];

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

  String _totals(BuildContext context, List<DealItem> items) {
    final t = <String, double>{};
    for (final i in items) {
      if (i.deal.amount != null) t[i.deal.currency] = (t[i.deal.currency] ?? 0) + i.deal.amount!;
    }
    return [for (final e in t.entries) formatMoney(context, e.value, e.key)].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    if (!_loaded) return const SizedBox.shrink();
    if (_summaries.isEmpty) return EmptyState(icon: Icons.paid_outlined, title: l.dealsTitle, body: l.noDealsYet);
    if (_searching) return _searchView(l, pal);
    final cur = _summaries[_page].stage;
    final closed = cur.kind != 'open';
    final curItems = _itemsOf(_summaries[_page].stage);
    return Column(children: [
      HeaderBand(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(children: [
              Expanded(child: Text(l.dealsTitle, style: TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, color: pal.onHeader))),
              GlassIconButton(icon: Icons.search, tooltip: l.dealsSearchHint, onTap: () => setState(() => _searching = true)),
              const SizedBox(width: 12),
              GlassIconButton(icon: Icons.filter_alt_outlined, tooltip: l.dealsFilterTitle, filled: _filtered, onTap: _openFilter),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              decoration: BoxDecoration(color: pal.glass, borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                SizedBox(
                  width: 56,
                  child: IconButton(icon: Icon(Icons.chevron_left, color: pal.text), onPressed: _page > 0 ? () => _go(_page - 1) : null),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _jump,
                    child: Column(children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(stageLabel(l, cur), style: TextStyle(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600, color: pal.text)),
                        Icon(Icons.keyboard_arrow_down, size: 22, color: pal.text),
                      ]),
                      for (final line in _stageLines(l, curItems, cur))
                        Text(line, style: TextStyle(fontSize: 13, height: 18 / 13, color: pal.text2)),
                    ]),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: IconButton(
                    icon: Icon(Icons.chevron_right, color: pal.text),
                    onPressed: _page < _summaries.length - 1 ? () => _go(_page + 1) : null,
                  ),
                ),
              ]),
            ),
          ),
          SizedBox(
            height: 29,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _summaries.length; i++)
                Container(
                  width: i == _page ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(color: i == _page ? pal.accent : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6)), borderRadius: BorderRadius.circular(3)),
                ),
            ]),
          ),
          if (closed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: SizedBox(
                height: 40,
                child: Row(children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _pickMonth,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.calendar_today_outlined, size: 20, color: pal.text),
                        const SizedBox(width: 8),
                        Text(
                          _month == null ? l.allTime : dfmt(DateFormat.yMMMM(Localizations.localeOf(context).toString()), _month!),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: pal.text),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.keyboard_arrow_down, size: 20, color: pal.text),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  if (_totals(context, curItems).isNotEmpty)
                    Text.rich(TextSpan(style: TextStyle(fontSize: 13, color: pal.text2), children: [
                      TextSpan(text: '${l.dealsTotal} '),
                      TextSpan(text: _totals(context, curItems), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ])),
                ]),
              ),
            ),
        ]),
      ),
      Expanded(
        child: PageView(
          controller: _pages,
          onPageChanged: (i) => setState(() => _page = i),
          children: [
            for (final s in _summaries)
              () {
                final items = _itemsOf(s.stage);
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.paid_outlined,
                    title: _filtered ? l.noDealsMatch : l.nothingInStage,
                    body: !_filtered && s.stage.kind == 'open' ? l.nothingInStageBody : null,
                  );
                }
                final isClosed = s.stage.kind != 'open';
                return ListView(
                  padding: EdgeInsets.fromLTRB(16, isClosed ? 10 : 2, 16, 120),
                  children: [for (final i in items) DealCard(item: i, showStage: false, mode: isClosed ? DealCardMode.closedPage : DealCardMode.open, onTap: () => _open(i))],
                );
              }(),
          ],
        ),
      ),
    ]);
  }

  List<String> _stageLines(AppLocalizations l, List<DealItem> items, DealStage s) {
    final t = <String, double>{};
    for (final i in items) {
      if (i.deal.amount != null) t[i.deal.currency] = (t[i.deal.currency] ?? 0) + i.deal.amount!;
    }
    final counts = l.dealsInStageCount(items.length);
    if (s.kind != 'open' || t.isEmpty) return [counts];
    final money = [for (final e in t.entries) formatMoney(context, e.value, e.key)];
    return ['$counts · ${money.first}', ...money.skip(1)];
  }

  Widget _searchView(AppLocalizations l, YoncaPalette pal) {
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? const <DealItem>[]
        : [for (final i in _all) if (_passes(i) && (i.deal.title.toLowerCase().contains(q) || i.contactName.toLowerCase().contains(q))) i];
    void close() => setState(() {
          _searching = false;
          _query = '';
          _queryCtl.clear();
        });
    return Column(children: [
      HeaderBand(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(children: [
            GlassIconButton(icon: Icons.chevron_left, tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: close),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: pal.glass, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.search, size: 24, color: pal.text),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _queryCtl,
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(fontSize: 16, color: pal.text),
                      cursorColor: pal.primary,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: l.dealsSearchHint,
                        hintStyle: TextStyle(color: pal.text2),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    InkWell(
                      onTap: () => setState(() {
                        _query = '';
                        _queryCtl.clear();
                      }),
                      child: Icon(Icons.close, size: 24, color: pal.text),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
      if (q.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 11, 20, 0),
          child: Align(alignment: AlignmentDirectional.centerStart, child: Text(l.resultsCount(results.length), style: TextStyle(fontSize: 13, height: 18 / 13, color: pal.text2))),
        ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 1, 16, 120),
          children: [for (final i in results) DealCard(item: i, showStage: false, mode: DealCardMode.search, onTap: () => _open(i))],
        ),
      ),
    ]);
  }

  Future<void> _pickMonth() async {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final loc = Localizations.localeOf(context).toString();
    final months = [for (var k = 0; k < 12; k++) DateTime(now.year, now.month - k)];
    final r = await showGlassSheet<Object>(
      context,
      builder: (ctx) => SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GlassSheetOption(icon: Icons.all_inclusive, label: l.allTime, first: true, onTap: () => Navigator.pop(ctx, 'all')),
          for (final m in months)
            GlassSheetOption(icon: Icons.calendar_today_outlined, label: dfmt(DateFormat.yMMMM(loc), m), onTap: () => Navigator.pop(ctx, m)),
        ]),
      ),
    );
    if (r == null) return;
    setState(() => _month = r is DateTime ? r : null);
  }

  Future<void> _openFilter() async {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final currencies = {for (final i in _all) i.deal.currency}.toList()..sort();
    var cur = {..._currencies};
    var roles = {..._roleFilter};
    await showGlassSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final count = _all.where((i) => (cur.isEmpty || cur.contains(i.deal.currency)) && (roles.isEmpty || (_roles[i.deal.contactId] ?? const <Role>{}).intersection(roles).isNotEmpty)).length;
        Widget label(String t, double top) => Padding(
              padding: EdgeInsets.fromLTRB(4, top, 4, 10),
              child: Text(t.toUpperCase(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text2)),
            );
        return SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 0), child: Text(l.dealsFilterTitle, style: const TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600))),
            label(l.filterCurrency, 20),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in currencies)
                PillChip(label: c, selected: cur.contains(c), onTap: () => setS(() => cur.contains(c) ? cur.remove(c) : cur.add(c))),
            ]),
            label(l.filterContactRole, 20),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in Role.values)
                PillChip(label: roleLabel(l, r), selected: roles.contains(r), onTap: () => setS(() => roles.contains(r) ? roles.remove(r) : roles.add(r))),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setS(() {
                    cur.clear();
                    roles.clear();
                  }),
                  child: Text(l.filterClear, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.primary)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: PillButton(label: l.dealsShowN(count), onPressed: () => Navigator.pop(ctx))),
            ]),
          ]),
        );
      }),
    );
    if (!mounted) return;
    setState(() {
      _currencies = cur;
      _roleFilter = roles;
    });
  }

  Future<void> _jump() async {
    final l = AppLocalizations.of(context);
    final s = await pickStage(context, [for (final x in _summaries) x.stage], current: _summaries[_page].stage.id, title: l.jumpToStage);
    if (s == null) return;
    _go(_summaries.indexWhere((x) => x.stage.id == s.id));
  }
}
