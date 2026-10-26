import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'contact_widgets.dart';
import 'country_sheet.dart';
import 'tags_sheet.dart';

class _PhoneRow {
  _PhoneRow({this.code = '+963', String number = '', this.label = 'mobile'}) : number = TextEditingController(text: number);
  String code;
  final TextEditingController number;
  String label;
  void dispose() => number.dispose();
}

enum _Extra { email, address, jobTitle, website, nickname, requirements, tags }

/// Full contact form (design S07) for a new contact ([id] null) or to edit contact [id].
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
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _job = TextEditingController();
  final _website = TextEditingController();
  final _nick = TextEditingController();
  final _requirements = TextEditingController();
  final _note = TextEditingController();
  final _phones = <_PhoneRow>[];
  final _extras = <_Extra>[];
  final _tags = <String>[];
  final _roles = <Role>{};
  Rating _rating = Rating.none;
  bool _loading = true;
  bool _saving = false;
  bool _nameMissing = false;
  bool _phoneShort = false;
  String _initial = '';
  ContactSummary? _duplicate;

  TextEditingController _controllerFor(_Extra e) => switch (e) {
        _Extra.email => _email,
        _Extra.address => _address,
        _Extra.jobTitle => _job,
        _Extra.website => _website,
        _Extra.nickname => _nick,
        _Extra.requirements => _requirements,
        _Extra.tags => _first,
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ContactInput? input = widget.draft;
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
          phones: [for (final p in s.phones) PhoneInput(number: p.number, countryCode: p.countryCode, label: p.label)],
          roles: s.roles,
          tags: [for (final t in s.tags) t.name],
        );
      }
    }
    if (input != null) {
      _first.text = input.firstName;
      _last.text = input.lastName;
      _company.text = input.company;
      _email.text = input.email;
      _address.text = input.address;
      _job.text = input.jobTitle;
      _website.text = input.website;
      _nick.text = input.nickname;
      _requirements.text = input.requirements;
      _note.text = input.temporaryNote;
      _rating = input.rating;
      _roles.addAll(input.roles);
      _tags.addAll(input.tags);
      for (final p in input.phones) {
        _phones.add(_PhoneRow(code: p.countryCode, number: p.number, label: p.label));
      }
      if (input.email.isNotEmpty) _extras.add(_Extra.email);
      if (input.address.isNotEmpty) _extras.add(_Extra.address);
      if (input.jobTitle.isNotEmpty) _extras.add(_Extra.jobTitle);
      if (input.website.isNotEmpty) _extras.add(_Extra.website);
      if (input.nickname.isNotEmpty) _extras.add(_Extra.nickname);
      if (input.requirements.isNotEmpty) _extras.add(_Extra.requirements);
      if (input.tags.isNotEmpty) _extras.add(_Extra.tags);
    }
    if (_phones.isEmpty) _phones.add(_PhoneRow());
    _initial = _signature();
    if (mounted) setState(() => _loading = false);
  }

  String _signature() => [
        _first.text, _last.text, _company.text, _email.text, _address.text, _job.text, _website.text, _nick.text,
        _requirements.text, _note.text, _rating.name, _roles.map((r) => r.name).join(','), _tags.join(','),
        _phones.map((p) => '${p.code}${p.number.text}${p.label}').join(','),
      ].join('|');

  bool get _dirty => !_loading && _signature() != _initial;

  @override
  void dispose() {
    for (final c in [_first, _last, _company, _email, _address, _job, _website, _nick, _requirements, _note]) {
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
        nickname: _extras.contains(_Extra.nickname) ? _nick.text.trim() : '',
        jobTitle: _extras.contains(_Extra.jobTitle) ? _job.text.trim() : '',
        email: _extras.contains(_Extra.email) ? _email.text.trim() : '',
        website: _extras.contains(_Extra.website) ? _website.text.trim() : '',
        address: _extras.contains(_Extra.address) ? _address.text.trim() : '',
        requirements: _extras.contains(_Extra.requirements) ? _requirements.text.trim() : '',
        temporaryNote: _note.text.trim(),
        rating: _rating,
        phones: [
          for (final p in _phones)
            if (p.number.text.trim().isNotEmpty)
              PhoneInput(
                number: p.number.text.trim(),
                countryCode: p.code,
                label: p.label,
                isWhatsApp: p.label == 'mobile' || p.label == 'whatsapp',
              ),
        ],
        roles: _roles.toList()..sort((a, b) => a.index.compareTo(b.index)),
        tags: _extras.contains(_Extra.tags) ? List.of(_tags) : const [],
      );

  Future<void> _save({bool force = false}) async {
    if (_saving) return;
    final input = _input();
    final noName = input.firstName.isEmpty && input.lastName.isEmpty && input.company.isEmpty;
    final short = _phones.any((p) => phoneTooShort(p.code, p.number.text));
    setState(() {
      _nameMissing = noName;
      _phoneShort = short;
    });
    if (noName || short) return;
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
    _initial = _signature();
    if (mounted) Navigator.of(context).pop(id);
  }

  Future<bool> _confirmDiscard() async {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: p.scrim,
      builder: (ctx) => Dialog(
        backgroundColor: p.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.discardTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(l.discardBody, style: TextStyle(color: p.text2)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: PillButton(label: l.keepEditing, outlined: true, height: 48, onPressed: () => Navigator.of(ctx).pop(false))),
              const SizedBox(width: 10),
              Expanded(child: PillButton(label: l.discard, height: 48, onPressed: () => Navigator.of(ctx).pop(true))),
            ]),
          ]),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteTitle),
        content: Text(l.deleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok == true && widget.id != null) {
      await widget.repo.delete(widget.id!);
      _initial = _signature();
      nav.popUntil((r) => r.isFirst);
    }
  }

  String _extraLabel(AppLocalizations l, _Extra e) => switch (e) {
        _Extra.email => l.fieldEmail,
        _Extra.address => l.fieldAddress,
        _Extra.jobTitle => l.fieldJobTitle,
        _Extra.website => l.fieldWebsite,
        _Extra.nickname => l.fieldNickname,
        _Extra.requirements => l.fieldRequirements,
        _Extra.tags => l.fieldTags,
      };

  String _extraChip(AppLocalizations l, _Extra e) => switch (e) {
        _Extra.email => l.chipEmail,
        _Extra.address => l.chipAddress,
        _Extra.jobTitle => l.chipJobTitle,
        _Extra.website => l.chipWebsite,
        _Extra.nickname => l.chipNickname,
        _Extra.requirements => l.chipRequirements,
        _Extra.tags => l.chipTags,
      };

  Future<void> _pickLabel(_PhoneRow row) async {
    final l = AppLocalizations.of(context);
    final picked = await showGlassSheet<String>(
      context,
      builder: (ctx) {
        final p = ctx.palette;
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(l.phoneLabelTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          for (final v in const ['mobile', 'work', 'home', 'whatsapp', 'other'])
            InkWell(
              onTap: () => Navigator.of(ctx).pop(v),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                child: Row(children: [
                  Expanded(
                    child: Text(phoneLabelText(l, v),
                        style: TextStyle(fontSize: 17, fontWeight: row.label == v ? FontWeight.w700 : FontWeight.w400)),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: row.label == v ? p.primary : Colors.transparent,
                      border: Border.all(color: row.label == v ? p.primary : p.outline, width: 2),
                    ),
                    child: row.label == v ? Icon(Icons.check, size: 17, color: p.onPrimary) : null,
                  ),
                ]),
              ),
            ),
        ]);
      },
    );
    if (picked != null) setState(() => row.label = picked);
  }

  Future<void> _pickCode(_PhoneRow row) async {
    final c = await showCountrySheet(context, row.code);
    if (c != null) setState(() => row.code = c);
  }

  Future<void> _editTags() async {
    final known = [for (final t in await widget.repo.allTags()) t.name];
    if (!mounted) return;
    final result = await showTagsSheet(context, known: known, chosen: _tags);
    if (result != null) {
      setState(() {
        _tags
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) {
          _initial = _signature();
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GlassBackdrop(
          child: SafeArea(
            child: _loading
                ? const LoadingView()
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(children: [
                        GlassIconButton(icon: Icons.close, onTap: () => Navigator.of(context).maybePop()),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(widget.id == null ? l.newContact : l.formTitleEdit,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        ),
                        SizedBox(
                          width: 84,
                          child: PillButton(label: l.save, height: 44, onPressed: _saving ? null : _save),
                        ),
                      ]),
                    ),
                    Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: _content(l, p))),
                  ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(AppLocalizations l, YoncaPalette p) {
    final remaining = [for (final e in _Extra.values) if (!_extras.contains(e)) e];
    return [
      Center(
        child: InkWell(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.comingLater))),
          borderRadius: BorderRadius.circular(30),
          child: Column(children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: p.glass,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: p.primary.withValues(alpha: .6), width: 1.5),
              ),
              child: Icon(Icons.photo_camera_outlined, color: p.primary),
            ),
            const SizedBox(height: 8),
            Text(widget.id == null ? l.addPhoto : l.changePhoto,
                style: TextStyle(color: p.primary, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      GlassField(
        controller: _first,
        label: l.fieldFirstName,
        textCapitalization: TextCapitalization.words,
        hint: _nameMissing ? l.errRequired : null,
        error: _nameMissing ? l.errFirstOrCompany : null,
        onChanged: (_) {
          if (_nameMissing) setState(() => _nameMissing = false);
        },
      ),
      const SizedBox(height: 12),
      GlassField(controller: _last, label: l.fieldLastName, textCapitalization: TextCapitalization.words),
      const SizedBox(height: 12),
      GlassField(controller: _company, label: l.fieldCompany, textCapitalization: TextCapitalization.words),
      const SizedBox(height: 12),
      for (var i = 0; i < _phones.length; i++) ...[_phoneRow(l, i), const SizedBox(height: 12)],
      if (_phoneShort)
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: p.error),
            const SizedBox(width: 6),
            Expanded(child: Text(l.errPhoneShort, style: TextStyle(fontSize: 12.5, color: p.error))),
          ]),
        ),
      if (_duplicate != null) _duplicateCard(l, p, _duplicate!),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => setState(() => _phones.add(_PhoneRow())),
          icon: const Icon(Icons.add),
          label: Text(l.addPhone),
        ),
      ),
      SectionLabel(l.fieldRoles),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in Role.values)
          PillChip(
            label: roleLabel(l, r),
            selected: _roles.contains(r),
            check: true,
            onTap: () => setState(() => _roles.contains(r) ? _roles.remove(r) : _roles.add(r)),
          ),
      ]),
      SectionLabel(l.fieldRating),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in const [Rating.hot, Rating.warm, Rating.cold])
          PillChip(
            label: ratingLabel(l, r),
            icon: ratingIcon(r),
            selected: _rating == r,
            onTap: () => setState(() => _rating = _rating == r ? Rating.none : r),
          ),
      ]),
      const SizedBox(height: 12),
      for (final e in _extras) ...[_extraField(l, p, e), const SizedBox(height: 12)],
      SectionLabel(l.fieldTempNote),
      GlassField(controller: _note, label: ' ', maxLines: 4, hint: l.optionalHint),
      if (remaining.isNotEmpty) ...[
        SectionLabel(l.addMoreInfo),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in remaining) PillChip(label: _extraChip(l, e), onTap: () => setState(() => _extras.add(e))),
        ]),
      ],
      if (widget.id != null) ...[
        const SizedBox(height: 24),
        TextButton(
          onPressed: _delete,
          child: Text(l.deleteContact, style: TextStyle(color: p.error, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ],
    ];
  }

  Widget _extraField(AppLocalizations l, YoncaPalette p, _Extra e) {
    final remove = IconButton(
      onPressed: () => setState(() {
        _extras.remove(e);
        if (e == _Extra.tags) _tags.clear();
      }),
      icon: Icon(Icons.close, color: p.error),
    );
    if (e == _Extra.tags) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: SectionLabel(l.fieldTags, padding: const EdgeInsets.fromLTRB(4, 8, 4, 8))),
          remove,
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in _tags) PillChip(label: t, onRemove: () => setState(() => _tags.remove(t))),
          PillChip(label: l.addTag, icon: Icons.add, onTap: _editTags),
        ]),
      ]);
    }
    return GlassField(
      controller: _controllerFor(e),
      label: _extraLabel(l, e),
      trailing: remove,
      maxLines: e == _Extra.requirements || e == _Extra.address ? 3 : 1,
      keyboardType: switch (e) {
        _Extra.email => TextInputType.emailAddress,
        _Extra.website => TextInputType.url,
        _ => null,
      },
      textDirection: e == _Extra.email || e == _Extra.website ? TextDirection.ltr : null,
    );
  }

  Widget _phoneRow(AppLocalizations l, int i) {
    final row = _phones[i];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GlassPickerField(label: i == 0 ? l.fieldPhone : ' ', value: row.code, onTap: () => _pickCode(row), error: _phoneShort),
      const SizedBox(width: 8),
      Expanded(
        child: GlassField(
          controller: row.number,
          label: ' ',
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          onChanged: (_) => setState(() {
            _duplicate = null;
            _phoneShort = false;
          }),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onLongPress: _phones.length > 1 ? () => setState(() => _phones.removeAt(i).dispose()) : null,
        child: GlassPickerField(label: ' ', value: phoneLabelText(l, row.label), onTap: () => _pickLabel(row)),
      ),
    ]);
  }

  Widget _duplicateCard(AppLocalizations l, YoncaPalette p, ContactSummary dup) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: p.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(child: Text('${l.duplicateTitle} · ${dup.displayName}', style: TextStyle(color: p.onErrorContainer, fontWeight: FontWeight.w500))),
        ]),
        const SizedBox(height: 8),
        TextButton(onPressed: () => _save(force: true), child: Text(l.saveAnyway)),
      ]),
    );
  }
}
