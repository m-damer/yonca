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
  final FocusNode focus = FocusNode();
  String label;
  void dispose() {
    number.dispose();
    focus.dispose();
  }
}

/// One email, website or address row. Addresses also use [map] for the map link.
class _EntryRow {
  _EntryRow({String value = '', this.label = 'work', String map = ''})
      : value = TextEditingController(text: value),
        map = TextEditingController(text: map);
  final TextEditingController value;
  final TextEditingController map;
  final FocusNode focus = FocusNode();
  String label;
  void dispose() {
    value.dispose();
    map.dispose();
    focus.dispose();
  }
}

const _kinds = ['email', 'website', 'address'];

enum _Extra { jobTitle, nickname, requirements, tags }

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
  final _job = TextEditingController();
  final _nick = TextEditingController();
  final _requirements = TextEditingController();
  final _note = TextEditingController();
  final _phones = <_PhoneRow>[];
  final _extras = <_Extra>[];
  final _tags = <String>[];
  final _roles = <Role>{};
  Rating _rating = Rating.none;
  final _entries = {for (final k in _kinds) k: <_EntryRow>[]};

  /// Which typed field (phone row, email, address, website) is being edited: it shows its Label field.
  String? _expanded;
  bool _labelSheetOpen = false;
  bool _loading = true;
  bool _saving = false;
  bool _nameMissing = false;
  bool _phoneShort = false;
  String _initial = '';
  ContactSummary? _duplicate;

  TextEditingController _controllerFor(_Extra e) => switch (e) {
        _Extra.jobTitle => _job,
        _Extra.nickname => _nick,
        _Extra.requirements => _requirements,
        _Extra.tags => _first,
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  _EntryRow _newEntry(String kind, {String value = '', String label = 'work', String map = ''}) {
    final row = _EntryRow(value: value, label: label, map: map);
    row.focus.addListener(() {
      if (!mounted) return;
      final key = '$kind:${_entries[kind]!.indexOf(row)}';
      if (row.focus.hasFocus) {
        if (_expanded != key) setState(() => _expanded = key);
      } else if (!_labelSheetOpen && _expanded == key) {
        setState(() => _expanded = null);
      }
    });
    return row;
  }

  _PhoneRow _newPhone({String code = '+963', String number = '', String label = 'mobile'}) {
    final row = _PhoneRow(code: code, number: number, label: label);
    row.focus.addListener(() {
      if (!mounted) return;
      final key = 'phone:${_phones.indexOf(row)}';
      if (row.focus.hasFocus) {
        if (_expanded != key) setState(() => _expanded = key);
      } else if (!_labelSheetOpen && _expanded == key) {
        setState(() => _expanded = null);
      }
    });
    return row;
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
          emails: [for (final e in s.emails) EntryInput(value: e.value, label: e.label)],
          websites: [for (final e in s.websites) EntryInput(value: e.value, label: e.label)],
          addresses: [for (final e in s.addresses) EntryInput(value: e.value, label: e.label, mapLink: e.mapLink)],
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
      _job.text = input.jobTitle;
      for (final e in input.emails) {
        _entries['email']!.add(_newEntry('email', value: e.value, label: e.label));
      }
      for (final e in input.websites) {
        _entries['website']!.add(_newEntry('website', value: e.value, label: e.label));
      }
      for (final e in input.addresses) {
        _entries['address']!.add(_newEntry('address', value: e.value, label: e.label, map: e.mapLink));
      }
      _nick.text = input.nickname;
      _requirements.text = input.requirements;
      _note.text = input.temporaryNote;
      _rating = input.rating;
      _roles.addAll(input.roles);
      _tags.addAll(input.tags);
      for (final p in input.phones) {
        _phones.add(_newPhone(code: p.countryCode, number: p.number, label: p.label));
      }
      if (input.jobTitle.isNotEmpty) _extras.add(_Extra.jobTitle);
      if (input.nickname.isNotEmpty) _extras.add(_Extra.nickname);
      if (input.requirements.isNotEmpty) _extras.add(_Extra.requirements);
      if (input.tags.isNotEmpty) _extras.add(_Extra.tags);
    }
    if (_phones.isEmpty) _phones.add(_newPhone());
    _initial = _signature();
    if (mounted) setState(() => _loading = false);
  }

  String _signature() => [
        _first.text, _last.text, _company.text, _job.text, _nick.text,
        _requirements.text, _note.text, _rating.name, _roles.map((r) => r.name).join(','), _tags.join(','),
        _phones.map((p) => '${p.code}${p.number.text}${p.label}').join(','),
        for (final k in _kinds) _entries[k]!.map((e) => '${e.value.text}${e.label}${e.map.text}').join(','),
      ].join('|');

  bool get _dirty => !_loading && _signature() != _initial;

  @override
  void dispose() {
    for (final c in [_first, _last, _company, _job, _nick, _requirements, _note]) {
      c.dispose();
    }
    for (final p in _phones) {
      p.dispose();
    }
    for (final list in _entries.values) {
      for (final e in list) {
        e.dispose();
      }
    }
    super.dispose();
  }

  ContactInput _input() => ContactInput(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        company: _company.text.trim(),
        nickname: _extras.contains(_Extra.nickname) ? _nick.text.trim() : '',
        jobTitle: _extras.contains(_Extra.jobTitle) ? _job.text.trim() : '',
        emails: _entryInputs('email'),
        websites: _entryInputs('website'),
        addresses: _entryInputs('address'),
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

  List<EntryInput> _entryInputs(String kind) => [
        for (final e in _entries[kind]!)
          if (e.value.text.trim().isNotEmpty)
            EntryInput(value: e.value.text.trim(), label: e.label, mapLink: kind == 'address' ? e.map.text.trim() : ''),
      ];

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
        _Extra.jobTitle => l.fieldJobTitle,
        _Extra.nickname => l.fieldNickname,
        _Extra.requirements => l.fieldRequirements,
        _Extra.tags => l.fieldTags,
      };

  String _extraChip(AppLocalizations l, _Extra e) => switch (e) {
        _Extra.jobTitle => l.chipJobTitle,
        _Extra.nickname => l.chipNickname,
        _Extra.requirements => l.chipRequirements,
        _Extra.tags => l.chipTags,
      };

  /// Opens the label list for a typed field. [options] are label keys; returns the chosen key.
  Future<String?> _chooseLabel(String title, List<String> options, String current) async {
    final l = AppLocalizations.of(context);
    _labelSheetOpen = true;
    final picked = await showGlassSheet<String>(
      context,
      builder: (ctx) {
        final p = ctx.palette;
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          for (final v in options)
            InkWell(
              onTap: () => Navigator.of(ctx).pop(v),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                child: Row(children: [
                  Expanded(
                    child: Text(phoneLabelText(l, v),
                        style: TextStyle(fontSize: 17, fontWeight: current == v ? FontWeight.w700 : FontWeight.w400)),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: current == v ? p.primary : Colors.transparent,
                      border: Border.all(color: current == v ? p.primary : p.outline, width: 2),
                    ),
                    child: current == v ? Icon(Icons.check, size: 17, color: p.onPrimary) : null,
                  ),
                ]),
              ),
            ),
        ]);
      },
    );
    _labelSheetOpen = false;
    return picked;
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
          child: _loading
              ? const SafeArea(child: LoadingView())
              : Column(children: [
                    HeaderBand(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      child: Row(children: [
                        GlassIconButton(icon: Icons.close, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(widget.id == null ? l.newContact : l.formTitleEdit,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.onHeader)),
                        ),
                        SizedBox(
                          width: 88,
                          child: PillButton(label: l.save, height: 44, accent: true, onPressed: _saving ? null : _save),
                        ),
                      ]),
                    ),
                    Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: _content(l, p))),
                  ]),
        ),
      ),
    );
  }

  List<Widget> _content(AppLocalizations l, YoncaPalette p) {
    final remaining = [for (final e in _Extra.values) if (!_extras.contains(e)) e];
    final emptyKinds = [for (final k in _kinds) if (_entries[k]!.isEmpty) k];
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
      if (_duplicate != null) _duplicateCard(l, p, _duplicate!),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => setState(() => _phones.add(_newPhone())),
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
      for (final k in _kinds) ..._entryGroup(l, k),
      for (final e in _extras) ...[_extraField(l, p, e), const SizedBox(height: 12)],
      SectionLabel(l.fieldTempNote),
      GlassField(controller: _note, label: ' ', maxLines: 4, hint: l.optionalHint),
      if (remaining.isNotEmpty || emptyKinds.isNotEmpty) ...[
        SectionLabel(l.addMoreInfo),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in emptyKinds) PillChip(label: _kindChip(l, k), onTap: () => setState(() => _entries[k]!.add(_newEntry(k)))),
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

  /// A field with a type (Google Contacts style): while it is not being edited the type shows in the
  /// label, for example "Phone (Mobile)"; while editing, the label is plain and a Label field appears below.
  Widget _typed({
    required String key,
    required String label,
    required String typeKey,
    required GlassField Function(String shownLabel) field,
    required Future<void> Function() onPickType,
    required VoidCallback onRemove,
    Widget? below,
  }) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final open = _expanded == key;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          field(open ? label : '$label (${phoneLabelText(l, typeKey)})'),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GlassSelectField(label: l.phoneLabel, value: phoneLabelText(l, typeKey), onTap: onPickType),
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (below != null) Padding(padding: const EdgeInsets.only(top: 12), child: below),
        ]),
      ),
      const SizedBox(width: 4),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: IconButton(
          tooltip: l.delete,
          onPressed: onRemove,
          icon: Icon(Icons.remove_circle_outline, color: p.error.withValues(alpha: .8)),
        ),
      ),
    ]);
  }

  Widget _extraField(AppLocalizations l, YoncaPalette p, _Extra e) {
    void remove() => setState(() {
          _extras.remove(e);
          if (e == _Extra.tags) _tags.clear();
          if (_expanded == e.name) _expanded = null;
        });
    switch (e) {
      case _Extra.tags:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: SectionLabel(l.fieldTags, padding: const EdgeInsets.fromLTRB(4, 8, 4, 8))),
            IconButton(onPressed: remove, icon: Icon(Icons.remove_circle_outline, color: p.error.withValues(alpha: .8))),
          ]),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in _tags) PillChip(label: t, onRemove: () => setState(() => _tags.remove(t))),
            PillChip(label: l.addTag, icon: Icons.add, onTap: _editTags),
          ]),
        ]);
      case _Extra.jobTitle:
      case _Extra.nickname:
      case _Extra.requirements:
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: GlassField(
              controller: _controllerFor(e),
              label: _extraLabel(l, e),
              maxLines: e == _Extra.requirements ? 3 : 1,
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: IconButton(onPressed: remove, icon: Icon(Icons.remove_circle_outline, color: p.error.withValues(alpha: .8))),
          ),
        ]);
    }
  }

  String _addText(AppLocalizations l, String kind) =>
      switch (kind) { 'email' => l.addEmail, 'website' => l.addWebsite, _ => l.addAddress };

  String _kindLabel(AppLocalizations l, String kind) =>
      switch (kind) { 'email' => l.fieldEmail, 'website' => l.fieldWebsite, _ => l.fieldAddress };

  String _kindChip(AppLocalizations l, String kind) =>
      switch (kind) { 'email' => l.chipEmail, 'website' => l.chipWebsite, _ => l.chipAddress };

  /// All rows of one kind (email, website or address) and an "Add …" button below them.
  List<Widget> _entryGroup(AppLocalizations l, String kind) {
    final list = _entries[kind]!;
    if (list.isEmpty) return const [];
    return [
      for (var i = 0; i < list.length; i++) ...[
        _typed(
          key: '$kind:$i',
          label: _kindLabel(l, kind),
          typeKey: list[i].label,
          onRemove: () => setState(() {
            list.removeAt(i).dispose();
            _expanded = null;
          }),
          onPickType: () async {
            final v = await _chooseLabel(l.phoneLabel, const ['work', 'home', 'other'], list[i].label);
            if (v != null) setState(() => list[i].label = v);
          },
          field: (shown) => GlassField(
            controller: list[i].value,
            focusNode: list[i].focus,
            label: shown,
            maxLines: kind == 'address' ? 3 : 1,
            keyboardType: switch (kind) {
              'email' => TextInputType.emailAddress,
              'website' => TextInputType.url,
              _ => TextInputType.streetAddress,
            },
            textDirection: kind == 'address' ? null : TextDirection.ltr,
          ),
          below: kind == 'address'
              ? GlassField(
                  controller: list[i].map,
                  label: l.fieldMapLink,
                  hint: l.mapLinkHint,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                )
              : null,
        ),
        const SizedBox(height: 12),
      ],
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => setState(() => list.add(_newEntry(kind))),
          icon: const Icon(Icons.add),
          label: Text(_addText(l, kind)),
        ),
      ),
      const SizedBox(height: 4),
    ];
  }

  Widget _phoneRow(AppLocalizations l, int i) {
    final row = _phones[i];
    final short = _phoneShort && phoneTooShort(row.code, row.number.text);
    return _typed(
      key: 'phone:$i',
      label: l.fieldPhone,
      typeKey: row.label,
      onRemove: () => setState(() {
        if (_phones.length > 1) {
          _phones.removeAt(i).dispose();
        } else {
          row.number.clear();
        }
        _expanded = null;
      }),
      onPickType: () async {
        final v = await _chooseLabel(l.phoneLabelTitle, const ['mobile', 'work', 'home', 'whatsapp', 'other'], row.label);
        if (v != null) setState(() => row.label = v);
      },
      field: (shown) => GlassField(
        controller: row.number,
        focusNode: row.focus,
        label: shown,
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        leading: CountrySelector(code: row.code, onTap: () => _pickCode(row)),
        prefixText: row.code,
        error: short ? l.errPhoneShort : null,
        onChanged: (_) => setState(() {
          _duplicate = null;
          _phoneShort = false;
        }),
      ),
    );
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
