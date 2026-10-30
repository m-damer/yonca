import 'dart:io';

import 'package:flutter/material.dart';
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
import '../sharing/share_helpers.dart';

/// Settings keys of the user's own profile.
const profileKeys = [
  'profile.name',
  'profile.job',
  'profile.company',
  'profile.phone',
  'profile.work',
  'profile.email',
  'profile.website',
  'profile.address',
  'profile.photo',
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
      height: 40,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: pal.avBg, borderRadius: BorderRadius.circular(8)),
      child: has
          ? Image.file(File(photo), width: 40, height: 40, fit: BoxFit.cover)
          : Text(name.trim().isEmpty ? '' : initialsOf(name), style: TextStyle(color: pal.avFg, fontWeight: FontWeight.w600, fontSize: 22)),
    );
  }
}

/// My profile (design RC1): your own card with a QR code others can scan. Also used in report headers.
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
    final role = [t('profile.job'), t('profile.company')].where((s) => s.isNotEmpty).join(' · ');
    final rows = <(IconData, String, String)>[
      if (t('profile.phone').isNotEmpty) (Icons.phone_outlined, t('profile.phone'), l.labelMobile),
      if (t('profile.work').isNotEmpty) (Icons.phone_outlined, t('profile.work'), l.labelWork),
      if (t('profile.email').isNotEmpty) (Icons.mail_outline, t('profile.email'), l.fieldEmail),
      if (t('profile.website').isNotEmpty) (Icons.language, t('profile.website'), l.fieldWebsite),
      if (t('profile.address').isNotEmpty) (Icons.location_on_outlined, t('profile.address'), l.fieldAddress),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              Expanded(child: Text(l.profileTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: pal.onHeader))),
              GlassIconButton(icon: Icons.edit_outlined, onHeader: true, tooltip: l.edit, onTap: _edit),
            ]),
          ),
          Expanded(
            child: v == null
                ? const SizedBox.shrink()
                : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
                    Center(child: _ProfileAvatar(name: t('profile.name'), photo: t('profile.photo'))),
                    const SizedBox(height: 10),
                    Center(child: Text(t('profile.name'), style: const TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600))),
                    if (role.isNotEmpty) Center(child: Text(role, style: TextStyle(fontSize: 15, height: 21 / 15, color: pal.text2))),
                    const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: pal.separator)),
                          child: QrImageView(data: profileVCard(v), size: 96, errorCorrectionLevel: QrErrorCorrectLevel.L, backgroundColor: Colors.white, padding: EdgeInsets.zero),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.profileQrTitle, style: const TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(l.profileQrNote, style: TextStyle(fontSize: 13, height: 18 / 13, color: pal.text2)),
                          ]),
                        ),
                      ]),
                    ),
                    if (rows.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SettingsGroup(children: [for (final r in rows) SettingsRow(icon: r.$1, title: r.$2, subtitle: r.$3)]),
                    ],
                    const SizedBox(height: 16),
                    PillButton(label: l.shareMyContact, icon: Icons.ios_share, height: 48, onPressed: () => _share(v)),
                  ]),
          ),
        ]),
      ),
    );
  }
}

/// Edit profile (design RC2).
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key, required this.db});
  final AppDatabase db;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _c = {for (final k in profileKeys) k: TextEditingController()};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await loadProfile(widget.db);
    for (final k in profileKeys) {
      _c[k]!.text = v[k] ?? '';
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    for (final k in profileKeys) {
      await widget.db.putSetting(k, _c[k]!.text.trim());
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
        SheetItem(first: true, icon: Icons.photo_camera_outlined, title: l.photoTake, onTap: () => Navigator.of(ctx).pop('camera')),
        SheetItem(icon: Icons.photo_library_outlined, title: l.photoGallery, onTap: () => Navigator.of(ctx).pop('gallery')),
        if (photo.text.isNotEmpty) SheetItem(icon: Icons.delete_outline, title: l.photoRemove, danger: true, onTap: () => Navigator.of(ctx).pop('remove')),
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    Widget field(String k, String label, {TextInputType? type}) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GlassField(controller: _c[k]!, label: label, keyboardType: type),
        );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.close, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              Expanded(child: Text(l.editProfile, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: pal.onHeader))),
              SizedBox(width: 80, child: PillButton(label: l.save, height: 44, accent: true, onPressed: _save)),
            ]),
          ),
          Expanded(
            child: !_loaded
                ? const SizedBox.shrink()
                : LabelInset(
                    inset: 0,
                    child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
                      Center(child: _ProfileAvatar(name: _c['profile.name']!.text, photo: _c['profile.photo']!.text)),
                      const SizedBox(height: 10),
                      Center(
                        child: SizedBox(width: 164, child: PillButton(label: _c['profile.photo']!.text.isEmpty ? l.addPhoto : l.changePhoto, icon: Icons.photo_camera_outlined, outlined: true, height: 36, onPressed: _photo)),
                      ),
                      const SizedBox(height: 20),
                      field('profile.name', l.fieldName),
                      field('profile.job', l.fieldJobTitle),
                      field('profile.company', l.fieldCompany),
                      field('profile.phone', l.labelMobile, type: TextInputType.phone),
                      field('profile.work', l.fieldWorkPhone, type: TextInputType.phone),
                      field('profile.email', l.fieldEmail, type: TextInputType.emailAddress),
                      field('profile.website', l.fieldWebsite, type: TextInputType.url),
                      field('profile.address', l.fieldAddress),
                      Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 0), child: Text(l.profileLocalNote, style: TextStyle(fontSize: 13, height: 18 / 13, color: pal.text2))),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }
}

/// The user's own business card as a vCard, from the saved profile settings.
String profileVCard(Map<String, String> v) {
  String e(String s) => s.replaceAll(r'\', r'\\').replaceAll(';', r'\;').replaceAll(',', r'\,');
  String t(String k) => (v[k] ?? '').trim();
  String tel(String k) => t(k).replaceAll(' ', '');
  final name = t('profile.name');
  final b = StringBuffer('BEGIN:VCARD\r\nVERSION:3.0\r\nFN:${e(name)}\r\nN:;${e(name)};;;\r\n');
  if (t('profile.company').isNotEmpty) b.write('ORG:${e(t('profile.company'))}\r\n');
  if (t('profile.job').isNotEmpty) b.write('TITLE:${e(t('profile.job'))}\r\n');
  if (t('profile.phone').isNotEmpty) b.write('TEL;TYPE=CELL:${tel('profile.phone')}\r\n');
  if (t('profile.work').isNotEmpty) b.write('TEL;TYPE=WORK:${tel('profile.work')}\r\n');
  if (t('profile.email').isNotEmpty) b.write('EMAIL:${e(t('profile.email'))}\r\n');
  if (t('profile.website').isNotEmpty) b.write('URL:${e(t('profile.website'))}\r\n');
  if (t('profile.address').isNotEmpty) b.write('ADR:;;${e(t('profile.address'))};;;;\r\n');
  b.write('END:VCARD\r\n');
  return b.toString();
}
