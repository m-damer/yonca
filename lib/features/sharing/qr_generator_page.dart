import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../shared/permission_primer.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../settings/settings_widgets.dart';
import 'share_helpers.dart';

/// QR generator (design Tool QRG): pick a contact, tick the fields that go in the code, share the image.
class QrGeneratorPage extends StatefulWidget {
  const QrGeneratorPage({super.key, required this.repo});
  final ContactsRepository repo;

  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

class _QrGeneratorPageState extends State<QrGeneratorPage> {
  List<ContactSummary> _all = const [];
  ContactSummary? _picked;
  final _on = <String>{'name', 'phone', 'email', 'company'};
  int _mode = 0;
  _Src? _phoneSrc;
  final _mName = TextEditingController();
  final _mPhone = TextEditingController();
  final _mEmail = TextEditingController();
  final _mCompany = TextEditingController();

  @override
  void dispose() {
    for (final c in [_mName, _mPhone, _mEmail, _mCompany]) {
      c.dispose();
    }
    super.dispose();
  }

  _Src? get _src {
    switch (_mode) {
      case 0:
        final s = _picked;
        if (s == null) return null;
        final c = s.contact;
        return _Src(
          name: s.displayName,
          first: c.firstName,
          last: c.lastName,
          company: c.company,
          job: c.jobTitle,
          phones: [for (final p in s.phones.take(2)) '${p.countryCode}${p.number}'],
          emails: [for (final e in s.emails.take(1)) e.value],
          address: s.addresses.isEmpty ? '' : s.addresses.first.value,
        );
      case 1:
        return _phoneSrc;
      default:
        final n = _mName.text.trim();
        if (n.isEmpty && _mPhone.text.trim().isEmpty && _mEmail.text.trim().isEmpty && _mCompany.text.trim().isEmpty) return null;
        final parts = n.split(RegExp(r'\s+'));
        return _Src(
          name: n,
          first: parts.isEmpty ? '' : parts.first,
          last: parts.length > 1 ? parts.sublist(1).join(' ') : '',
          company: _mCompany.text.trim(),
          phones: _mPhone.text.trim().isEmpty ? const [] : [_mPhone.text.trim()],
          emails: _mEmail.text.trim().isEmpty ? const [] : [_mEmail.text.trim()],
        );
    }
  }

