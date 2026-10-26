import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/palette.dart';

/// Splits one typed name into first and last: the last word is the last name.
({String first, String last}) splitName(String input) {
  final words = input.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return (first: '', last: '');
  if (words.length == 1) return (first: words.first, last: '');
  return (first: words.sublist(0, words.length - 1).join(' '), last: words.last);
}

/// Opens the quick-add sheet. Returns the saved contact, or the existing one the person chose to open.
Future<({int id, bool existing})?> showQuickAdd(BuildContext context, ContactsRepository repo) {
  return showModalBottomSheet<({int id, bool existing})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.palette.sheet,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => QuickAddSheet(repo: repo),
  );
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key, required this.repo});
  final ContactsRepository repo;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _name = TextEditingController();
  final _code = TextEditingController(text: '+963');
  final _phone = TextEditingController();
  final _note = TextEditingController();
  bool _nameMissing = false;
  bool _saving = false;
  ContactSummary? _duplicate;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
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
      phones: number.isEmpty ? const [] : [PhoneInput(number: number, countryCode: _code.text.trim())],
    );
  }

  Future<void> _save({bool force = false}) async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    setState(() => _saving = true);
    if (!force && _phone.text.trim().isNotEmpty) {
      final dup = await widget.repo.findByPhone(_code.text.trim(), _phone.text.trim());
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
    if (mounted) Navigator.of(context).pop((id: id, existing: false));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final dup = _duplicate;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: 36, height: 4, decoration: BoxDecoration(color: p.outline, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(l.quickAddTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l.fieldName,
                errorText: _nameMissing ? l.nameRequired : null,
              ),
              onChanged: (_) {
                if (_nameMissing) setState(() => _nameMissing = false);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 92,
                  child: TextField(
                    controller: _code,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: '+'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: l.fieldPhone, helperText: l.labelMobile),
                    onChanged: (_) {
                      if (_duplicate != null) setState(() => _duplicate = null);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(labelText: l.fieldTempNote),
            ),
            if (dup != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.duplicateTitle,
                        style: TextStyle(color: p.onErrorContainer, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(l.duplicateBody(dup.displayName), style: TextStyle(color: p.onErrorContainer)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop((id: dup.contact.id, existing: true)),
                          child: Text(l.openExisting),
                        ),
                        TextButton(onPressed: () => _save(force: true), child: Text(l.saveAnyway)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _saving ? null : _save, child: Text(l.save)),
          ],
        ),
      ),
    );
  }
}
