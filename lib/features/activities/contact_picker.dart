import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../contacts/contact_widgets.dart';

/// What the picker returns: a contact, or "no contact" (general note).
class ContactChoice {
  const ContactChoice(this.id, this.name);
  final int? id;
  final String name;
}

/// Bottom sheet with a search field and the contacts, recent first.
/// With [allowNone] the first row is "General note" (no contact).
Future<ContactChoice?> pickContact(BuildContext context, ContactsRepository repo, {bool allowNone = false}) {
  return showGlassSheet<ContactChoice>(
    context,
    builder: (ctx) => _PickerBody(repo: repo, allowNone: allowNone),
  );
}

class _PickerBody extends StatefulWidget {
  const _PickerBody({required this.repo, required this.allowNone});
  final ContactsRepository repo;
  final bool allowNone;

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  final _query = TextEditingController();
  List<ContactSummary>? _items;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final r = await widget.repo.list(query: q);
    if (mounted) setState(() => _items = r);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = _items;
    return SizedBox(
      height: MediaQuery.of(context).size.height * .7,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(l.chooseContact, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        GlassField(controller: _query, label: l.searchContacts, onChanged: _search),
        const SizedBox(height: 8),
        Expanded(
          child: items == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(children: [
                  if (widget.allowNone)
                    ListTile(
                      leading: const Icon(Icons.sticky_note_2_outlined),
                      title: Text(l.generalNote),
                      onTap: () => Navigator.of(context).pop(ContactChoice(null, l.generalNote)),
                    ),
                  if (items.isEmpty)
                    Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(l.noContactsFound))),
                  for (final s in items)
                    ListTile(
                      leading: ContactAvatar(summary: s, size: 40, showBadges: false),
                      title: Text(s.displayName),
                      onTap: () => Navigator.of(context).pop(ContactChoice(s.contact.id, s.displayName)),
                    ),
                ]),
        ),
      ]),
    );
  }
}
