import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/ds.dart';

import '../../shared/permission_primer.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../core/phone_split.dart';
import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../domain/name_prefix.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/tokens.dart';

/// Import from the phone book (design S08): pick contacts, they are added as leads. Numbers already saved are skipped.
class ImportPage extends StatefulWidget {
  const ImportPage({super.key, required this.repo});
  final ContactsRepository repo;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  List<Contact>? _phone;
  bool _denied = false;
  final _picked = <String>{};
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final go = await PermissionPrimer.once(context, 'contacts', icon: Icons.people_outline, title: l.navContacts, body: l.permContactsBody);
    final ok = go && await FlutterContacts.requestPermission(readonly: true);
    if (!ok) {
      if (mounted) setState(() => _denied = true);
      return;
    }
    final list = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
    list.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    if (mounted) setState(() => _phone = list);
  }

  static String _label(String name) => switch (name) {
        'mobile' => 'mobile',
        'work' || 'workFax' || 'workMobile' || 'workPager' => 'work',
        'home' || 'homeFax' => 'home',
        _ => 'other',
      };

  Future<String?> _savePhoto(Contact c) async {
    final bytes = c.photo ?? c.thumbnail;
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/contact_photos');
      await dir.create(recursive: true);
      final dest = '${dir.path}/import_${DateTime.now().microsecondsSinceEpoch}_${c.id}.jpg';
      await File(dest).writeAsBytes(bytes);
      return dest;
    } catch (_) {
      return null;
    }
  }

  ContactInput _convert(Contact c, {String? photoPath, required AppLocalizations l}) {
    final org = c.organizations.isEmpty ? null : c.organizations.first;
    var first = c.name.first;
    var last = c.name.last;
    // Some phones keep the whole name in one field; fall back to the display name.
    if (first.trim().isEmpty && last.trim().isEmpty && c.displayName.trim().isNotEmpty) first = c.displayName;
    final (prefix, rest) = splitNamePrefix(c.name.prefix, first);
    first = rest;
    return ContactInput(
      firstName: first,
      lastName: last,
      prefix: prefix,
      nickname: c.name.nickname,
      company: org?.company ?? '',
      jobTitle: org?.title ?? '',
      department: org?.department ?? '',
      phones: [
        for (final p in c.phones)
          if (p.number.trim().isNotEmpty)
            () {
              final (code, number) = splitPhone(p.number);
              return PhoneInput(countryCode: code, number: number, label: _label(p.label.name), isWhatsApp: p.label.name == 'mobile');
            }(),
      ],
      emails: [for (final e in c.emails) if (e.address.trim().isNotEmpty) EntryInput(value: e.address.trim(), label: _label(e.label.name))],
      websites: [for (final w in c.websites) if (w.url.trim().isNotEmpty) EntryInput(value: w.url.trim())],
      addresses: [for (final a in c.addresses) if (a.address.trim().isNotEmpty) EntryInput(value: a.address.trim(), label: _label(a.label.name))],
      events: [
        for (final e in c.events)
          if (e.year != null || e.month > 0)
            EventInput(
              title: switch (e.label) {
                EventLabel.birthday => l.evBirthday,
                EventLabel.anniversary => l.evAnniversary,
                _ => e.customLabel.isNotEmpty ? e.customLabel : l.evOther,
              },
              date: DateTime(e.year ?? 2000, e.month, e.day),
              yearly: true,
            ),
      ],
      requirements: c.notes.map((n) => n.note.trim()).where((n) => n.isNotEmpty).join('\n'),
      photoPath: photoPath,
      roles: const [Role.lead],
    );
  }

  Future<void> _import() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    var added = 0, skipped = 0;
    for (final c in _phone!.where((c) => _picked.contains(c.id))) {
      Contact full = c;
      try {
        full = await FlutterContacts.getContact(c.id, withProperties: true, withPhoto: true) ?? c;
      } catch (_) {}
      final input = _convert(full, photoPath: await _savePhoto(full), l: l);
      var dup = false;
      for (final p in input.phones) {
        if (await widget.repo.findByPhone(p.countryCode, p.number) != null) dup = true;
      }
      try {
        if (dup) {
          skipped++;
        } else {
          await widget.repo.save(input);
          added++;
        }
      } on ContactValidationException {
        skipped++;
      }
    }
    messenger.showSnackBar(SnackBar(content: Text(l.importDone(added, skipped))));
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final list = _phone;
    final q = _query.trim().toLowerCase();
    final shown = list == null ? const <Contact>[] : [for (final c in list) if (q.isEmpty || c.displayName.toLowerCase().contains(q)) c];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(
 title: l.importTitle,

 actions: [SizedBox(width: AppControl.btnM, child: PillButton(label: l.importCount(_picked.length), height: AppControl.lg, accent: true, onPressed: _picked.isEmpty || _busy ? null : _import))],
 ),
          Expanded(
            child: _denied
                ? EmptyState(icon: Icons.lock_outline, title: l.contactsDenied)
                : list == null
                    ? const LoadingView()
                    : Column(children: [
                        Padding(padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xs), child: GlassField(controller: _search, label: l.searchContacts, onChanged: (v) => setState(() => _query = v))),
                        Row(children: [
                          TextButton(
                            onPressed: () => setState(() {
                              final ids = shown.map((c) => c.id);
                              if (ids.every(_picked.contains)) {
                                _picked.removeAll(ids);
                              } else {
                                _picked.addAll(ids);
                              }
                            }),
                            child: Text(l.selectAll),
                          ),
                        ]),
                        Expanded(
                          child: ListView(children: [
                            for (final c in shown)
                              CheckboxListTile(
                                value: _picked.contains(c.id),
                                title: Text(c.displayName.isEmpty ? (c.phones.isEmpty ? '' : c.phones.first.number) : c.displayName),
                                subtitle: c.phones.isEmpty ? null : Text(c.phones.first.number),
                                onChanged: (v) => setState(() => v == true ? _picked.add(c.id) : _picked.remove(c.id)),
                              ),
                            const SizedBox(height: AppSpace.x5),
                          ]),
                        ),
                      ]),
          ),
        ]),
      ),
    );
  }
}
