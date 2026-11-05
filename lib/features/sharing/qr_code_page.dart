import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_controller.dart';
import '../../domain/contact_models.dart';
import '../../domain/field_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/multi_select.dart';
import '../../shared/permission_primer.dart';
import '../../shared/scroll_fab.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/lucide.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../importing/scan_page.dart';
import '../settings/settings_widgets.dart';
import 'qr_detail_page.dart';
import 'qr_manual_page.dart';
import 'qr_models.dart';

/// QR Code (More tab): the saved codes, a floating "+" to make one, and a scan button in the header.
class QrCodePage extends StatefulWidget {
  const QrCodePage({super.key, required this.controller});
  final AppController controller;

  @override
  State<QrCodePage> createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage> {
  List<SavedQr> _items = const [];
  bool _loaded = false;

  QrStore? get _store => widget.controller.database == null ? null : QrStore(widget.controller.database!);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _store?.load() ?? const <SavedQr>[];
    if (mounted) {
      setState(() {
        _items = r;
        _loaded = true;
      });
    }
  }

  Future<void> _open(SavedQr q) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => QrDetailPage(store: _store!, qr: q)));
    _load();
  }

  Future<void> _new() async {
    final l = AppLocalizations.of(context);
    final src = await showGlassSheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.qrNew),
        SheetItem(first: true, icon: Lu.contactRound, title: l.qrSrcApp, onTap: () => Navigator.of(ctx).pop('app')),
        SheetItem(icon: Lu.smartphone, title: l.qrSrcPhone, onTap: () => Navigator.of(ctx).pop('phone')),
        SheetItem(icon: Lu.pencil, title: l.qrSrcManual, onTap: () => Navigator.of(ctx).pop('manual')),
      ]),
    );
    if (src == null || !mounted) return;
    List<QrField>? fields;
    switch (src) {
      case 'app':
        fields = await _fromApp(l);
      case 'phone':
        fields = await _fromPhone(l);
      default:
        fields = await Navigator.of(context).push<List<QrField>>(MaterialPageRoute(builder: (_) => const QrManualPage()));
    }
    if (fields == null || fields.isEmpty || !mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => QrFieldsPage(store: _store!, fields: fields!)));
    _load();
  }

  Future<List<QrField>?> _fromApp(AppLocalizations l) async {
    final repo = widget.controller.contacts;
    if (repo == null) return null;
    final all = await repo.list(sort: ContactSort.name);
    if (!mounted) return null;
    final r = await showSearchableSelect(
      context,
      title: l.qrContactLabel,
      options: [for (final s in all) if (s.fullName.isNotEmpty) PickOption(s.contact.id, s.fullName)],
      selected: const {},
      multi: false,
    );
    final id = r?.whereType<int>().firstOrNull;
    if (id == null) return null;
    final s = all.firstWhere((x) => x.contact.id == id);
    final fr = widget.controller.fields;
    final custom = <String, String>{};
    if (fr != null) {
      final defs = await fr.fields(FieldScope.contact);
      final vals = await fr.values(FieldScope.contact, id);
      for (final d in defs) {
        final v = (vals[d.id] ?? '').trim();
        if (v.isNotEmpty) custom[d.name] = v;
      }
    }
    return qrFieldsFromContact(l, s, custom: custom);
  }

  Future<List<QrField>?> _fromPhone(AppLocalizations l) async {
    try {
      if (!await PermissionPrimer.once(context, 'contacts', icon: Lu.users, title: l.navContacts, body: l.permContactsBody)) return null;
      if (!await fc.FlutterContacts.requestPermission(readonly: true)) return null;
      final c = await fc.FlutterContacts.openExternalPick();
      if (c == null) return null;
      final full = await fc.FlutterContacts.getContact(c.id, withProperties: true, withPhoto: false) ?? c;
      final org = full.organizations.isEmpty ? null : full.organizations.first;
      return [
        QrField('prefix', l.fieldPrefix, full.name.prefix),
        QrField('first', l.fieldFirstName, full.name.first),
        QrField('last', l.fieldLastName, full.name.last),
        QrField('job', l.fieldJobTitle, org?.title ?? ''),
        QrField('dept', l.fieldDepartment, org?.department ?? ''),
        QrField('company', l.fieldCompany, org?.company ?? ''),
        for (final p in full.phones) QrField('phone', l.fieldPhone, p.number.replaceAll(' ', '')),
        for (final e in full.emails) QrField('email', l.fieldEmail, e.address),
        for (final w in full.websites) QrField('website', l.fieldWebsite, w.url),
        for (final a in full.addresses) QrField('address', l.fieldAddress, a.address),
      ].where((f) => f.value.trim().isNotEmpty).toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final repo = widget.controller.contacts;
    return FabScope(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          SettingsScaffold(
            title: l.qrCodeTitle,
            actions: [
              if (repo != null)
                GlassIconButton(
                  icon: Lu.scanLine,
                  onHeader: true,
                  tooltip: l.scanQr,
                  onTap: () => Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => ScanPage(repo: repo))),
                ),
            ],
            children: [
              if (_loaded && _items.isEmpty)
                Padding(padding: const EdgeInsets.only(top: AppSpace.x5), child: EmptyState(icon: Lu.qrCode, title: l.qrEmpty, body: l.qrEmptyBody)),
              for (final q in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: InkWell(
                      onTap: () => _open(q),
                      child: Row(children: [
                        Container(
                          color: p.qrPaper,
                          padding: const EdgeInsets.all(AppSpace.xs),
                          child: QrImageView(data: q.data, size: AppControl.xl, errorCorrectionLevel: qrLevel(q.data, logo: false), backgroundColor: p.qrPaper),
                        ),
                        const SizedBox(width: AppSpace.lg),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(q.title.isEmpty ? l.qrUntitled : q.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.semibold)),
                            Text(qrDateText(context, q.createdAt), style: TextStyle(fontSize: AppFont.meta, color: p.text2)),
                          ]),
                        ),
                        Icon(Lu.chevronRight, size: AppIcon.md, color: p.text2),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
          PositionedDirectional(
            end: AppSpace.lg,
            bottom: AppSpace.lg + MediaQuery.of(context).padding.bottom,
            child: ExpandingFab(label: l.qrNew, onPressed: _new),
          ),
        ]),
      ),
    );
  }
}

