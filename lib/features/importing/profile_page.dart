import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../shared/ds.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../../core/phone_split.dart';
import '../contacts/contact_widgets.dart';
import '../contacts/country_sheet.dart';
import '../contacts/form_rows.dart';
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

/// Edit profile: the same form as a contact (photo, name, company, phones, emails, websites, addresses),
/// built from the same shared widgets so the two cannot drift apart.
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key, required this.db});
  final AppDatabase db;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _job = TextEditingController();
  final _company = TextEditingController();
  String _photo = '';
  final _phones = <PhoneFormRow>[];
  final _entries = {for (final k in const ['email', 'website', 'address']) k: <EntryFormRow>[]};
  // Which of the rows are ticked for the QR code (kept as they were; the switch lives on the profile page).
  final _qr = <Object, bool>{};
  String? _expanded;
  bool _labelSheetOpen = false;
  bool _phoneShort = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  PhoneFormRow _newPhone({String code = '+963', String number = '', String label = 'mobile'}) {
    final row = PhoneFormRow(code: code, number: number, label: label);
    row.focus.addListener(() {
      if (!mounted) return;
      final key = 'phone:${_phones.indexOf(row)}';
      if (row.focus.hasFocus) {
        if (_expanded != key) setState(() => _expanded = key);
      } else if (!_labelSheetOpen && _expanded == key) {
        setState(() => _expanded = null);
      }
    });
    return row;
  }

  EntryFormRow _newEntry(String kind, {String value = '', String label = 'work'}) {
    final row = EntryFormRow(value: value, label: label);
    row.focus.addListener(() {
      if (!mounted) return;
      final key = '$kind:${_entries[kind]!.indexOf(row)}';
      if (row.focus.hasFocus) {
        if (_expanded != key) setState(() => _expanded = key);
      } else if (!_labelSheetOpen && _expanded == key) {
        setState(() => _expanded = null);
      }
    });
    return row;
  }

  Future<void> _load() async {
    final v = await loadProfile(widget.db);
    final name = (v['profile.name'] ?? '').trim();
    final cut = name.lastIndexOf(' ');
    _first.text = cut < 0 ? name : name.substring(0, cut);
    _last.text = cut < 0 ? '' : name.substring(cut + 1);
    _job.text = v['profile.job'] ?? '';
    _company.text = v['profile.company'] ?? '';
    _photo = v['profile.photo'] ?? '';
    for (final r in profileRows(v)) {
      final label = r.label == 'personal' ? 'home' : r.label;
      if (r.kind == 'phone') {
        final (code, number) = splitPhone(r.value);
        final row = _newPhone(code: code.isEmpty ? '+963' : code, number: code.isEmpty ? r.value : number, label: label);
        _phones.add(row);
        _qr[row] = r.qr;
      } else if (_entries.containsKey(r.kind)) {
        final row = _newEntry(r.kind, value: r.value, label: label);
        _entries[r.kind]!.add(row);
        _qr[row] = r.qr;
      }
    }
    if (_phones.isEmpty) _phones.add(_newPhone());
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _job.dispose();
    _company.dispose();
    for (final r in _phones) {
      r.dispose();
    }
    for (final list in _entries.values) {
      for (final r in list) {
        r.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    final short = _phones.any((p) => p.label != 'landline' && phoneTooShort(p.code, p.number.text));
    setState(() => _phoneShort = short);
    if (short) return;
    final nav = Navigator.of(context);
    final db = widget.db;
    await db.putSetting('profile.name', [_first.text.trim(), _last.text.trim()].where((e) => e.isNotEmpty).join(' '));
    await db.putSetting('profile.job', _job.text.trim());
    await db.putSetting('profile.company', _company.text.trim());
    await db.putSetting('profile.photo', _photo);
    final rows = <ProfileRow>[
      for (final p in _phones)
        if (p.number.text.trim().isNotEmpty)
          ProfileRow('phone', p.label, '${p.code} ${p.label == 'landline' ? p.number.text.replaceAll(RegExp(r'\s'), '') : p.number.text.trim()}', _qr[p] ?? _phones.first == p),
      for (final kind in const ['email', 'website', 'address'])
        for (final e in _entries[kind]!)
          if (e.value.text.trim().isNotEmpty) ProfileRow(kind, e.label, e.value.text.trim(), _qr[e] ?? _entries[kind]!.first == e),
    ];
    await db.putSetting('profile.rows', encodeProfileRows(rows));
    // The old single-value keys are now part of the rows.
    for (final k in ['profile.phone', 'profile.work', 'profile.email', 'profile.website', 'profile.address']) {
      await db.putSetting(k, '');
    }
    nav.pop();
  }

  Future<void> _photoSheet() async {
    final v = await pickFormPhoto(context, hasPhoto: _photo.isNotEmpty, prefix: 'profile_');
    if (v == null || !mounted) return;
    setState(() => _photo = v);
  }

  Future<String?> _chooseLabel(String title, List<String> options, String current, {String kind = ''}) async {
    _labelSheetOpen = true;
    final picked = await chooseFormLabel(context, title, options, current, kind: kind);
    _labelSheetOpen = false;
    return picked;
  }

  Future<void> _pickCode(PhoneFormRow row) async {
    final c = await showCountrySheet(context, row.code);
    if (c != null) setState(() => row.code = c);
  }

  void _disposeAfterFrame(VoidCallback dispose) => WidgetsBinding.instance.addPostFrameCallback((_) => dispose());

  Widget _phoneRow(AppLocalizations l, int i) {
    final row = _phones[i];
    return PhoneRowField(
      key: ObjectKey(row),
      row: row,
      open: _expanded == 'phone:$i',
      short: _phoneShort && row.label != 'landline' && phoneTooShort(row.code, row.number.text),
      onRemove: () => setState(() {
        if (_phones.length > 1) {
          _disposeAfterFrame(_phones.removeAt(i).dispose);
        } else {
          row.number.clear();
        }
        _expanded = null;
      }),
      onPickType: () async {
        final v = await _chooseLabel(l.phoneLabelTitle, const ['mobile', 'landline', 'work', 'home', 'whatsapp', 'other'], row.label);
        if (v != null) setState(() => row.label = v);
      },
      onPickCode: () => _pickCode(row),
      onChanged: () => setState(() => _phoneShort = false),
    );
  }

  List<Widget> _entryGroup(AppLocalizations l, String kind) {
    final list = _entries[kind]!;
    if (list.isEmpty) return const [];
    return [
      for (var i = 0; i < list.length; i++) ...[
        const SizedBox(height: AppSpace.lg),
        EntryRowField(
          key: ObjectKey(list[i]),
          kind: kind,
          row: list[i],
          open: _expanded == '$kind:$i',
          onRemove: () => setState(() {
            _disposeAfterFrame(list.removeAt(i).dispose);
            _expanded = null;
          }),
          onPickType: () async {
            final v = await _chooseLabel(l.phoneLabel, const ['work', 'home', 'other'], list[i].label, kind: kind);
            if (v != null) setState(() => list[i].label = v);
          },
        ),
      ],
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FormAddLink(label: entryAddText(l, kind), onTap: () => setState(() => list.add(_newEntry(kind)))),
      ),
      const SizedBox(height: AppSpace.xs),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(
            title: l.editProfile,
            close: true,
            actions: [SizedBox(width: AppControl.btnS, child: PillButton(label: l.save, height: AppControl.lg, accent: true, onPressed: _loaded ? _save : null))],
          ),
          Expanded(
            child: !_loaded
                ? const SizedBox.shrink()
                : LabelInset(
                    inset: 0,
                    child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.x5), children: [
                      FormPhoto(photo: _photo, onTap: _photoSheet),
                      const SizedBox(height: AppSpace.lg),
                      GlassField(controller: _first, label: l.fieldFirstName, textCapitalization: TextCapitalization.words),
                      const SizedBox(height: AppSpace.lg),
                      GlassField(controller: _last, label: l.fieldLastName, textCapitalization: TextCapitalization.words),
                      const SizedBox(height: AppSpace.lg),
                      GlassField(controller: _company, label: l.fieldCompany, textCapitalization: TextCapitalization.words),
                      const SizedBox(height: AppSpace.lg),
                      GlassField(controller: _job, label: l.fieldJobTitle, textCapitalization: TextCapitalization.words),
                      const SizedBox(height: AppSpace.lg),
                      for (var i = 0; i < _phones.length; i++) ...[if (i > 0) const SizedBox(height: AppSpace.lg), _phoneRow(l, i)],
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FormAddLink(label: l.addPhone, onTap: () => setState(() => _phones.add(_newPhone()))),
                      ),
                      ..._entryGroup(l, 'email'),
                      ..._entryGroup(l, 'website'),
                      ..._entryGroup(l, 'address'),
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
