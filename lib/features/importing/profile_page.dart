import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../sharing/share_helpers.dart';

const _keys = ['profile.name', 'profile.company', 'profile.phone', 'profile.email'];

/// My profile: your own card, shown as a QR code others can scan. Also used in report headers.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.db});
  final AppDatabase db;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _c = {for (final k in _keys) k: TextEditingController()};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final k in _keys) {
      _c[k]!.text = await widget.db.getSetting(k) ?? '';
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
    for (final k in _keys) {
      await widget.db.putSetting(k, _c[k]!.text.trim());
    }
  }

  String _vcard() => profileVCard({for (final k in _keys) k: _c[k]!.text});

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
              GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () async {
                final nav = Navigator.of(context);
                await _save();
                nav.pop();
              }),
              const SizedBox(width: 12),
              Expanded(child: Text(l.profileTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: pal.onHeader))),
            ]),
          ),
          Expanded(
            child: !_loaded
                ? const SizedBox.shrink()
                : ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: [
                    GlassField(controller: _c['profile.name']!, label: l.profileName),
                    const SizedBox(height: 12),
                    GlassField(controller: _c['profile.company']!, label: l.fieldCompany),
                    const SizedBox(height: 12),
                    GlassField(controller: _c['profile.phone']!, label: l.fieldPhone, keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    GlassField(controller: _c['profile.email']!, label: l.fieldEmail, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 20),
                    PillButton(
                      label: l.showQr,
                      height: 50,
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await _save();
                        await nav.push(MaterialPageRoute<void>(builder: (_) => QrShowPage(title: l.profileTitle, data: _vcard())));
                      },
                    ),
                  ]),
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
  final name = t('profile.name');
  final b = StringBuffer('BEGIN:VCARD\r\nVERSION:3.0\r\nFN:${e(name)}\r\nN:;${e(name)};;;\r\n');
  if (t('profile.company').isNotEmpty) b.write('ORG:${e(t('profile.company'))}\r\n');
  if (t('profile.phone').isNotEmpty) b.write('TEL;TYPE=CELL:${t('profile.phone').replaceAll(' ', '')}\r\n');
  if (t('profile.email').isNotEmpty) b.write('EMAIL:${e(t('profile.email'))}\r\n');
  b.write('END:VCARD\r\n');
  return b.toString();
}