/// Step two: tick the fields that go in the code, set the optional title and logo, then Continue saves the code.
class QrFieldsPage extends StatefulWidget {
  const QrFieldsPage({super.key, required this.store, required this.fields});
  final QrStore store;
  final List<QrField> fields;

  @override
  State<QrFieldsPage> createState() => _QrFieldsPageState();
}

class _QrFieldsPageState extends State<QrFieldsPage> {
  late final Set<int> _on = {for (var i = 0; i < widget.fields.length; i++) i};
  final _title = TextEditingController();
  String _logo = '';
  bool _useLogo = true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  List<QrField> get _chosen => [for (var i = 0; i < widget.fields.length; i++) if (_on.contains(i)) widget.fields[i]];

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (x == null) return;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/qr_logos');
    await dir.create(recursive: true);
    final dest = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.png';
    await File(x.path).copy(dest);
    if (mounted) {
      setState(() {
        _logo = dest;
        _useLogo = true;
      });
    }
  }

  Future<void> _continue() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    final f = _chosen;
    String one(String k) => f.where((x) => x.kind == k).map((x) => x.value).firstOrNull ?? '';
    var title = _title.text.trim();
    if (title.isEmpty) title = [one('first'), one('last')].where((e) => e.isNotEmpty).join(' ');
    if (title.isEmpty) title = one('company');
    if (title.isEmpty) title = l.qrUntitled;
    final q = await widget.store.add(title: title, fields: f, logoPath: _logo, includeLogo: _useLogo && _logo.isNotEmpty);
    nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => QrDetailPage(store: widget.store, qr: q)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final fits = qrFits(qrVCard(_chosen));
    Widget link(String t, VoidCallback onTap) => InkWell(onTap: onTap, child: Text(t, style: TextStyle(color: p.primary, fontWeight: AppWeight.semibold, fontSize: AppFont.body)));
    return SettingsScaffold(
      title: l.qrChooseFields,
      children: [
        const SizedBox(height: AppSpace.sm),
        Row(children: [
          Expanded(child: Text(l.qrFieldCount(_on.length), style: TextStyle(fontSize: AppFont.label, color: p.text2))),
          link(l.qrAll, () => setState(() => _on.addAll(List.generate(widget.fields.length, (i) => i)))),
          const SizedBox(width: AppSpace.xl),
          link(l.qrNone, () => setState(_on.clear)),
        ]),
        const SizedBox(height: AppSpace.sm),
        SettingsGroup(children: [
          for (var i = 0; i < widget.fields.length; i++)
            InkWell(
              onTap: () => setState(() => _on.contains(i) ? _on.remove(i) : _on.add(i)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
                child: Row(children: [
                  Container(
                    width: AppIcon.lg,
                    height: AppIcon.lg,
                    decoration: BoxDecoration(
                      color: _on.contains(i) ? p.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      border: Border.all(color: _on.contains(i) ? p.primary : p.handle, width: AppStroke.regular),
                    ),
                    child: _on.contains(i) ? Icon(Lu.check, size: AppIcon.sm, color: p.onPrimary) : null,
                  ),
                  const SizedBox(width: AppSpace.lg),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.fields[i].label, style: TextStyle(fontSize: AppFont.meta, color: p.text2)),
                      Text(widget.fields[i].value, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.medium)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
        SectionLabel(l.qrOptions),
        GlassField(controller: _title, label: l.qrTitleOpt),
        const SizedBox(height: AppSpace.md),
        SettingsGroup(children: [
          SettingsRow(
            title: l.qrLogo,
            subtitle: _logo.isEmpty ? l.qrAddLogo : null,
            onTap: _pickLogo,
            trailing: _logo.isEmpty
                ? Icon(Lu.images, size: AppIcon.md, color: p.text2)
                : ClipRRect(borderRadius: BorderRadius.circular(AppRadius.sm), child: Image.file(File(_logo), width: AppControl.md, height: AppControl.md, fit: BoxFit.cover)),
          ),
          if (_logo.isNotEmpty) SettingsSwitch(title: l.qrIncludeLogo, value: _useLogo, onChanged: (v) => setState(() => _useLogo = v)),
        ]),
        if (!fits) Padding(padding: const EdgeInsets.only(top: AppSpace.md), child: Text(l.qrTooMuch, style: TextStyle(fontSize: AppFont.label, color: p.error))),
        const SizedBox(height: AppSpace.xl),
        PillButton(label: l.qrContinue, height: AppControl.lg, onPressed: (_on.isEmpty || !fits || _saving) ? null : _continue),
      ],
    );
  }
}
