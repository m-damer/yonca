import 'package:flutter/material.dart';

import '../../app_controller.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = widget.controller.schedule;
    if (s == null) return;
    if (_isTask) {
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
      if (_isTask) {
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
      builder: (_) => _isTask
          ? TaskFormPage(schedule: s, contacts: contacts, id: widget.id)
          : MeetingFormPage(schedule: s, contacts: contacts, id: widget.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final style = ButtonStyle(minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)));
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: p.header,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Spacer(),
              Icon(_isTask ? Icons.task_alt : Icons.event, size: 48, color: p.accent),
              const SizedBox(height: 8),
              Text(_isTask ? l.alarmTask : l.alarmMeeting,
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: p.onHeader.withValues(alpha: .85))),
              if (_at != null) ...[
                const SizedBox(height: 8),
                Text(formatClock(context, _at!), textAlign: TextAlign.center, style: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: p.onHeader)),
              ],
              const SizedBox(height: 12),
              Text(_found ? _title : '', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: p.onHeader)),
              if (_who.isNotEmpty) Text(_who, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: p.onHeader.withValues(alpha: .9))),
              if (_place.isNotEmpty) Text(_place, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: p.onHeader.withValues(alpha: .8))),
              const Spacer(),
              FilledButton(
                onPressed: _snooze,
                style: style.merge(FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.onAccent)),
                child: Text(l.alarmSnooze, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _found ? _open : null,
                style: style.merge(OutlinedButton.styleFrom(foregroundColor: p.onHeader, side: BorderSide(color: p.onHeader))),
                child: Text(l.alarmOpen, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: style.merge(TextButton.styleFrom(foregroundColor: p.onHeader.withValues(alpha: .85))),
                child: Text(l.alarmDismiss, style: const TextStyle(fontSize: 16)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