  Future<void> _pickPhone() async {
    try {
      final l = AppLocalizations.of(context);
      if (!await PermissionPrimer.once(context, 'contacts', icon: Icons.people_outline, title: l.navContacts, body: l.permContactsBody)) return;
      if (!await fc.FlutterContacts.requestPermission(readonly: true)) return;
      final c = await fc.FlutterContacts.openExternalPick();
      if (c == null) return;
      final full = await fc.FlutterContacts.getContact(c.id, withProperties: true, withPhoto: false) ?? c;
      final org = full.organizations.isEmpty ? null : full.organizations.first;
      if (!mounted) return;
      setState(() => _phoneSrc = _Src(
            name: full.displayName,
            first: full.name.first,
            last: full.name.last,
            company: org?.company ?? '',
            job: org?.title ?? '',
            phones: [for (final p in full.phones.take(2)) p.number.replaceAll(' ', '')],
            emails: [for (final e in full.emails.take(1)) e.address],
            address: full.addresses.isEmpty ? '' : full.addresses.first.address,
          ));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    widget.repo.list(sort: ContactSort.name).then((v) {
      if (mounted) {
        setState(() {
          _all = v;
          _picked = v.isEmpty ? null : v.first;
        });
      }
    });
  }

  String _esc(String s) => s.replaceAll(r'\', r'\\').replaceAll(';', r'\;').replaceAll(',', r'\,');

  String _data() {
    final s = _src;
    if (s == null) return ' ';
    final b = StringBuffer('BEGIN:VCARD\r\nVERSION:3.0\r\n');
    b.write('FN:${_esc(_on.contains('name') ? s.name : s.company)}\r\n');
    if (_on.contains('name')) b.write('N:${_esc(s.last)};${_esc(s.first)};;;\r\n');
    if (_on.contains('company') && s.company.isNotEmpty) b.write('ORG:${_esc(s.company)}\r\n');
    if (_on.contains('job') && s.job.isNotEmpty) b.write('TITLE:${_esc(s.job)}\r\n');
    if (_on.contains('phone')) {
      for (final p in s.phones) {
        b.write('TEL;TYPE=CELL:$p'.replaceAll(' ', ''));
        b.write('\r\n');
      }
    }
    if (_on.contains('email')) {
      for (final e in s.emails) {
        b.write('EMAIL:${_esc(e)}\r\n');
      }
    }
    if (_on.contains('address') && s.address.isNotEmpty) b.write('ADR:;;${_esc(s.address)};;;;\r\n');
    b.write('END:VCARD\r\n');
    return b.toString();
  }

  Future<File> _image() async {
    final painter = QrPainter(data: _data(), version: QrVersions.auto, errorCorrectionLevel: QrErrorCorrectLevel.L, gapless: true);
    final img = await painter.toImage(720);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/yonca-qr.png');
    await f.writeAsBytes(bytes!.buffer.asUint8List());
    return f;
  }

  Future<void> _pick() async {
    final l = AppLocalizations.of(context);
    final chosen = await showGlassSheet<ContactSummary>(
      context,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .6),
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(l.qrContactLabel, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
          for (final s in _all) ListTile(title: Text(s.displayName), subtitle: s.contact.company.isEmpty ? null : Text(s.contact.company), onTap: () => Navigator.of(ctx).pop(s)),
        ]),
      ),
    );
    if (chosen != null) setState(() => _picked = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    Widget field(String key, String label) => InkWell(
          onTap: () => setState(() => _on.contains(key) ? _on.remove(key) : _on.add(key)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _on.contains(key) ? p.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _on.contains(key) ? p.primary : p.text2, width: 1.5),
                ),
                child: _on.contains(key) ? Icon(Icons.check, size: 16, color: p.onPrimary) : null,
              ),
              const SizedBox(width: 14),
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ]),
          ),
        );
    final fields = <(String, String)>[
      ('name', l.fieldName),
      ('phone', l.fieldPhone),
      ('email', l.fieldEmail),
      ('company', l.fieldCompany),
      ('job', l.fieldJobTitle),
      ('address', l.fieldAddress),
    ];
    final data = _data();
    return SettingsScaffold(
      title: l.qrGeneratorTitle,
      children: [
        const SizedBox(height: 8),
        SegControl(
          labels: [l.qrAppContact, l.qrPhoneBook, l.qrManual],
          selected: _mode,
          onSelect: (i) => setState(() => _mode = i),
        ),
        const SizedBox(height: 16),
        if (_mode == 0)
          GlassSelectField(label: l.qrContactLabel, value: _picked?.displayName ?? ' ', onTap: _all.isEmpty ? () {} : _pick),
        if (_mode == 1)
          GlassSelectField(label: l.qrContactLabel, value: _phoneSrc?.name ?? l.qrChoosePhone, onTap: _pickPhone),
        if (_mode == 2) ...[
          GlassField(controller: _mName, label: l.fieldName, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          GlassField(controller: _mPhone, label: l.fieldPhone, keyboardType: TextInputType.phone, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          GlassField(controller: _mEmail, label: l.fieldEmail, keyboardType: TextInputType.emailAddress, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          GlassField(controller: _mCompany, label: l.fieldCompany, onChanged: (_) => setState(() {})),
        ],
        SectionLabel(l.qrFieldsTitle),
        SettingsGroup(children: [for (final f in fields) field(f.$1, f.$2)]),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: QrImageView(data: data, size: 220, errorCorrectionLevel: QrErrorCorrectLevel.L, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 10, color: data.length < 400 ? p.primary : p.error),
              const SizedBox(width: 8),
              Text(l.qrGood, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: PillButton(
              label: l.qrShareImage,
              icon: Icons.ios_share,
              height: 48,
              onPressed: _src == null ? null : () async => Share.shareXFiles([XFile((await _image()).path, mimeType: 'image/png')]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PillButton(
              label: l.qrSaveImage,
              outlined: true,
              height: 48,
              onPressed: _src == null
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final f = await _image();
                      final out = await FilePicker.platform.saveFile(fileName: 'yonca-qr.png', bytes: await f.readAsBytes(), type: FileType.image);
                      if (out != null) messenger.showSnackBar(SnackBar(content: Text(l.qrSaved)));
                    },
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _mode != 0 || _picked == null ? null : () => shareVCards([_picked!], name: _picked!.displayName.replaceAll(RegExp(r'[^\w؀-ۿ -]'), '')),
            child: Text(l.qrShareFile, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _Src {
  const _Src({required this.name, this.first = '', this.last = '', this.company = '', this.job = '', this.phones = const [], this.emails = const [], this.address = ''});
  final String name;
  final String first;
  final String last;
  final String company;
  final String job;
  final List<String> phones;
  final List<String> emails;
  final String address;
}
