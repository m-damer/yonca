import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/format.dart';
import '../../data/contacts_repository.dart';
import '../../domain/activity_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import '../settings/settings_widgets.dart' show AppSwitch;
import 'contact_picker.dart';

String _day(BuildContext context, DateTime d) => dfmt(DateFormat('d MMM', Localizations.localeOf(context).toString()), d);

/// Chip labels in the same order as the design: Calls, Visits, Messages, Notes, Tasks, Meetings, Deals.
String timelineKindLabel(AppLocalizations l, Object k) => switch (k) {
      ActivityType.call => l.tlCalls,
      ActivityType.visit => l.tlVisits,
      ActivityType.message => l.tlMessages,
      ActivityType.note => l.tlNotes,
      'tasks' => l.tlTasks,
      'meetings' => l.tlMeetings,
      _ => l.tlDeals,
    };

/// "Filter timeline" sheet. Returns the new filter, or null when closed without applying.
Future<TimelineFilter?> showTimelineFilter(
  BuildContext context, {
  required ContactsRepository contacts,
  required TimelineFilter current,
  required Future<int> Function(TimelineFilter) count,
}) {
  return showGlassSheet<TimelineFilter>(
    context,
    builder: (ctx) => _FilterBody(contacts: contacts, current: current, count: count),
  );
}

class _FilterBody extends StatefulWidget {
  const _FilterBody({required this.contacts, required this.current, required this.count});
  final ContactsRepository contacts;
  final TimelineFilter current;
  final Future<int> Function(TimelineFilter) count;

  @override
  State<_FilterBody> createState() => _FilterBodyState();
}

class _FilterBodyState extends State<_FilterBody> {
  late TimelineFilter _f = widget.current;
  int? _n;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _recount();
  }

  Future<void> _recount() async {
    final my = ++_seq;
    final n = await widget.count(_f);
    if (mounted && my == _seq) setState(() => _n = n);
  }

  void _set(TimelineFilter f) {
    setState(() => _f = f);
    _recount();
  }

  Future<void> _pickDate(bool from) async {
    final cur = (from ? _f.from : _f.to) ?? DateTime.now();
    final d = await showDatePicker(context: context, initialDate: cur, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d == null || !mounted) return;
    _set(from ? _f.copyWith(from: d) : _f.copyWith(to: d));
  }

  Future<void> _pickContact() async {
    final c = await pickContact(context, widget.contacts, allowNone: true);
    if (c == null || !mounted) return;
    _set(_f.copyWith(contactId: c.id, contactName: c.id == null ? null : c.name));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    Widget chip(String label, bool on, VoidCallback tap) => GestureDetector(
          onTap: tap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: on ? p.primary : p.surface2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: on ? p.primary : Colors.transparent),
            ),
            child: Center(widthFactor: 1, child: Text(label, style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? p.onPrimary : p.text))),
          ),
        );

    Widget typeChip(ActivityType t) => chip(timelineKindLabel(l, t), _f.types.contains(t), () {
          final s = {..._f.types};
          s.contains(t) ? s.remove(t) : s.add(t);
          _set(_f.copyWith(types: s));
        });

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(l.tlFilterTitle, style: TextStyle(fontSize: 22, height: 34.8 / 22, fontWeight: FontWeight.w600, color: p.text)),
        SectionLabel(l.tlType, padding: const EdgeInsets.fromLTRB(0, 16, 0, 8)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in ActivityType.values) typeChip(t),
          chip(l.tlTasks, _f.tasks, () => _set(_f.copyWith(tasks: !_f.tasks))),
          chip(l.tlMeetings, _f.meetings, () => _set(_f.copyWith(meetings: !_f.meetings))),
          chip(l.tlDeals, _f.deals, () => _set(_f.copyWith(deals: !_f.deals))),
        ]),
        const SizedBox(height: 27),
        GlassSelectField(label: l.fieldContact, value: _f.contactName ?? l.filterAllTypes, onTap: _pickContact, trailing: const SizedBox.shrink()),
        const SizedBox(height: 27),
        Row(children: [
          Expanded(child: GlassSelectField(label: l.tlFrom, value: _f.from == null ? '' : _day(context, _f.from!), onTap: () => _pickDate(true), trailing: const SizedBox.shrink())),
          const SizedBox(width: 10),
          Expanded(child: GlassSelectField(label: l.tlTo, value: _f.to == null ? '' : _day(context, _f.to!), onTap: () => _pickDate(false), trailing: const SizedBox.shrink())),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text(l.tlNoContactOnly, style: const TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w500))),
          AppSwitch(value: _f.noContactOnly, onChanged: (v) => _set(_f.copyWith(noContactOnly: v, contactId: v ? null : _f.contactId, contactName: v ? null : _f.contactName))),
        ]),
        const SizedBox(height: 26),
        Row(children: [
          Expanded(flex: 146, child: PillButton(label: l.tlReset, outlined: true, height: 48, onPressed: () => _set(const TimelineFilter()))),
          const SizedBox(width: 10),
          Expanded(flex: 202, child: PillButton(label: l.tlShowResults(_n ?? 0), height: 48, onPressed: () => Navigator.of(context).pop(_f))),
        ]),
      ]),
    );
  }
}
