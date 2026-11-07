import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../data/app_database.dart' show ContactEvent;
import '../../l10n/app_localizations.dart';
import '../../shared/ds.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/lucide.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../contacts/contact_details_page.dart';
import '../settings/settings_widgets.dart';
import 'event_form_page.dart';
import 'schedule_labels.dart';

/// An event of a contact (birthday, renewal, …): what it is, when, who it is about and how it reminds.
/// Opened from the notification, the alarm and the bell; "Open contact" goes to the person.
class EventViewPage extends StatefulWidget {
  const EventViewPage({super.key, required this.controller, required this.id});
  final AppController controller;
  final int id;

  @override
  State<EventViewPage> createState() => _EventViewPageState();
}

class _EventViewPageState extends State<EventViewPage> {
  ContactEvent? _e;
  String _contact = '';
  String _company = '';

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = c.schedule, contacts = c.contacts;
    if (s == null || contacts == null) return;
    final e = await s.getEvent(widget.id);
    if (!mounted) return;
    if (e == null) {
      Navigator.of(context).pop();
      return;
    }
    final who = await contacts.get(e.contactId);
    if (!mounted) return;
    setState(() {
      _e = e;
      _contact = who?.fullName ?? '';
      _company = who?.contact.company ?? '';
    });
  }

  Future<void> _edit() async {
    final s = c.schedule, contacts = c.contacts;
    if (s == null || contacts == null) return;
    await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => EventFormPage(schedule: s, contacts: contacts, id: widget.id)));
    if (mounted) await _load();
  }

  void _openContact() {
    final e = _e;
    if (e == null) return;
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ContactDetailsPage(repo: c.contacts!, activities: c.activities, schedule: c.schedule, deals: c.deals, fields: c.fields, id: e.contactId),
    ));
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final ok = await showSheetDialog<bool>(
      context: context,
      builder: (ctx) => SheetDialog(
        title: Text(l.eventDeleteTitle),
        content: Text(l.eventDeleteBody),
        actions: [
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.delete, danger: true, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (ok != true) return;
    await c.schedule!.deleteEvent(widget.id);
    nav.pop();
  }

  /// The next time this event comes round (today counts), or its date when it does not repeat.
  DateTime _next(ContactEvent e) {
    final today = dayOnly(DateTime.now());
    if (!e.yearly) return dayOnly(e.date);
    var d = DateTime(today.year, e.date.month, e.date.day);
    if (d.isBefore(today)) d = DateTime(today.year + 1, e.date.month, e.date.day);
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final e = _e;
    if (e == null) {
      return const Scaffold(backgroundColor: Colors.transparent, body: GlassBackdrop(child: SafeArea(child: LoadingView())));
    }
    final locale = Localizations.localeOf(context).toString();
    final next = _next(e);
    final days = next.difference(dayOnly(DateTime.now())).inDays;
    final past = !e.yearly && days < 0;
    final time = e.alertMinutes == null ? null : formatClock(context, DateTime(next.year, next.month, next.day, e.alertMinutes! ~/ 60, e.alertMinutes! % 60));
    final reminders = [
      if (e.remindMask & 1 != 0) l.remSameDay,
      if (e.remindMask & 2 != 0) l.remDayBefore,
      if (e.remindMask & 4 != 0) l.remWeekBefore,
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(
            title: l.kindEvent,
            actions: [
              GlassIconButton(icon: Lu.pencil, onHeader: true, onTap: _edit),
              const SizedBox(width: AppSpace.sm),
              HeaderMenu<String>(
                onSelected: (_) => _delete(),
                actions: [MenuAction('delete', Lu.trash2, l.delete, danger: true)],
              ),
            ],
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.x5), children: [
              if (e.yearly) Wrap(children: [TagPill(l.evRepeatYear)]),
              if (e.yearly) const SizedBox(height: AppSpace.md),
              Text(e.title, style: TextStyle(fontSize: AppFont.pageTitle, height: AppLine.snug, fontWeight: AppWeight.semibold, color: p.text)),
              const SizedBox(height: AppSpace.lg),
              SettingsGroup(children: [
                SettingsRow(
                  icon: Lu.calendarDays,
                  title: dfmt(DateFormat.yMMMMEEEEd(locale), next),
                  subtitle: past ? null : l.daysShort(days),
                ),
                if (_contact.isNotEmpty) SettingsRow(icon: Lu.user, title: _contact, subtitle: _company.isEmpty ? null : _company, chevron: true, onTap: _openContact),
                if (reminders.isNotEmpty)
                  SettingsRow(
                    icon: Lu.alarmClock,
                    title: reminders.join(' · '),
                    subtitle: '${time == null ? '' : '$time · '}${e.alarm ? l.reminderTypeAlarm : l.reminderTypeNotification}',
                  ),
              ]),
              if (e.note.isNotEmpty) ...[
                SectionLabel(l.fieldDescriptionHead),
                GlassCard(padding: const EdgeInsets.all(AppSpace.lg), child: Text(e.note, style: const TextStyle(fontSize: AppFont.body, height: AppLine.normal))),
              ],
              if (_contact.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xl),
                PillButton(label: l.eventOpenContact, icon: Lu.user, height: AppControl.lg, onPressed: _openContact),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
