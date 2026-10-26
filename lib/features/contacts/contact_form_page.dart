import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'contact_widgets.dart';

class _PhoneRow {
  _PhoneRow({String code = '+963', String number = '', this.label = 'mobile', this.whatsapp = false})
      : code = TextEditingController(text: code),
        number = TextEditingController(text: number);
  final TextEditingController code;
  final TextEditingController number;
  String label;
  bool whatsapp;
  void dispose() {
    code.dispose();
    number.dispose();
  }
}

/// Full contact form for a new contact ([id] null) or to edit contact [id].
/// [draft] pre-fills a new contact (from quick add). Pops with the saved contact id.
class ContactFormPage extends StatefulWidget {
  const ContactFormPage({super.key, required this.repo, this.id, this.draft});
  final ContactsRepository repo;
  final int? id;
  final ContactInput? draft;

  @override
  State<ContactFormPage> createState() => _ContactFormPageState();
}

class _ContactFormPageState extends State<ContactFormPage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _nick = TextEditingController();
  final _company = TextEditingController();
  final _job = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _address = TextEditingController();
  final _requirements = TextEditingController();
  final _note = TextEditingController();
  final _tags = TextEditingController();
  final _phones = <_PhoneRow>[];
  Rating _rating = Rating.none;
  final _roles = <Role>{};
  bool _loading = true;
  bool _saving = false;
  bool _nameMissing = false;
  ContactSummary? _duplicate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ContactInput? input = widget.draft;
    List<String> tagNames = input?.tags ?? const [];
    if (widget.id != null) {
      final s = await widget.repo.get(widget.id!);
      if (s != null) {
        final c = s.contact;
        input = ContactInput(
          firstName: c.firstName,
          lastName: c.lastName,
          company: c.company,
          nickname: c.nickname,
          jobTitle: c.jobTitle,
          email: c.email,
          website: c.website,
          address: c.address,
          requirements: c.requirements,
          temporaryNote: c.temporaryNote,
          rating: ratingFromName(c.rating),
          phones: [
            for (final p in s.phones)
              PhoneInput(number: p.number, countryCode: p.countryCode, label: p.label, isWhatsApp: p.isWhatsApp),
          ],
          roles: s.roles,
        );
        tagNames = [for (final t in s.tags) t.name];
      }
    }
    if (input != null) {
      _first.text = input.firstName;
      _last.text = input.lastName;
      _nick.text = input.nickname;
      _company.text = input.company;
      _job.text = input.jobTitle;
      _email.text = input.email;
      _website.text = input.website;
      _address.text = input.address;
      _requirements.text = input.requirements;
      _note.text = input.temporaryNote;
      _rating = input.rating;
      _roles.addAll(input.roles);
      for (final p in input.phones) {
        _phones.add(_PhoneRow(code: p.countryCode, number: p.number, label: p.label, whatsapp: p.isWhatsApp));
      }
    }
    _tags.text = tagNames.join(', ');
    if (_phones.isEmpty) _phones.add(_PhoneRow());
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _nick, _company, _job, _email, _website, _address, _requirements, _note, _tags]) {
      c.dispose();
    }
    for (final p in _phones) {
      p.dispose();
    }
    super.dispose();
  }

  ContactInput _input() => ContactInput(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        company: _company.text.trim(),
        nickname: _nick.text.trim(),
        jobTitle: _job.text.trim(),
        email: _email.text.trim(),
        website: _website.text.trim(),
        address: _address.text.trim(),
        requirements: _requirements.text.trim(),
        temporaryNote: _note.text.trim(),
        rating: _rating,
        phones: [
          for (final p in _phones)
            if (p.number.text.trim().isNotEmpty)
              PhoneInput(
                number: p.number.text.trim(),
                countryCode: p.code.text.trim(),
                label: p.label,
                isWhatsApp: p.whatsapp,
              ),
        ],
        roles: _roles.toList()..sort((a, b) => a.index.compareTo(b.index)),
        tags: _tags.text.split(RegExp('[,،]')).map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      );

  Future<void> _save({bool force = false}) async {
    if (_saving) return;
    final input = _input();
    try {
      input.validate();
    } on ContactValidationException {
      setState(() => _nameMissing = true);
      return;
    }
    setState(() => _saving = true);
    if (!force) {
      for (final p in input.phones) {
        final dup = await widget.repo.findByPhone(p.countryCode, p.number, excludeId: widget.id);
        if (dup != null) {
          if (!mounted) return;
          setState(() {
            _duplicate = dup;
            _saving = false;
          });
          return;
        }
      }
    }
    final id = await widget.repo.save(input, id: widget.id);
    if (mounted) Navigator.of(context).pop(id);
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? type, int maxLines = 1, TextDirection? dir, String? error, bool words = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: type,
        maxLines: maxLines,
        textDirection: dir,
        textCapitalization: words ? TextCapitalization.words : TextCapitalization.none,
        decoration: InputDecoration(labelText: label, errorText: error),
        onChanged: (_) {
          if (_nameMissing) setState(() => _nameMissing = false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final dup = _duplicate;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: SafeArea(
          child: _loading
              ? const LoadingView()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                      child: Row(children: [
                        const CloseButton(),
                        Expanded(
                          child: Text(widget.id == null ? l.formTitleNew : l.formTitleEdit,
                              style: Theme.of(context).textTheme.titleLarge),
                        ),
                        FilledButton(onPressed: _saving ? null : _save, child: Text(l.save)),
                      ]),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          GlassCard(
                            child: Column(children: [
                              _field(_first, l.fieldFirstName, words: true, error: _nameMissing ? l.nameRequired : null),
                              _field(_last, l.fieldLastName, words: true),
                              _field(_nick, l.fieldNickname),
                              _field(_company, l.fieldCompany, words: true),
                              _field(_job, l.fieldJobTitle),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          GlassCard(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              for (var i = 0; i < _phones.length; i++) _phoneRow(l, i),
                              TextButton.icon(
                                onPressed: () => setState(() => _phones.add(_PhoneRow())),
                                icon: const Icon(Icons.add),
                                label: Text(l.addPhone),
                              ),
                              if (dup != null) _duplicateCard(l, p, dup),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          GlassCard(
                            child: Column(children: [
                              _field(_email, l.fieldEmail, type: TextInputType.emailAddress, dir: TextDirection.ltr),
                              _field(_website, l.fieldWebsite, type: TextInputType.url, dir: TextDirection.ltr),
                              _field(_address, l.fieldAddress, maxLines: 2),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          GlassCard(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(l.fieldRating, style: TextStyle(color: p.text2)),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, children: [
                                for (final r in Rating.values)
                                  ChoiceChip(
                                    avatar: r == Rating.none ? null : Icon(ratingIcon(r), size: 16, color: ratingColor(r)),
                                    label: Text(ratingLabel(l, r)),
                                    selected: _rating == r,
                                    onSelected: (_) => setState(() => _rating = r),
                                  ),
                              ]),
                              const SizedBox(height: 16),
                              Text(l.fieldRoles, style: TextStyle(color: p.text2)),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, children: [
                                for (final r in Role.values)
                                  FilterChip(
                                    label: Text(roleLabel(l, r)),
                                    selected: _roles.contains(r),
                                    onSelected: (v) => setState(() => v ? _roles.add(r) : _roles.remove(r)),
                                  ),
                              ]),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _tags,
                                decoration: InputDecoration(labelText: l.fieldTags, helperText: l.tagsHint),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          GlassCard(
                            child: Column(children: [
                              _field(_requirements, l.fieldRequirements, maxLines: 3),
                              _field(_note, l.fieldTempNote, maxLines: 2),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _phoneRow(AppLocalizations l, int i) {
    final row = _phones[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        Row(children: [
          SizedBox(
            width: 84,
            child: TextField(
              controller: row.code,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: '+'),
              onChanged: (_) => setState(() => _duplicate = null),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: row.number,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: l.fieldPhone),
              onChanged: (_) => setState(() => _duplicate = null),
            ),
          ),
          if (_phones.length > 1)
            IconButton(
              onPressed: () => setState(() => _phones.removeAt(i).dispose()),
              icon: const Icon(Icons.remove_circle_outline),
            ),
        ]),
        Row(children: [
          DropdownButton<String>(
            value: row.label,
            items: [
              for (final v in const ['mobile', 'work', 'home', 'other'])
                DropdownMenuItem(value: v, child: Text(phoneLabelText(l, v))),
            ],
            onChanged: (v) => setState(() => row.label = v ?? 'mobile'),
          ),
          const Spacer(),
          Text(l.whatsapp),
          Switch(value: row.whatsapp, onChanged: (v) => setState(() => row.whatsapp = v)),
        ]),
      ]),
    );
  }

  Widget _duplicateCard(AppLocalizations l, YoncaPalette p, ContactSummary dup) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.duplicateTitle, style: TextStyle(color: p.onErrorContainer, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(l.duplicateBody(dup.displayName), style: TextStyle(color: p.onErrorContainer)),
        TextButton(onPressed: () => _save(force: true), child: Text(l.saveAnyway)),
      ]),
    );
  }
}
