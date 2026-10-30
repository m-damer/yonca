import 'event_form_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/palette.dart';
import 'meeting_form_page.dart';
import 'schedule_labels.dart';
import 'task_form_page.dart';

/// Full-screen alarm (design S38): time, what it is, and three big buttons. It shows over the lock
/// screen when an alarm notification launches the app.
class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key, required this.controller, required this.kind, required this.id});
  final AppController controller;
  final String kind;
  final int id;

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  String _title = '';
  String _who = '';
  String _place = '';
  DateTime? _at;
  bool _found = true;

  bool get _isTask => widget.kind == 'task';
  bool get _isEvent => widget.kind == 'event';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = widget.controller.schedule;
    if (s == null) return;
    if (_isEvent) {
      final e = await s.getEvent(widget.id);
      final who = e == null ? '' : ((await widget.controller.contacts?.get(e.contactId))?.displayName ?? '');
      if (!mounted) return;
      setState(() {
        _found = e != null;
        _title = e?.title ?? '';
        _at = null;
        _who = who;
      });
    } else if (_isTask) {
      final t = await s.getTask(widget.id);
      String who = '';
      if (t?.contactId != null) who = (await widget.controller.contacts?.get(t!.contactId!))?.displayName ?? '';
      if (!mounted) return;
      setState(() {
        _found = t != null;
        _title = t?.title ?? '';
        _at = t?.hasTime == true ? t!.dueAt : null;
        _who = who;
      });
    } else {
      final m = await s.getMeeting(widget.id);
      if (!mounted) return;
      setState(() {
        _found = m != null;
        _title = m?.meeting.title ?? '';
        _at = m?.meeting.startAt;
        _who = m?.contactNames.join(', ') ?? '';
        _place = m?.meeting.place ?? '';
      });
    }
  }

  Future<void> _snooze() async {
    final s = widget.controller.schedule;
    final until = DateTime.now().add(const Duration(minutes: 15));
    if (s != null) {
      if (_isEvent) {
        // Events have no snooze; the alarm is just dismissed.
      } else if (_isTask) {
        await s.snoozeTask(widget.id, until);
      } else {
        await s.snoozeMeeting(widget.id, until);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _open() {
    final c = widget.controller;
    final s = c.schedule, contacts = c.contacts;
    if (s == null || contacts == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => _isEvent
          ? EventFormPage(schedule: s, contacts: contacts, id: widget.id)
          : (_isTask ? TaskFormPage(schedule: s, contacts: contacts, id: widget.id) : MeetingFormPage(schedule: s, contacts: contacts, id: widget.id)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final locale = Localizations.localeOf(context).toString();
    final hide = widget.controller.hideLockDetails;
    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size.fromHeight(60)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
    );
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 40),
              if (_at != null) ...[
                Text(formatClock(context, _at!),
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 72, height: 1, fontWeight: FontWeight.w700, color: p.text)),
                const SizedBox(height: 8),
                Text(dfmt(DateFormat.MMMMEEEEd(locale), _at!), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: p.text2)),
              ],
              const SizedBox(height: 36),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
                  child: Icon(_isTask ? Icons.task_alt_outlined : Icons.groups_outlined, size: 24, color: p.primary),
                ),
                const SizedBox(width: 12),
                Text(_isTask ? l.alarmTask : l.alarmMeeting, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: p.text2)),
              ]),
              const SizedBox(height: 16),
              Text(hide ? (_isEvent ? l.alarmEventGeneric : (_isTask ? l.alarmTaskGeneric : l.alarmMeetingGeneric)) : (_found ? _title : ''),
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, color: p.text)),
              if (!hide && _who.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_who, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, height: 24 / 18, color: p.text2))),
              if (!hide && _place.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.place_outlined, size: 18, color: p.primary),
                    const SizedBox(width: 6),
                    Flexible(child: Text(_place, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.primary))),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse('geo:0,0?q=${Uri.encodeComponent(_place)}'), mode: LaunchMode.externalApplication),
                      child: Text(l.actionMap, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.primary, decoration: TextDecoration.underline)),
                    ),
                  ]),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _snooze,
                style: style.merge(FilledButton.styleFrom(backgroundColor: p.primary, foregroundColor: p.onPrimary)),
                child: Text(l.alarmSnooze, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _found ? _open : null,
                style: style.merge(OutlinedButton.styleFrom(foregroundColor: p.text, side: BorderSide(color: p.glassBorder))),
                child: Text(l.alarmOpen, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: style.merge(TextButton.styleFrom(foregroundColor: p.text2)),
                child: Text(l.alarmDismiss, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
