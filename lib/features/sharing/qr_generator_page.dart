import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
    final s = _picked;
    if (s == null) return ' ';
    final c = s.contact;
    final b = StringBuffer('BEGIN:VCARD\r\nVERSION:3.0\r\n');
    b.write('FN:${_esc(_on.contains('name') ? s.displayName : c.company)}\r\n');
    if (_on.contains('name')) b.write('N:${_esc(c.lastName)};${_esc(c.firstName)};;;\r\n');
    if (_on.contains('company') && c.company.isNotEmpty) b.write('ORG:${_esc(c.company)}\r\n');
    if (_on.contains('job') && c.jobTitle.isNotEmpty) b.write('TITLE:${_esc(c.jobTitle)}\r\n');
    if (_on.contains('phone')) {
      for (final p in s.phones.take(2)) {
        b.write('TEL;TYPE=CELL:${p.countryCode}${p.number}'.replaceAll(' ', ''));
        b.write('\r\n');
      }
    }
    if (_on.contains('email')) {
      for (final e in s.emails.take(1)) {
        b.write('EMAIL:${_esc(e.value)}\r\n');
      }
    }
    if (_on.contains('address')) {
      for (final a in s.addresses.take(1)) {
        b.write('ADR:;;${_esc(a.value)};;;;\r\n');
      }
    }
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
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(l.qrContactLabel, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
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
        GlassCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: _all.isEmpty ? null : _pick,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.qrContactLabel, style: TextStyle(fontSize: 12, color: p.text2)),
                    Text(_picked?.displayName ?? '—', style: const TextStyle(fontSize: 17)),
                  ]),
                ),
                Icon(Icons.expand_more, color: p.text2),
              ]),
            ),
          ),
        ),
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
              height: 52,
              onPressed: _picked == null ? null : () async => Share.shareXFiles([XFile((await _image()).path, mimeType: 'image/png')]),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _picked == null ? null : () => shareVCards([_picked!], name: _picked!.displayName.replaceAll(RegExp(r'[^\w؀-ۿ -]'), '')),
            child: Text(l.qrShareFile, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
