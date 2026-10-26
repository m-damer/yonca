import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../core/phone_split.dart';
import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';

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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ok = await FlutterContacts.requestPermission(readonly: true);
    if (!ok) {
      if (mounted) setState(() => _denied = true);
      return;
    }
    final list = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
    list.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    if (mounted) setState(() => _phone = list);
  }

  ContactInput _convert(Contact c) {
    final org = c.organizations.isEmpty ? null : c.organizations.first;
    return ContactInput(
      firstName: c.name.first,
      lastName: c.name.last,
      prefix: c.name.prefix,
      nickname: c.name.nickname,
      company: org?.company ?? '',
      jobTitle: org?.title ?? '',
      department: org?.department ?? '',
      phones: [
        for (final p in c.phones)
          if (p.number.trim().isNotEmpty)
            () {
              final (code, number) = splitPhone(p.number);
              return PhoneInput(countryCode: code, number: number);
            }(),
      ],
      emails: [for (final e in c.emails) if (e.address.trim().isNotEmpty) EntryInput(value: e.address.trim())],
      websites: [for (final w in c.websites) if (w.url.trim().isNotEmpty) EntryInput(value: w.url.trim())],
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
      final input = _convert(c);
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
    final pal = context.palette;
    final list = _phone;
    final q = _query.trim().toLowerCase();
    final shown = list == null ? const <Contact>[] : [for (final c in list) if (q.isEmpty || c.displayName.toLowerCase().contains(q)) c];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(children: [
              GlassIconButton(icon: Icons.arrow_back, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 14),
              Expanded(child: Text(l.importTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: pal.onHeader))),
              SizedBox(width: 110, child: PillButton(label: l.importCount(_picked.length), height: 44, accent: true, onPressed: _picked.isEmpty || _busy ? null : _import)),
            ]),
          ),
          Expanded(
            child: _denied
                ? EmptyState(icon: Icons.lock_outline, title: l.contactsDenied)
                : list == null
                    ? const LoadingView()
                    : Column(children: [
                        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: GlassField(label: l.searchContacts, onChanged: (v) => setState(() => _query = v))),
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
                            const SizedBox(height: 40),
                          ]),
                        ),
                      ]),
          ),
        ]),
      ),
    );
  }
}
