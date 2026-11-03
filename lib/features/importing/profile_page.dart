import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../shared/ds.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../contacts/contact_widgets.dart';
import '../settings/settings_widgets.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';
import '../sharing/qr_models.dart';
import '../sharing/share_helpers.dart' show QrShowPage;

/// Settings keys of the user's own profile.
const profileKeys = [
  'profile.name',
  'profile.job',
  'profile.company',
  'profile.photo',
  'profile.rows',
  // Older single-value keys, still read once to build the rows of a profile saved before there were many rows.
  'profile.phone',
  'profile.work',
  'profile.email',
  'profile.website',
  'profile.address',
];

Future<Map<String, String>> loadProfile(AppDatabase db) async => {for (final k in profileKeys) k: await db.getSetting(k) ?? ''};

/// Square avatar with the photo or the initial (design RC1/RC2).
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name, required this.photo});
  final String name;
  final String photo;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final has = photo.isNotEmpty && File(photo).existsSync();
    return Container(
      width: 40,
      height: AppControl.md,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: pal.avBg, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: has
          ? Image.file(File(photo), width: 40, height: 40, fit: BoxFit.cover)
          : Text(name.trim().isEmpty ? '' : initialsOf(name), style: TextStyle(color: pal.avFg, fontWeight: FontWeight.w600, fontSize: AppFont.pageTitle)),
    );
  }
}

/// My profile (design RC1): your own card with a QR code others can scan. Also used in report headers.
/// One phone, email, website or address of the profile, and whether it goes in the QR code.
class ProfileRow {
  ProfileRow(this.kind, this.label, this.value, this.qr);
  final String kind;
  String label;
  String value;
  bool qr;

  Map<String, dynamic> toJson() => {'k': kind, 'l': label, 'v': value, 'q': qr};
  factory ProfileRow.fromJson(Map<String, dynamic> j) => ProfileRow(j['k'] as String, j['l'] as String, j['v'] as String, j['q'] as bool? ?? false);
}

/// The profile's rows. A profile saved before rows existed is read from the old keys:
/// the first phone and the first email start ticked for the QR code.
List<ProfileRow> profileRows(Map<String, String> v) {
  final raw = (v['profile.rows'] ?? '').trim();
  if (raw.isNotEmpty) {
    try {
      return [for (final x in jsonDecode(raw) as List) ProfileRow.fromJson(x as Map<String, dynamic>)];
    } catch (_) {}
  }
  String t(String k) => (v[k] ?? '').trim();
  return [
    if (t('profile.phone').isNotEmpty) ProfileRow('phone', 'mobile', t('profile.phone'), true),
    if (t('profile.work').isNotEmpty) ProfileRow('phone', 'work', t('profile.work'), false),
    if (t('profile.email').isNotEmpty) ProfileRow('email', 'work', t('profile.email'), true),
    if (t('profile.website').isNotEmpty) ProfileRow('website', 'other', t('profile.website'), false),
    if (t('profile.address').isNotEmpty) ProfileRow('address', 'other', t('profile.address'), false),
  ];
}

String encodeProfileRows(List<ProfileRow> rows) => jsonEncode([for (final r in rows) r.toJson()]);

String profileLabelText(AppLocalizations l, String key) => switch (key) {
      'mobile' => l.labelMobile,
      'landline' => l.labelLandline,
      'work' => l.labelWork,
      'home' => l.labelHome,
      'personal' => l.labelPersonal,
      _ => l.labelOther,
    };

/// The lines that go in the QR code and in the shared contact: the name, job, company and every ticked row.
List<QrField> profileQrFields(Map<String, String> v) {
  String t(String k) => (v[k] ?? '').trim();
  return [
    if (t('profile.name').isNotEmpty) QrField('first', '', t('profile.name')),
    if (t('profile.job').isNotEmpty) QrField('job', '', t('profile.job')),
    if (t('profile.company').isNotEmpty) QrField('company', '', t('profile.company')),
    for (final r in profileRows(v))
      if (r.qr && r.value.trim().isNotEmpty) QrField(r.kind, r.kind == 'phone' ? r.label : '', r.value.trim()),
  ];
}

