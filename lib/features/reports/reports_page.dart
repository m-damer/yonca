import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../app_controller.dart';
import '../../data/report_builder.dart';
import '../../data/app_database.dart' show Tag, DealStage;
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../contacts/contact_widgets.dart';
import '../deals/deal_widgets.dart';
import '../schedule/schedule_labels.dart';

/// Reports (design S25): choose clients, choose content, preview and export as PDF or CSV.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int _step = 0;
  List<ContactSummary> _all = const [];
  final _selected = <int>{};
  Rating? _rating;
  Role? _role;
  var _options = const ReportOptions();
  final _title = TextEditingController();
  List<ReportClient> _clients = const [];
  final _keys = <GlobalKey>[];
  bool _busy = false;
  String? _open;
  int? _tagId;
  int? _stageId;
  int? _days;
  List<Tag> _tags = const [];
  List<DealStage> _stages = const [];
  Set<int> _stageContacts = const {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadFilters();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final c = widget.controller;
    final tags = await c.contacts?.allTags() ?? const <Tag>[];
    final stages = await c.deals?.stages() ?? const <DealStage>[];
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _stages = stages;
    });
  }

  Future<void> _pickStage(int? id) async {
    var ids = <int>{};
    if (id != null) {
      final items = await widget.controller.deals!.listDeals(stageId: id);
      ids = {for (final d in items) d.deal.contactId};
    }
    if (!mounted) return;
    setState(() {
      _stageId = id;
      _stageContacts = ids;
    });
  }

  List<ContactSummary> get _shown {
    final now = DateTime.now();
    return [
      for (final s in _all)
        if ((_tagId == null || s.tags.any((t) => t.id == _tagId)) &&
            (_stageId == null || _stageContacts.contains(s.contact.id)) &&
            (_days == null || now.difference(s.contact.lastActivityAt ?? s.contact.createdAt).inDays <= _days!))
          s
    ];
  }

  Future<void> _loadContacts() async {
    final r = await widget.controller.contacts?.list(rating: _rating, role: _role) ?? const <ContactSummary>[];
    if (mounted) setState(() => _all = r);
  }

  ReportBuilder get _builder => ReportBuilder(
        contacts: widget.controller.contacts!,
        activities: widget.controller.activities!,
        deals: widget.controller.deals,
        fields: widget.controller.fields,
      );

  Future<void> _toPreview() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final clients = await _builder.build(_selected.toList(), _options);
    if (!mounted) return;
    if (_title.text.isEmpty) _title.text = l.reportDefaultTitle(formatDay(context, DateTime.now()));
    setState(() {
      _clients = clients;
      _keys
        ..clear()
        ..addAll(List.generate(clients.length, (_) => GlobalKey()));
      _busy = false;
      _step = 2;
    });
  }

  Future<File> _tempFile(String ext) async {
    final dir = await getTemporaryDirectory();
    final safe = _title.text.replaceAll(RegExp(r'[^\w؀-ۿ -]'), '').trim();
    return File('${dir.path}/${safe.isEmpty ? 'report' : safe}.$ext');
  }

  Future<void> _csv() async {
    final l = AppLocalizations.of(context);
    final rows = <List<String>>[
      [
        l.colName, l.colCompany, l.colRoles, l.colRating, l.colPhone, l.colEmail,
        if (_options.requirements) l.fieldRequirements,
        if (_options.history) ...[l.colLastActivity, l.typeCall, l.typeVisit, l.typeMessage, l.typeNote],
        if (_options.deals) l.colOpenDeals,
        if (_options.fields && _clients.any((c) => c.fieldValues.isNotEmpty)) l.customFieldsCard,
      ],
      for (final c in _clients)
        [
          c.summary.displayName,
          c.summary.contact.company,
          c.summary.roles.map((r) => roleLabel(l, r)).join('; '),
          ratingLabel(l, ratingFromName(c.summary.contact.rating)),
          c.summary.phones.map((p) => p.number).join('; '),
          c.summary.emails.map((e) => e.value).join('; '),
          if (_options.requirements) c.summary.contact.requirements,
          if (_options.history) ...[
            c.lastActivity == null ? '' : formatDay(context, c.lastActivity!),
            '${c.calls}', '${c.visits}', '${c.messages}', '${c.notes}',
          ],
          if (_options.deals)
            c.openDeals
                .map((d) => '${d.deal.title}${d.deal.amount == null ? '' : ' (${formatMoney(context, d.deal.amount!, d.deal.currency)})'}')
                .join('; '),
          if (_options.fields && _clients.any((x) => x.fieldValues.isNotEmpty)) c.fieldValues.map((f) => '${f.$1}: ${f.$2}').join('; '),
        ],
    ];
    final f = await _tempFile('csv');
    await f.writeAsString(toCsv(rows));
    await Share.shareXFiles([XFile(f.path)], text: _title.text);
  }

  Future<void> _pdf() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_clients.length > 150) {
      messenger.showSnackBar(SnackBar(content: Text(l.reportTooMany)));
      return;
    }
    setState(() => _busy = true);
    try {
      final doc = pw.Document();
      final images = <pw.MemoryImage>[];
      for (final k in _keys) {
        final b = k.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (b == null) continue;
        final img = await b.toImage(pixelRatio: 2.5);
        final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
        images.add(pw.MemoryImage(bytes));
      }
      doc.addPage(pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [for (final i in images) pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10), child: pw.Image(i, fit: pw.BoxFit.fitWidth))],
      ));
      final f = await _tempFile('pdf');
      await f.writeAsBytes(await doc.save());
      await Share.shareXFiles([XFile(f.path)], text: _title.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              GlassIconButton(
                icon: Icons.chevron_left,
                onHeader: true,
                onTap: () => _step > 0 ? setState(() => _step--) : Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _step ? pal.primary : pal.separator,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.reportStepOf(_step + 1), style: TextStyle(fontSize: 13, height: 18.2 / 13, color: pal.text2)),
              Text([l.reportT1, l.reportT2, l.reportT3][_step], style: const TextStyle(fontSize: 28, height: 30 / 28, fontWeight: FontWeight.w600)),
            ]),
          ),
          Expanded(child: _busy ? Center(child: Text(l.reportWorking)) : _body(l, pal)),
        ]),
      ),
    );
  }

  Widget _body(AppLocalizations l, YoncaPalette pal) {
    switch (_step) {
      case 0:
        final shown = _shown;
        final withNote = [for (final s in shown) if (_selected.contains(s.contact.id) && s.contact.temporaryNote.trim().isNotEmpty) s].length;
        Widget chip(String label, bool on, VoidCallback onTap, {double h = 40}) => GestureDetector(
              onTap: onTap,
              child: Container(
                height: h,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: on ? pal.primary : pal.surface2, borderRadius: BorderRadius.circular(6)),
                child: Text(label, style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? pal.onPrimary : pal.text)),
              ),
            );
        void toggle(String k) => setState(() => _open = _open == k ? null : k);
        Widget subs(String k) {
          if (_open != k) return const SizedBox.shrink();
          final opts = switch (k) {
            'role' => [for (final r in Role.values) (roleLabel(l, r), _role == r, () { setState(() => _role = _role == r ? null : r); _loadContacts(); })],
            'rating' => [for (final r in [Rating.hot, Rating.warm, Rating.cold]) (ratingLabel(l, r), _rating == r, () { setState(() => _rating = _rating == r ? null : r); _loadContacts(); })],
            'tag' => [for (final t in _tags) (t.name, _tagId == t.id, () => setState(() => _tagId = _tagId == t.id ? null : t.id))],
            'stage' => [for (final st in _stages) (stageLabel(l, st), _stageId == st.id, () => _pickStage(_stageId == st.id ? null : st.id))],
            _ => [
                for (final d in [7, 30, 90]) (d == 7 ? l.reportRange7 : d == 30 ? l.reportRange30 : l.reportRange90, _days == d, () => setState(() => _days = _days == d ? null : d))
              ],
          };
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 8, children: [for (final o in opts) chip(o.$1, o.$2, o.$3, h: 34)]),
          );
        }
        final filters = [
          ('role', l.filterRole, _role != null),
          ('rating', l.filterRating, _rating != null),
          ('tag', l.filterTag, _tagId != null),
          if (_stages.isNotEmpty) ('stage', l.reportFilterStage, _stageId != null),
          ('date', l.reportFilterDate, _days != null),
        ];
        return Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 16), children: [
              Wrap(spacing: 8, runSpacing: 8, children: [for (final f in filters) chip(f.$2, f.$3 || _open == f.$1, () => toggle(f.$1))]),
              if (_open != null) subs(_open!),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Row(children: [
                  Expanded(child: Text(l.contactsCount(shown.length), style: const TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w600))),
                  GestureDetector(
                    onTap: () => setState(() {
                      final ids = shown.map((s) => s.contact.id);
                      if (ids.isNotEmpty && ids.every(_selected.contains)) {
                        _selected.removeAll(ids);
                      } else {
                        _selected.addAll(ids);
                      }
                    }),
                    child: Text(l.selectAll, style: TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w600, color: pal.primary)),
                  ),
                ]),
              ),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: Column(children: [
                  for (final s in shown)
                    InkWell(
                      onTap: () => setState(() => _selected.contains(s.contact.id) ? _selected.remove(s.contact.id) : _selected.add(s.contact.id)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                        child: Row(children: [
                          ContactAvatar(summary: s, size: 40, fontSize: 14, showBadges: false),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w500)),
                              Text(
                                [
                                  if (s.roles.isNotEmpty) roleLabel(l, s.roles.first),
                                  ratingLabel(l, ratingFromName(s.contact.rating)),
                                ].join(' · '),
                                style: TextStyle(fontSize: 13, height: 18.2 / 13, color: pal.text2),
                              ),
                            ]),
                          ),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _selected.contains(s.contact.id) ? pal.primary : null,
                              borderRadius: BorderRadius.circular(8),
                              border: _selected.contains(s.contact.id) ? null : Border.all(color: const Color(0xFFC7C7CC), width: 2),
                            ),
                            child: _selected.contains(s.contact.id) ? Icon(Icons.check, size: 16, color: pal.onPrimary) : null,
                          ),
                        ]),
                      ),
                    ),
                ]),
              ),
              if (withNote > 0)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(color: const Color(0xFFFFE5E2), borderRadius: BorderRadius.circular(8)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.warning_amber_rounded, size: 22, color: Color(0xFFB3261E)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.reportTempNote(withNote), style: const TextStyle(fontSize: 13, height: 18.2 / 13, color: Color(0xFF3A1A17)))),
                  ]),
                ),
            ]),
          ),
          _nav(l, enabled: _selected.isNotEmpty, label: l.reportNextCount(_selected.length), onNext: () => setState(() => _step = 1)),
        ]);
      case 1:
        Widget sw(String t, bool v, ReportOptions Function(bool) f) =>
            SwitchListTile(title: Text(t), value: v, onChanged: (x) => setState(() => _options = f(x)));
        return Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              sw(l.reportBasics, _options.basics, (v) => _options.copyWith(basics: v)),
              sw(l.reportRequirements, _options.requirements, (v) => _options.copyWith(requirements: v)),
              sw(l.reportHistory, _options.history, (v) => _options.copyWith(history: v)),
              sw(l.reportDeals, _options.deals, (v) => _options.copyWith(deals: v)),
              sw(l.reportFields, _options.fields, (v) => _options.copyWith(fields: v)),
            ]),
          ),
          _nav(l, enabled: true, onNext: _toPreview),
        ]);
      default:
        return Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: GlassField(controller: _title, label: l.reportTitleField)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                for (var i = 0; i < _clients.length; i++)
                  RepaintBoundary(key: _keys[i], child: _ReportCard(client: _clients[i], options: _options, title: i == 0 ? _title.text : null)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(l.reportPrivacy, style: TextStyle(fontSize: 12, color: pal.text2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(children: [
              Expanded(child: PillButton(label: l.exportPdf, height: 48, onPressed: _pdf)),
              const SizedBox(width: 8),
              Expanded(child: PillButton(label: l.exportCsv, outlined: true, height: 48, onPressed: _csv)),
            ]),
          ),
        ]);
    }
  }

  Widget _nav(AppLocalizations l, {required bool enabled, required VoidCallback onNext, String? label}) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: PillButton(label: label ?? l.reportNext, height: 48, onPressed: enabled ? onNext : null),
      );
}

