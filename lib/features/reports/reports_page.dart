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

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
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
    final steps = [l.reportStep1, l.reportStep2, l.reportStep3];
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
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.reportsTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: pal.onHeader)),
                  Text(steps[_step], style: TextStyle(fontSize: 13, color: pal.onHeader.withValues(alpha: .85))),
                ]),
              ),
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
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in [Rating.hot, Rating.warm, Rating.cold])
                  PillChip(
                    label: ratingLabel(l, r),
                    selected: _rating == r,
                    onTap: () {
                      setState(() => _rating = _rating == r ? null : r);
                      _loadContacts();
                    },
                  ),
                for (final r in Role.values)
                  PillChip(
                    label: roleLabel(l, r),
                    selected: _role == r,
                    onTap: () {
                      setState(() => _role = _role == r ? null : r);
                      _loadContacts();
                    },
                  ),
              ]),
              Row(children: [
                TextButton(
                  onPressed: () => setState(() {
                    final ids = _all.map((s) => s.contact.id);
                    if (ids.every(_selected.contains)) {
                      _selected.removeAll(ids);
                    } else {
                      _selected.addAll(ids);
                    }
                  }),
                  child: Text(l.selectAll),
                ),
                Expanded(child: Text(l.selectedCount(_selected.length), style: TextStyle(color: pal.text2))),
              ]),
            ]),
          ),
          Expanded(
            child: ListView(children: [
              for (final s in _all)
                CheckboxListTile(
                  value: _selected.contains(s.contact.id),
                  title: Text(s.displayName),
                  subtitle: s.contact.company.isEmpty || s.contact.company == s.displayName ? null : Text(s.contact.company),
                  onChanged: (v) => setState(() => v == true ? _selected.add(s.contact.id) : _selected.remove(s.contact.id)),
                ),
              const SizedBox(height: 100),
            ]),
          ),
          _nav(l, enabled: _selected.isNotEmpty, onNext: () => setState(() => _step = 1)),
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

  Widget _nav(AppLocalizations l, {required bool enabled, required VoidCallback onNext}) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: PillButton(label: l.reportNext, height: 48, onPressed: enabled ? onNext : null),
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