/// The user's own business card as a vCard, from the ticked lines of the profile.
String profileVCard(Map<String, String> v) => qrVCard(profileQrFields(v));

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.db});
  final AppDatabase db;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, String>? _v;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await loadProfile(widget.db);
    if (mounted) setState(() => _v = v);
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileEditPage(db: widget.db)));
    await _load();
  }

  Future<void> _toggle(List<ProfileRow> rows, ProfileRow r, bool on) async {
    setState(() => r.qr = on);
    final enc = encodeProfileRows(rows);
    _v!['profile.rows'] = enc;
    await widget.db.putSetting('profile.rows', enc);
  }

  Future<void> _share(Map<String, String> v) async {
    final dir = await getTemporaryDirectory();
    final name = (v['profile.name'] ?? '').trim();
    final f = File('${dir.path}/${name.isEmpty ? 'contact' : name.replaceAll(RegExp(r'[^\w\- ]'), '_')}.vcf');
    await f.writeAsString(profileVCard(v));
    await Share.shareXFiles([XFile(f.path, mimeType: 'text/vcard')]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final v = _v;
    String t(String k) => (v?[k] ?? '').trim();
    final rows = v == null ? <ProfileRow>[] : profileRows(v);
    final role = [t('profile.job'), t('profile.company')].where((s) => s.isNotEmpty).join(' · ');
    Widget card(String title, String kind, IconData icon) {
      final list = rows.where((r) => r.kind == kind && r.value.trim().isNotEmpty).toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionLabel(title),
        SettingsGroup(children: [
          for (final r in list)
            SettingsRow(
              icon: icon,
              title: r.value,
              subtitle: profileLabelText(l, r.label),
              onTap: () => _toggle(rows, r, !r.qr),
              trailing: Semantics(label: l.profileInQr, child: AppSwitch(value: r.qr, onChanged: (x) => _toggle(rows, r, x))),
            ),
        ]),
      ]);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(title: l.profileTitle, actions: [GlassIconButton(icon: Lu.pencil, onHeader: true, tooltip: l.edit, onTap: _edit)]),
          Expanded(
            child: v == null
                ? const SizedBox.shrink()
                : ListView(padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.x5), children: [
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QrShowPage(title: t('profile.name'), data: profileVCard(v)))),
                        child: Padding(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpace.sm),
                          decoration: BoxDecoration(color: pal.qrPaper, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: pal.separator)),
                          child: QrImageView(data: profileVCard(v), size: AppControl.hero * 1.5, errorCorrectionLevel: QrErrorCorrectLevel.L, backgroundColor: pal.qrPaper, padding: EdgeInsets.zero),
                        ),
                        const SizedBox(width: AppSpace.lg),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.profileQrTitle, style: const TextStyle(fontSize: AppFont.subtitle, height: AppLine.normal, fontWeight: FontWeight.w600)),
                            const SizedBox(height: AppSpace.xs),
                            Text(l.qrFieldCount(profileQrFields(v).length), style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2)),
                            const SizedBox(height: AppSpace.xs),
                            Text(l.profileQrNote, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2)),
                          ]),
                        ),
                      ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    GlassCard(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      child: Row(children: [
                        _ProfileAvatar(name: t('profile.name'), photo: t('profile.photo')),
                        const SizedBox(width: AppSpace.lg),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t('profile.name'), style: const TextStyle(fontSize: AppFont.pageTitle, height: AppLine.snug, fontWeight: FontWeight.w600)),
                            if (role.isNotEmpty) Text(role, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: pal.text2)),
                          ]),
                        ),
                      ]),
                    ),
                    card(l.profilePhones, 'phone', Lu.phone),
                    card(l.profileEmails, 'email', Lu.mail),
                    card(l.fieldWebsite, 'website', Lu.globe),
                    card(l.fieldAddress, 'address', Lu.mapPin),
                    const SizedBox(height: AppSpace.lg),
                    PillButton(label: l.shareMyContact, icon: Lu.share, height: AppControl.lg, onPressed: () => _share(v)),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class _EditRow {
  _EditRow(this.kind, this.label, String value, this.qr) : value = TextEditingController(text: value);
  final String kind;
  String label;
  final TextEditingController value;
  bool qr;
}

