import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../app_controller.dart';
import '../../data/crash_log.dart';
import '../../data/report_builder.dart';
import '../../data/timeline_builder.dart';
import '../../domain/stats_models.dart';
import '../stats/stats_labels.dart';
import '../../core/format.dart';
import '../../data/app_database.dart' show Tag, DealStage;
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/multi_select.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../contacts/contact_widgets.dart';
import '../settings/settings_widgets.dart' show SettingsSwitch;
import '../deals/deal_widgets.dart';
import '../schedule/schedule_labels.dart';
import 'timeline_report.dart';
import '../../theme/lucide.dart';

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
  final _ratings = <Rating>{};
  final _roles = <Role>{};
  var _options = const ReportOptions();
  final _title = TextEditingController();
  List<ReportClient> _clients = const [];
  final _keys = <GlobalKey>[];
  bool _busy = false;
  String _parent = 'role';
  String _lang = '';
  List<Map<String, dynamic>> _presets = const [];
  String _owner = '';
  PeriodStats? _perf;
  List<(TargetValue, double, DateTime)> _prog = const [];
  final _tagIds = <int>{};
  final _stageIds = <int>{};
  int? _days;
  List<Tag> _tags = const [];
  List<DealStage> _stages = const [];
  Set<int> _stageContacts = const {};
  bool _timeline = false;
  List<ContactTimeline> _timelines = const [];
  final _tlKeys = <({GlobalKey key, bool first})>[];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadFilters();
    _loadPreset();
  }

  Future<void> _loadPreset() async {
    final c = widget.controller;
    final owner = await c.database?.getSetting('profile.name') ?? '';
    final raw = c.pref('report.presets');
    var list = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        list = [for (final m in jsonDecode(raw) as List) Map<String, dynamic>.from(m as Map)];
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _owner = owner.trim();
      _presets = list;
    });
  }

  Future<void> _storePresets() => widget.controller.setPref('report.presets', jsonEncode(_presets));

  Map<String, dynamic> _snapshot(String name) => {
        'name': name,
        'roles': [for (final r in _roles) r.name],
        'ratings': [for (final r in _ratings) r.name],
        'tagIds': _tagIds.toList(),
        'stageIds': _stageIds.toList(),
        'days': _days,
        'performance': _options.performance,
        'requirements': _options.requirements,
        'basics': _options.basics,
        'history': _options.history,
        'deals': _options.deals,
        'targets': _options.targets,
        'lang': _lang,
      };

  // Presets saved before multi-select stored a single value under the old key.
  List<String> _presetNames(Map<String, dynamic> m, String key, String old) =>
      [if (m[key] is List) ...(m[key] as List).cast<String>() else if (m[old] != null) m[old] as String];
  List<int> _presetInts(Map<String, dynamic> m, String key, String old) =>
      [if (m[key] is List) ...(m[key] as List).cast<int>() else if (m[old] != null) m[old] as int];

  String _presetSummary(AppLocalizations l, Map<String, dynamic> m) {
    final parts = <String>[
      for (final n in _presetNames(m, 'roles', 'role')) roleLabel(l, Role.values.byName(n)),
      for (final n in _presetNames(m, 'ratings', 'rating')) ratingLabel(l, Rating.values.byName(n)),
      for (final i in _presetInts(m, 'tagIds', 'tagId')) ..._tags.where((t) => t.id == i).map((t) => t.name),
      for (final i in _presetInts(m, 'stageIds', 'stageId')) ..._stages.where((t) => t.id == i).map((t) => stageLabel(l, t)),
      if (m['days'] != null) (m['days'] == 7 ? l.reportRange7 : m['days'] == 30 ? l.reportRange30 : l.reportRange90),
    ];
    final on = ['performance', 'requirements', 'basics', 'history', 'deals', 'targets'].where((k) => m[k] == true).length;
    return [parts.isEmpty ? l.presetAllClients : parts.join(' · '), l.presetOptions(on)].join(' · ');
  }

  Future<void> _applyPreset(Map<String, dynamic> m) async {
    setState(() {
      _roles
        ..clear()
        ..addAll(_presetNames(m, 'roles', 'role').map(Role.values.byName));
      _ratings
        ..clear()
        ..addAll(_presetNames(m, 'ratings', 'rating').map(Rating.values.byName));
      _tagIds
        ..clear()
        ..addAll(_presetInts(m, 'tagIds', 'tagId'));
      _days = m['days'] as int?;
      _options = ReportOptions(
        performance: m['performance'] as bool? ?? true,
        requirements: m['requirements'] as bool? ?? true,
        basics: m['basics'] as bool? ?? true,
        history: m['history'] as bool? ?? true,
        deals: m['deals'] as bool? ?? true,
        targets: m['targets'] as bool? ?? false,
      );
      _lang = m['lang'] as String? ?? '';
      _selected.clear();
    });
    await _loadContacts();
    await _pickStages(_presetInts(m, 'stageIds', 'stageId').toSet());
    if (mounted) setState(() => _selected.addAll(_shown.map((s) => s.contact.id)));
  }

  Future<void> _openPresets() async {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final r = await showGlassSheet<int>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.presetsTitle),
        if (_presets.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.xs, AppSpace.xs, AppSpace.md), child: Text(l.presetsEmpty, style: TextStyle(fontSize: AppFont.body, height: AppLine.relaxed, color: p.text2))),
        for (var i = 0; i < _presets.length; i++)
          GestureDetector(
            onLongPress: () => Navigator.of(ctx).pop(-i - 1),
            child: SheetItem(
              first: i == 0,
              icon: Lu.bookmark,
              iconSize: 36,
              title: _presets[i]['name'] as String? ?? '',
              subtitle: _presetSummary(l, _presets[i]),
              vpad: AppSpace.rowS,
              trailing: Icon(Lu.chevronRight, size: AppIcon.lg, color: p.text2),
              onTap: () => Navigator.of(ctx).pop(i),
            ),
          ),
      ]),
    );
    if (r == null || !mounted) return;
    if (r >= 0) {
      await _applyPreset(_presets[r]);
      return;
    }
    final idx = -r - 1;
    final ok = await showSheetDialog<bool>(
      context: context,
      builder: (ctx) => SheetDialog(
        title: Text(l.presetDeleteTitle),
        actions: [
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.delete, onPressed: () => Navigator.of(ctx).pop(true), danger: true),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _presets = [..._presets]..removeAt(idx));
    await _storePresets();
  }

  Future<void> _savePreset() async {
    final l = AppLocalizations.of(context);
    final name = TextEditingController();
    final ok = await showGlassSheet<bool>(
      context,
      builder: (ctx) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.presetSaveTitle),
          Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.md), child: Text(l.presetSaveSub, style: TextStyle(fontSize: AppFont.body, height: AppLine.loose, color: ctx.palette.text2))),
          GlassField(controller: name, label: l.presetNameLabel, autofocus: true, maxLength: 30),
          const SizedBox(height: AppSpace.lg),
          SheetButtons(secondary: l.cancel, onSecondary: () => Navigator.of(ctx).pop(false), primary: l.presetSaveBtn, onPrimary: () => Navigator.of(ctx).pop(true)),
        ]),
      ),
    );
    final text = name.text.trim();
    if (ok != true || text.isEmpty || !mounted) return;
    setState(() => _presets = [..._presets, _snapshot(text)]);
    await _storePresets();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.presetSaveBtn)));
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

  Future<void> _pickStages(Set<int> picked) async {
    final ids = <int>{};
    for (final id in picked) {
      final items = await widget.controller.deals!.listDeals(stageId: id);
      ids.addAll(items.map((d) => d.deal.contactId));
    }
    if (!mounted) return;
    setState(() {
      _stageIds
        ..clear()
        ..addAll(picked);
      _stageContacts = ids;
    });
  }

  List<ContactSummary> get _shown {
    final now = DateTime.now();
    return [
      for (final s in _all)
        if ((_roles.isEmpty || s.roles.any(_roles.contains)) &&
            (_ratings.isEmpty || _ratings.contains(ratingFromName(s.contact.rating))) &&
            (_tagIds.isEmpty || s.tags.any((t) => _tagIds.contains(t.id))) &&
            (_stageIds.isEmpty || _stageContacts.contains(s.contact.id)) &&
            (_days == null || now.difference(s.contact.lastActivityAt ?? s.contact.createdAt).inDays <= _days!))
          s
    ];
  }

  Future<void> _loadContacts() async {
    final r = await widget.controller.contacts?.list() ?? const <ContactSummary>[];
    if (mounted) setState(() => _all = r);
  }

  // ---- filter dropdowns: parent = which filter, child = its values ----
  List<(String, String)> _parents(AppLocalizations l) => [
        ('role', l.filterRole),
        ('rating', l.filterRating),
        ('tag', l.filterTag),
        if (_stages.isNotEmpty) ('stage', l.reportFilterStage),
        ('date', l.reportFilterDate),
      ];

  String _rangeLabel(AppLocalizations l, int d) => d == 7 ? l.reportRange7 : d == 30 ? l.reportRange30 : l.reportRange90;

  List<PickOption> _childOptions(AppLocalizations l, String k) => switch (k) {
        'role' => [for (final r in Role.values) PickOption(r, roleLabel(l, r))],
        'rating' => [for (final r in const [Rating.hot, Rating.warm, Rating.cold]) PickOption(r, ratingLabel(l, r))],
        'tag' => [for (final t in _tags) PickOption(t.id, t.name)],
        'stage' => [for (final st in _stages) PickOption(st.id, stageLabel(l, st))],
        _ => [for (final d in const [7, 30, 90]) PickOption(d, _rangeLabel(l, d))],
      };

  Set<Object> _chosen(String k) => switch (k) {
        'role' => {..._roles},
        'rating' => {..._ratings},
        'tag' => {..._tagIds},
        'stage' => {..._stageIds},
        _ => {if (_days != null) _days!},
      };

  Future<void> _setChosen(String k, Set<Object> v) async {
    switch (k) {
      case 'role':
        setState(() => _roles
          ..clear()
          ..addAll(v.whereType<Role>()));
      case 'rating':
        setState(() => _ratings
          ..clear()
          ..addAll(v.whereType<Rating>()));
      case 'tag':
        setState(() => _tagIds
          ..clear()
          ..addAll(v.whereType<int>()));
      case 'stage':
        await _pickStages(v.whereType<int>().toSet());
      default:
        setState(() => _days = v.whereType<int>().firstOrNull);
    }
  }

  Future<void> _chooseParent(AppLocalizations l) async {
    final r = await showSearchableSelect(context, title: l.msFilterBy, options: [for (final f in _parents(l)) PickOption(f.$1, f.$2)], selected: {_parent}, multi: false);
    if (r != null && r.isNotEmpty && mounted) setState(() => _parent = r.first as String);
  }

  Future<void> _chooseChildren(AppLocalizations l) async {
    final k = _parent;
    final r = await showSearchableSelect(
      context,
      title: _parents(l).firstWhere((f) => f.$1 == k).$2,
      options: _childOptions(l, k),
      selected: _chosen(k),
      multi: k != 'date',
    );
    if (r != null && mounted) await _setChosen(k, r);
  }

  /// One removable chip for every value chosen under any filter.
  List<Widget> _filterChips(AppLocalizations l) => [
        for (final k in ['role', 'rating', 'tag', 'stage', 'date'])
          for (final o in _childOptions(l, k).where((o) => _chosen(k).contains(o.id)))
            PillChip(label: o.label, selected: true, dense: true, onRemove: () => _setChosen(k, _chosen(k)..remove(o.id))),
      ];

  ReportBuilder get _builder => ReportBuilder(
        contacts: widget.controller.contacts!,
        activities: widget.controller.activities!,
        deals: widget.controller.deals,
        fields: widget.controller.fields,
      );

  Future<void> _toPreview() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    if (_timeline) {
      final tls = await TimelineBuilder(
        contacts: widget.controller.contacts!,
        activities: widget.controller.activities!,
        deals: widget.controller.deals,
        fields: widget.controller.fields,
      ).build(_selected.toList());
      if (!mounted) return;
      if (_lang.isEmpty) _lang = Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
      if (_title.text.isEmpty) _title.text = l.tlDefaultTitle(dfmt(DateFormat.yMMMd(Localizations.localeOf(context).toString()), DateTime.now()));
      setState(() {
        _timelines = tls;
        _tlKeys.clear();
        for (final t in tls) {
          _tlKeys.add((key: GlobalKey(), first: true));
          for (var i = 0; i < t.entries.length; i++) {
            _tlKeys.add((key: GlobalKey(), first: false));
          }
        }
        _busy = false;
        _step = 2;
      });
      return;
    }
    final clients = await _builder.build(_selected.toList(), _options);
    final st = widget.controller.stats;
    PeriodStats? perf;
    var prog = <(TargetValue, double, DateTime)>[];
    if (st != null) {
      final now = DateTime.now();
      if (_options.performance) perf = await st.stats(now.subtract(const Duration(days: 30)), now);
      if (_options.targets) prog = await st.progress();
    }
    if (!mounted) return;
    _perf = perf;
    _prog = prog;
    if (_lang.isEmpty) _lang = Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
    if (_title.text.isEmpty) _title.text = l.reportDefaultTitle(dfmt(DateFormat.yMMMd(Localizations.localeOf(context).toString()), DateTime.now()));
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
    if (_timeline) {
      final tl = lookupAppLocalizations(Locale(_lang));
      final f = await _tempFile('csv');
      await f.writeAsString(toCsv(timelineCsv(tl, _lang, _timelines)));
      await Share.shareXFiles([XFile(f.path)], text: _title.text);
      return;
    }
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
          c.summary.fullName,
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

  /// The timeline on A4 pages: each entry is kept whole, and a new contact starts on a new page.
  Future<void> _timelinePdf() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_tlKeys.length > 1500) {
      messenger.showSnackBar(SnackBar(content: Text(l.tlTooMany)));
      return;
    }
    setState(() => _busy = true);
    try {
      const contentW = 595.28 - 56;
      const maxH = 700.0;
      final parts = <pw.Widget>[];
      for (final item in _tlKeys) {
        final b = item.key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (b == null) continue;
        if (item.first && parts.isNotEmpty) parts.add(pw.NewPage());
        final img = await b.toImage(pixelRatio: 2);
        final stripPx = (maxH * img.width / contentW).floor();
        for (var y = 0; y < img.height; y += stripPx) {
          final h = (img.height - y) < stripPx ? img.height - y : stripPx;
          ui.Image part = img;
          if (h != img.height) {
            final rec = ui.PictureRecorder();
            Canvas(rec).drawImageRect(img, Rect.fromLTWH(0, y.toDouble(), img.width.toDouble(), h.toDouble()), Rect.fromLTWH(0, 0, img.width.toDouble(), h.toDouble()), Paint());
            part = await rec.endRecording().toImage(img.width, h);
          }
          final bytes = (await part.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
          parts.add(pw.SizedBox(width: contentW, height: contentW * h / img.width, child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill)));
        }
      }
      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(AppSpace.x3),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: AppSpace.sm),
          child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(fontSize: AppFont.tiny, color: pdf.PdfColor.fromInt(PrintInk.soft.toARGB32()))),
        ),
        build: (_) => parts,
      ));
      final f = await _tempFile('pdf');
      await f.writeAsBytes(await doc.save());
      await Share.shareXFiles([XFile(f.path)], text: _title.text);
    } catch (e, st) {
      CrashLog.instance?.record('Timeline PDF failed: $e', st);
      messenger.showSnackBar(SnackBar(content: Text(l.stateError)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pdf() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_timeline) return _timelinePdf();
    if (_clients.length > 150) {
      messenger.showSnackBar(SnackBar(content: Text(l.reportTooMany)));
      return;
    }
    setState(() => _busy = true);
    try {
      final doc = pw.Document();
      final images = <(pw.MemoryImage, double)>[];
      for (final k in _keys) {
        final b = k.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (b == null) continue;
        final img = await b.toImage(pixelRatio: 2.5);
        // A client card taller than one page is cut into strips that each fit a page.
        const contentW = 595.28 - 56;
        const maxH = 640.0;
        final stripPx = (maxH * img.width / contentW).floor();
        for (var y = 0; y < img.height; y += stripPx) {
          final h = (img.height - y) < stripPx ? img.height - y : stripPx;
          final rec = ui.PictureRecorder();
          Canvas(rec).drawImageRect(img, Rect.fromLTWH(0, y.toDouble(), img.width.toDouble(), h.toDouble()), Rect.fromLTWH(0, 0, img.width.toDouble(), h.toDouble()), Paint());
          final part = await rec.endRecording().toImage(img.width, h);
          final bytes = (await part.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
          // Height of the strip on the page, from its own proportions (never taller than maxH).
          images.add((pw.MemoryImage(bytes), contentW * h / img.width));
        }
      }
      const contentWidth = 595.28 - 56;
      doc.addPage(pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(AppSpace.x3),
        build: (_) => [
          for (final i in images)
            pw.Padding(padding: const pw.EdgeInsets.only(bottom: AppSpace.md), child: pw.SizedBox(width: contentWidth, height: i.$2, child: pw.Image(i.$1, fit: pw.BoxFit.fill))),
        ],
      ));
      final f = await _tempFile('pdf');
      await f.writeAsBytes(await doc.save());
      await Share.shareXFiles([XFile(f.path)], text: _title.text);
    } catch (e, st) {
      CrashLog.instance?.record('Report PDF failed: $e', st);
      messenger.showSnackBar(SnackBar(content: Text(l.stateError)));
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
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, 0),
            child: Row(children: [
              GlassIconButton(
                icon: Lu.x,
                onHeader: true,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: AppSpace.md),
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Container(
                    height: AppSize.s4,
                    decoration: BoxDecoration(
                      color: i <= _step ? pal.primary : pal.separator,
                      borderRadius: BorderRadius.circular(AppRadius.xxs),
                    ),
                  ),
                ),
              ],
            ]),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.lg, AppSpace.xxl, AppSpace.md),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.reportStepOf(_step + 1), style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2)),
              Text([l.reportT1, l.reportT2, l.reportT3][_step], style: const TextStyle(fontSize: AppFont.display, height: AppLine.tight, fontWeight: AppWeight.semibold)),
            ]),
          )),
          // The preview stays in the tree while working: the PDF is drawn from its cards.
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: _body(l, pal)),
              if (_busy) Positioned.fill(child: ColoredBox(color: pal.bg, child: Center(child: Text(l.reportWorking)))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _body(AppLocalizations l, YoncaPalette pal) {
    switch (_step) {
      case 0:
        final shown = _shown;
        final withNote = [for (final s in shown) if (_selected.contains(s.contact.id) && s.contact.temporaryNote.trim().isNotEmpty) s].length;
        final parentLabel = _parents(l).firstWhere((f) => f.$1 == _parent, orElse: () => _parents(l).first).$2;
        final nChosen = _chosen(_parent).length;
        final childText = nChosen == 0
            ? l.msSelectValues
            : _parent == 'date'
                ? _rangeLabel(l, _days!)
                : l.msNValues(nChosen);
        return Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xxl, 0, AppSpace.xxl, AppSpace.lg), children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: GestureDetector(
                    onTap: _openPresets,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Lu.bookmark, size: AppIcon.md, color: pal.primary),
                      const SizedBox(width: AppSpace.sm),
                      Text(l.presetsTitle, style: TextStyle(fontSize: AppFont.label, fontWeight: AppWeight.semibold, color: pal.primary)),
                    ]),
                  ),
                ),
              ),
              DropdownBox(label: l.msFilterBy, text: parentLabel, onTap: () => _chooseParent(l)),
              const SizedBox(height: AppSpace.md),
              DropdownBox(label: l.msValues, text: childText, placeholder: nChosen == 0, onTap: () => _chooseChildren(l)),
              if (_filterChips(l).isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
                ChipsScrollRow(chips: _filterChips(l)),
              ],
              const SizedBox(height: AppSpace.lg),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.sm),
                child: Row(children: [
                  Expanded(child: Text(l.contactsCount(shown.length), style: const TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: AppWeight.semibold))),
                  GestureDetector(
                    onTap: () => setState(() {
                      final ids = shown.map((s) => s.contact.id);
                      if (ids.isNotEmpty && ids.every(_selected.contains)) {
                        _selected.removeAll(ids);
                      } else {
                        _selected.addAll(ids);
                      }
                    }),
                    child: Text(l.selectAll, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: AppWeight.semibold, color: pal.primary)),
                  ),
                ]),
              ),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final s in shown)
                    InkWell(
                      onTap: () => setState(() => _selected.contains(s.contact.id) ? _selected.remove(s.contact.id) : _selected.add(s.contact.id)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
                        child: Row(children: [
                          ContactAvatar(summary: s, size: AppSize.s40, fontSize: AppFont.label, showBadges: false),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: AppWeight.medium)),
                              Text(
                                [
                                  if (s.roles.isNotEmpty) roleLabel(l, s.roles.first),
                                  ratingLabel(l, ratingFromName(s.contact.rating)),
                                ].join(' · '),
                                style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2),
                              ),
                            ]),
                          ),
                          Container(
                            width: AppSize.s24,
                            height: AppSize.s24,
                            decoration: BoxDecoration(
                              color: _selected.contains(s.contact.id) ? pal.primary : null,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: _selected.contains(s.contact.id) ? null : Border.all(color: pal.handle, width: AppStroke.regular),
                            ),
                            child: _selected.contains(s.contact.id) ? Icon(Lu.check, size: AppIcon.sm, color: pal.onPrimary) : null,
                          ),
                        ]),
                      ),
                    ),
                ]),
              ),
              if (withNote > 0)
                Container(
                  margin: const EdgeInsets.only(top: AppSpace.md),
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.lg),
                  decoration: BoxDecoration(color: pal.noticeBg, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Lu.triangleAlert, size: AppIcon.lg, color: pal.noticeFg),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(child: Text(l.reportTempNote(withNote), style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.noticeInk))),
                  ]),
                ),
            ]),
          ),
          _nav(l, enabled: _selected.isNotEmpty, label: l.reportNextCount(_selected.length), onNext: () => setState(() => _step = 1)),
        ]);
      case 1:
        Widget sw(String t, bool v, ReportOptions Function(bool) f, {String? sub, bool first = false}) => SettingsSwitch(
              vpad: first ? 11 : 11,
              title: t,
              subtitle: sub,
              value: v,
              onChanged: (x) => setState(() => _options = f(x)),
            );
        Widget modePill(String label, bool on, VoidCallback tap) => Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpace.sm),
              child: GestureDetector(
                onTap: tap,
                child: Container(
                  height: AppControl.md,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  decoration: BoxDecoration(color: on ? pal.primary : pal.surface2, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Center(child: Text(label, style: TextStyle(fontSize: AppFont.meta, fontWeight: on ? AppWeight.semibold : AppWeight.medium, color: on ? pal.onPrimary : pal.text2))),
                ),
              ),
            );
        return Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xxl, 0, AppSpace.xxl, AppSpace.lg), children: [
              SectionLabel(l.reportModeLabel, padding: const EdgeInsets.fromLTRB(0, 0, 0, AppSpace.sm)),
              Row(children: [
                modePill(l.reportModeSummary, !_timeline, () => setState(() => _timeline = false)),
                modePill(l.reportModeTimeline, _timeline, () => setState(() => _timeline = true)),
              ]),
              const SizedBox(height: AppSpace.lg),
              if (_timeline)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.xs),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Lu.info, size: AppIcon.lg, color: pal.text2),
                    const SizedBox(width: AppSpace.md),
                    Expanded(child: Text(l.reportTimelineHint, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2))),
                  ]),
                )
              else
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  sw(l.reportPerformance, _options.performance, (v) => _options.copyWith(performance: v), sub: l.reportPerformanceSub),
                  sw(l.reportRequirements, _options.requirements, (v) => _options.copyWith(requirements: v)),
                  sw(l.reportBasics, _options.basics, (v) => _options.copyWith(basics: v)),
                  sw(l.reportHistory, _options.history, (v) => _options.copyWith(history: v)),
                  sw(l.reportDeals, _options.deals, (v) => _options.copyWith(deals: v)),
                  sw(l.reportTargets, _options.targets, (v) => _options.copyWith(targets: v)),
                ]),
              ),
            ]),
          ),
          _footer([
            SizedBox(width: AppControl.btnM, child: PillButton(label: l.reportBack, outlined: true, height: AppControl.lg, onPressed: () => setState(() => _step = 0))),
            Expanded(child: PillButton(label: l.reportNext, height: AppControl.lg, onPressed: _toPreview)),
          ]),
        ]);
      default:
        final locale = Locale(_lang);
        return Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xxl, 0, AppSpace.xxl, AppSpace.lg), children: [
              if (_timeline)
                Localizations.override(
                  context: context,
                  locale: locale,
                  child: Builder(
                    builder: (ctx) => Directionality(
                      textDirection: _lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                      child: ClipRect(
                        child: SizedBox(
                          height: AppSize.chartH * 3,
                          child: OverflowBox(
                            alignment: AlignmentDirectional.topStart,
                            minHeight: 0,
                            maxHeight: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.fitWidth,
                              alignment: AlignmentDirectional.topStart,
                              child: SizedBox(
                                width: timelineDrawWidth,
                                child: Column(children: [
                                  for (var c = 0, k = 0; c < _timelines.length; k += _timelines[c].entries.length + 1, c++) ...[
                                    RepaintBoundary(
                                      key: _tlKeys[k].key,
                                      child: TimelineHeader(timeline: _timelines[c], title: c == 0 ? _title.text : null, owner: _owner),
                                    ),
                                    for (var i = 0; i < _timelines[c].entries.length; i++)
                                      RepaintBoundary(key: _tlKeys[k + 1 + i].key, child: TimelineRow(entry: _timelines[c].entries[i])),
                                  ],
                                ]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
              Localizations.override(
                context: context,
                locale: locale,
                child: Builder(
                  builder: (ctx) => Directionality(
                    textDirection: _lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                    child: ClipRect(
                      child: SizedBox(
                        height: AppSize.chartH,
                        child: OverflowBox(
                          alignment: AlignmentDirectional.topStart,
                          minHeight: 0,
                          maxHeight: double.infinity,
                          child: Column(children: [
                            for (var i = 0; i < _clients.length; i++)
                              RepaintBoundary(
                                key: _keys[i],
                                child: _ReportCard(
                                  client: _clients[i],
                                  options: _options,
                                  title: i == 0 ? _title.text : null,
                                  owner: _owner,
                                  perf: i == 0 ? _perf : null,
                                  progress: i == 0 ? _prog : const [],
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.x3),
              Text(l.reportTitleLabel, style: const TextStyle(fontSize: AppFont.label, height: AppLine.normal, fontWeight: AppWeight.medium)),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: _title,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: AppFont.bodyL),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: pal.glass,
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: pal.glassBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: pal.primary)),
                ),
              ),
              SectionLabel(l.reportLanguage, padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.sm)),
              Row(children: [
                for (final e in [('en', l.langEnglish), ('ar', l.langArabic)])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: AppSpace.sm),
                    child: GestureDetector(
                      onTap: () => setState(() => _lang = e.$1),
                      child: Container(
                        height: AppControl.md,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                        decoration: BoxDecoration(color: _lang == e.$1 ? pal.primary : pal.surface2, borderRadius: BorderRadius.circular(AppRadius.sm)),
                        child: Center(child: Text(e.$2, style: TextStyle(fontSize: AppFont.meta, fontWeight: _lang == e.$1 ? AppWeight.semibold : AppWeight.medium, color: _lang == e.$1 ? pal.onPrimary : pal.text))),
                      ),
                    ),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.lg, AppSpace.xs, AppSpace.xs),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Lu.info, size: AppIcon.lg, color: pal.text2),
                  const SizedBox(width: AppSpace.md),
                  Expanded(child: Text(l.reportPrivacy, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2))),
                ]),
              ),
              const SizedBox(height: AppSpace.md),
              PillButton(label: l.presetSaveTitle, outlined: true, icon: Lu.bookmarkPlus, onPressed: _savePreset),
            ]),
          ),
          _footer([
            SizedBox(width: AppControl.btnS, child: PillButton(label: l.reportBack, outlined: true, height: AppControl.lg, onPressed: () => setState(() => _step = 1))),
            Expanded(child: PillButton(label: l.reportPdf, height: AppControl.lg, onPressed: _pdf)),
            Expanded(child: PillButton(label: l.reportCsv, height: AppControl.lg, onPressed: _csv)),
          ]),
        ]);
    }
  }

  Widget _footer(List<Widget> kids) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.sm, AppSpace.xxl, AppSpace.x3),
        child: Row(children: [
          for (var i = 0; i < kids.length; i++) ...[if (i > 0) const SizedBox(width: AppSpace.md), kids[i]],
        ]),
      );

  Widget _nav(AppLocalizations l, {required bool enabled, required VoidCallback onNext, String? label}) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.sm, AppSpace.xxl, AppSpace.x3),
        child: PillButton(label: label ?? l.reportNext, height: AppControl.lg, onPressed: enabled ? onNext : null),
      );
}

