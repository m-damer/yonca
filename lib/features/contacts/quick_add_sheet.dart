import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'contact_widgets.dart';
import 'country_sheet.dart';

/// Splits one typed name into first and last: the last word is the last name.
({String first, String last}) splitName(String input) {
  final words = input.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return (first: '', last: '');
  if (words.length == 1) return (first: words.first, last: '');
  return (first: words.sublist(0, words.length - 1).join(' '), last: words.last);
}

/// What the quick-add sheet hands back: a saved contact, an existing one to open, or a draft for the full form.
class QuickAddResult {
  const QuickAddResult.saved(this.id)
      : existing = false,
        draft = null;
  const QuickAddResult.existing(this.id)
      : existing = true,
        draft = null;
  const QuickAddResult.draft(this.draft)
      : id = null,
        existing = false;
  final int? id;
  final bool existing;
  final ContactInput? draft;
}

/// Opens the quick-add sheet (design S06).
Future<QuickAddResult?> showQuickAdd(BuildContext context, ContactsRepository repo) {
  return showGlassSheet<QuickAddResult>(context, builder: (_) => QuickAddSheet(repo: repo));
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key, required this.repo});
  final ContactsRepository repo;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  String _code = '+963';
  bool _nameMissing = false;
  bool _phoneShort = false;
  bool _saving = false;
  ContactSummary? _duplicate;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  ContactInput _input() {
    final n = splitName(_name.text);
    final number = _phone.text.trim();
    return ContactInput(
      firstName: n.first,
      lastName: n.last,
      temporaryNote: _note.text.trim(),
      phones: number.isEmpty ? const [] : [PhoneInput(number: number, countryCode: _code, isWhatsApp: true)],
    );
  }

  bool _validate() {
    final input = _input();
    final empty = input.firstName.isEmpty && input.lastName.isEmpty && input.phones.isEmpty;
    final short = phoneTooShort(_code, _phone.text);
    setState(() {
      _nameMissing = empty;
      _phoneShort = short;
    });
    return !empty && !short;
  }

  Future<void> _save({bool force = false}) async {
    if (_saving || !_validate()) return;
    setState(() => _saving = true);
    if (!force && _phone.text.trim().isNotEmpty) {
      final dup = await widget.repo.findByPhone(_code, _phone.text.trim());
      if (dup != null) {
        if (!mounted) return;
        setState(() {
          _duplicate = dup;
          _saving = false;
        });
        return;
      }
    }
    final id = await widget.repo.save(_input());
    if (mounted) Navigator.of(context).pop(QuickAddResult.saved(id));
  }

  Future<void> _pickCountry() async {
    final c = await showCountrySheet(context, _code);
    if (c != null) setState(() => _code = c);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final dup = _duplicate;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text(l.newContact, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          if (dup != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(22), border: Border.all(color: p.error.withValues(alpha: .35))),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: p.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(child: Text(l.duplicateTitle, style: TextStyle(color: p.onErrorContainer, fontWeight: FontWeight.w500))),
              ]),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(QuickAddResult.existing(dup.contact.id)),
                borderRadius: BorderRadius.circular(26),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    ContactAvatar(summary: dup, showBadges: false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(dup.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        Text(
                          [if (dup.contact.company.isNotEmpty && dup.displayName != dup.contact.company) dup.contact.company, if (dup.phones.isNotEmpty) dup.phones.first.number].join(' · '),
                          style: TextStyle(fontSize: 13, color: p.text2),
                        ),
                      ]),
                    ),
                    Icon(Icons.chevron_right),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          GlassField(
            controller: _name,
            label: l.fieldName,
            autofocus: dup == null,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            hint: _nameMissing ? l.errRequired : null,
            error: _nameMissing ? l.errNameOrPhone : null,
            onChanged: (_) {
              if (_nameMissing) setState(() => _nameMissing = false);
            },
          ),
          const SizedBox(height: 12),
          GlassField(
            controller: _phone,
            label: l.fieldPhone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            leading: CountrySelector(code: _code, onTap: _pickCountry),
            prefixText: _code,
            error: _phoneShort ? l.errPhoneShort : null,
            onChanged: (_) => setState(() {
              _duplicate = null;
              _phoneShort = false;
            }),
          ),
          if (dup == null) ...[
            const SizedBox(height: 12),
            GlassField(controller: _note, label: l.fieldTempNote, maxLines: 4, hint: l.optionalHint),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: dup == null
                  ? PillButton(
                      label: l.moreDetails,
                      outlined: true,
                      onPressed: () => Navigator.of(context).pop(QuickAddResult.draft(_input())),
                    )
                  : PillButton(label: l.saveAnyway, outlined: true, onPressed: _saving ? null : () => _save(force: true)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: dup == null
                  ? PillButton(label: l.save, onPressed: _saving ? null : _save)
                  : PillButton(
                      label: l.openExisting,
                      onPressed: () => Navigator.of(context).pop(QuickAddResult.existing(dup.contact.id)),
                    ),
            ),
          ]),
        ],
      ),
    );
  }
}