/// Edit profile (design RC2): photo, name, job, company, then any number of phones, emails, websites and addresses.
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key, required this.db});
  final AppDatabase db;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _c = {for (final k in ['profile.name', 'profile.job', 'profile.company', 'profile.photo']) k: TextEditingController()};
  final _rows = <_EditRow>[];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await loadProfile(widget.db);
    for (final k in _c.keys) {
      _c[k]!.text = v[k] ?? '';
    }
    for (final r in profileRows(v)) {
      _rows.add(_EditRow(r.kind, r.label, r.value, r.qr));
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    for (final r in _rows) {
      r.value.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    for (final e in _c.entries) {
      await widget.db.putSetting(e.key, e.value.text.trim());
    }
    final rows = [for (final r in _rows) if (r.value.text.trim().isNotEmpty) ProfileRow(r.kind, r.label, r.value.text.trim(), r.qr)];
    await widget.db.putSetting('profile.rows', encodeProfileRows(rows));
    // The old single-value keys are now part of the rows.
    for (final k in ['profile.phone', 'profile.work', 'profile.email', 'profile.website', 'profile.address']) {
      await widget.db.putSetting(k, '');
    }
    nav.pop();
  }

  Future<void> _photo() async {
    final l = AppLocalizations.of(context);
    final photo = _c['profile.photo']!;
    final v = await showGlassSheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.photoTitle),
        SheetItem(first: true, icon: Lu.camera, title: l.photoTake, onTap: () => Navigator.of(ctx).pop('camera')),
        SheetItem(icon: Lu.images, title: l.photoGallery, onTap: () => Navigator.of(ctx).pop('gallery')),
        if (photo.text.isNotEmpty) SheetItem(icon: Lu.trash2, title: l.photoRemove, danger: true, onTap: () => Navigator.of(ctx).pop('remove')),
      ]),
    );
    if (v == null || !mounted) return;
    if (v == 'remove') {
      setState(() => photo.text = '');
      return;
    }
    try {
      final x = await ImagePicker().pickImage(source: v == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (x == null) return;
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/contact_photos');
      await dir.create(recursive: true);
      final dest = '${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(x.path).copy(dest);
      if (mounted) setState(() => photo.text = dest);
    } catch (_) {}
  }

  Future<void> _pickLabel(_EditRow r) async {
    final l = AppLocalizations.of(context);
    final keys = switch (r.kind) {
      'phone' => ['mobile', 'landline', 'work', 'home', 'other'],
      'email' => ['work', 'personal', 'other'],
      _ => ['work', 'home', 'other'],
    };
    final k = await showGlassSheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < keys.length; i++) SheetItem(first: i == 0, title: profileLabelText(l, keys[i]), selected: r.label == keys[i], onTap: () => Navigator.of(ctx).pop(keys[i])),
      ]),
    );
    if (k != null && mounted) setState(() => r.label = k);
  }

  Widget _section(AppLocalizations l, String kind, String title, String addLabel, TextInputType? type) {
    final pal = context.palette;
    final list = _rows.where((r) => r.kind == kind).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionLabel(title),
      for (final r in list)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            InkWell(
              onTap: () => _pickLabel(r),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                height: AppControl.lg,
                constraints: const BoxConstraints(minWidth: AppControl.hero),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(profileLabelText(l, r.label), style: TextStyle(fontSize: AppFont.label, fontWeight: FontWeight.w500, color: pal.text)),
                  const SizedBox(width: AppSpace.xs),
                  Icon(Lu.chevronDown, size: AppIcon.sm, color: pal.text2),
                ]),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: GlassField(controller: r.value, label: title, keyboardType: type, forceLtr: kind != 'address')),
            const SizedBox(width: AppSpace.sm),
            GlassIconButton(
              icon: Lu.x,
              onTap: () => setState(() {
                _rows.remove(r);
                r.value.dispose();
              }),
            ),
          ]),
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: InkWell(
          onTap: () => setState(() => _rows.add(_EditRow(kind, kind == 'phone' ? 'mobile' : (kind == 'email' ? 'work' : 'other'), '', list.isEmpty))),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Lu.plus, size: AppIcon.md, color: pal.primary),
              const SizedBox(width: AppSpace.sm),
              Text(addLabel, style: TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w600, color: pal.primary)),
            ]),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    Widget field(String k, String label) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          child: GlassField(controller: _c[k]!, label: label),
        );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(
            title: l.editProfile,
            close: true,
            actions: [SizedBox(width: AppControl.btnS, child: PillButton(label: l.save, height: AppControl.lg, accent: true, onPressed: _save))],
          ),
          Expanded(
            child: !_loaded
                ? const SizedBox.shrink()
                : LabelInset(
                    inset: 0,
                    child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.x5), children: [
                      Center(child: _ProfileAvatar(name: _c['profile.name']!.text, photo: _c['profile.photo']!.text)),
                      const SizedBox(height: AppSpace.md),
                      Center(
                        child: SizedBox(width: AppControl.btnL, child: PillButton(label: _c['profile.photo']!.text.isEmpty ? l.addPhoto : l.changePhoto, icon: Lu.camera, outlined: true, height: AppControl.md, onPressed: _photo)),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      field('profile.name', l.fieldName),
                      field('profile.job', l.fieldJobTitle),
                      field('profile.company', l.fieldCompany),
                      _section(l, 'phone', l.profilePhones, l.addPhone, TextInputType.phone),
                      _section(l, 'email', l.profileEmails, l.addEmail, TextInputType.emailAddress),
                      _section(l, 'website', l.fieldWebsite, l.addWebsite, TextInputType.url),
                      _section(l, 'address', l.fieldAddress, l.addAddress, null),
                      const SizedBox(height: AppSpace.lg),
                      Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, 0), child: Text(l.profileLocalNote, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2))),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }
}