/// A client card drawn in fixed light colours so the PDF looks the same in either theme.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.client, required this.options, this.title, this.owner = '', this.perf, this.progress = const []});
  final String owner;
  final PeriodStats? perf;
  final List<(TargetValue, double, DateTime)> progress;
  final ReportClient client;
  final ReportOptions options;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = client.summary;
    const ink = PrintInk.ink;
    const soft = PrintInk.soft;
    Widget line(String t, {bool bold = false, Color color = ink}) =>
        Padding(padding: const EdgeInsets.only(top: AppSpace.xs), child: Text(t, style: TextStyle(fontSize: AppFont.meta, color: color, fontWeight: bold ? AppWeight.semibold : AppWeight.regular)));
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.all(AppSpace.lg),
      color: PrintInk.paper,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: ink),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[
            Text(owner.isEmpty ? l.appName : '$owner · ${l.appName}', style: const TextStyle(fontSize: AppFont.tiny, height: AppLine.normal, color: soft)),
            if (title!.isNotEmpty) Text(title!, style: const TextStyle(fontSize: AppFont.body, height: AppLine.snug, fontWeight: AppWeight.semibold)),
            const Padding(padding: EdgeInsets.symmetric(vertical: AppSpace.sm), child: Divider(height: AppStroke.hairline, thickness: AppStroke.hairline, color: PrintInk.divider)),
            if (perf != null) ...[
              line('${l.reportLast30}: ${[
                '${metricLabel(l, Metric.calls)} ${perf!.calls}',
                '${metricLabel(l, Metric.visits)} ${perf!.visits}',
                '${metricLabel(l, Metric.meetings)} ${perf!.meetings}',
                '${metricLabel(l, Metric.messages)} ${perf!.messages}',
                '${metricLabel(l, Metric.newContacts)} ${perf!.newContacts}',
              ].join(' · ')}', bold: true),
              const SizedBox(height: AppSpace.sm),
            ],
            for (final t in progress) line('${metricLabel(l, t.$1.metric)}: ${t.$2.round()} / ${t.$1.value.round()}', color: soft),
            if (progress.isNotEmpty) const SizedBox(height: AppSpace.sm),
          ],
          Text(s.fullName, style: const TextStyle(fontSize: AppFont.meta, height: AppLine.snug, fontWeight: AppWeight.semibold)),
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