/// A client card drawn in fixed light colours so the PDF looks the same in either theme.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.client, required this.options, this.title});
  final ReportClient client;
  final ReportOptions options;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = client.summary;
    const ink = Color(0xFF16211B);
    const soft = Color(0xFF5B6B62);
    Widget line(String t, {bool bold = false, Color color = ink}) =>
        Padding(padding: const EdgeInsets.only(top: 3), child: Text(t, style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)));
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: DefaultTextStyle(
        style: const TextStyle(color: ink),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null && title!.isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title!, style: const TextStyle(fontSize: 12, color: soft))),
          Text(s.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (s.contact.company.isNotEmpty && s.contact.company != s.displayName) line(s.contact.company, color: soft),
          line([
            s.roles.map((r) => roleLabel(l, r)).join(', '),
            ratingLabel(l, ratingFromName(s.contact.rating)),
          ].where((t) => t.isNotEmpty).join(' · '), color: soft),
          if (options.basics) ...[
            for (final p in s.phones) line(p.number),
            for (final e in s.emails) line(e.value),
          ],
          if (options.requirements && s.contact.requirements.isNotEmpty) line(s.contact.requirements),
          if (options.history) ...[
            if (client.lastActivity != null) line(l.reportLastActivity(formatDay(context, client.lastActivity!)), color: soft),
            line(l.reportActivityCounts(client.calls, client.visits, client.messages, client.notes), color: soft),
          ],
          if (options.deals)
            for (final d in client.openDeals)
              line('${d.deal.title} · ${stageLabel(l, d.stage)}${d.deal.amount == null ? '' : ' · ${formatMoney(context, d.deal.amount!, d.deal.currency)}'}', bold: true),
          if (options.fields)
            for (final f in client.fieldValues) line('${f.$1}: ${f.$2}'),
        ]),
      ),
    );
  }
}
