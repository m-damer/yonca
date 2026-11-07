import 'open_reminder.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/palette.dart';
import 'schedule_labels.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

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
  int _more = 0;
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
      final who = e == null ? '' : ((await widget.controller.contacts?.get(e.contactId))?.fullName ?? '');
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
      if (t?.contactId != null) who = (await widget.controller.contacts?.get(t!.contactId!))?.fullName ?? '';
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
        _who = m == null || m.contactNames.isEmpty ? '' : m.contactNames.first;
        _more = m == null || m.contactNames.isEmpty ? 0 : m.contactNames.length - 1;
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
    if (c.schedule == null || c.contacts == null) {
      Navigator.of(context).pop();
      return;
    }
    openReminder(context, c, widget.kind, widget.id, replace: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final locale = Localizations.localeOf(context).toString();
    final hide = widget.controller.hideLockDetails;
    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size.fromHeight(60)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
    );
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xxl),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: AppSpace.x5),
              if (_at != null) ...[
                Text(formatClock(context, _at!),
                    textAlign: TextAlign.center, style: TextStyle(fontSize: AppFont.clock, height: AppLine.flat, fontWeight: AppWeight.bold, color: p.text)),
                const SizedBox(height: AppSpace.sm),
                Text(dfmt(DateFormat.MMMMEEEEd(locale), _at!), textAlign: TextAlign.center, style: TextStyle(fontSize: AppFont.body, color: p.text2)),
              ],
              const SizedBox(height: AppSpace.x5),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: AppSize.s48,
                  height: AppControl.lg,
                  decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Icon(_isTask ? Lu.circleCheck : Lu.usersRound, size: AppIcon.lg, color: p.primary),
                ),
                const SizedBox(width: AppSpace.md),
                Text(_isTask ? l.alarmTask : l.alarmMeeting, style: TextStyle(fontSize: AppFont.title, fontWeight: AppWeight.semibold, color: p.text2)),
              ]),
              const SizedBox(height: AppSpace.lg),
              Text(hide ? (_isEvent ? l.alarmEventGeneric : (_isTask ? l.alarmTaskGeneric : l.alarmMeetingGeneric)) : (_found ? _title : ''),
                  textAlign: TextAlign.center, style: TextStyle(fontSize: AppFont.pageTitle, height: AppLine.snug, fontWeight: AppWeight.semibold, color: p.text)),
              if (!hide && _who.isNotEmpty) Padding(padding: const EdgeInsets.only(top: AppSpace.sm), child: Text(_who, textAlign: TextAlign.center, style: TextStyle(fontSize: AppFont.lead, height: AppLine.snug, color: p.text2))),
              if (!hide && _place.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.md),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Lu.mapPin, size: AppIcon.md, color: p.primary),
                    const SizedBox(width: AppSpace.sm),
                    Flexible(child: Text(_place, style: TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.semibold, color: p.primary))),
                    const SizedBox(width: AppSpace.sm),
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse('geo:0,0?q=${Uri.encodeComponent(_place)}'), mode: LaunchMode.externalApplication),
                      child: Text(l.actionMap, style: TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.semibold, color: p.primary, decoration: TextDecoration.underline)),
                    ),
                  ]),
                ),
              if (!hide && _more > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.lg),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
                      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.xl)),
                      child: Text(l.alarmMore(_more), style: TextStyle(fontSize: AppFont.label, fontWeight: AppWeight.semibold, color: p.text2)),
                    ),
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _snooze,
                style: style.merge(FilledButton.styleFrom(backgroundColor: p.primary, foregroundColor: p.onPrimary)),
                child: Text(l.alarmSnooze, style: const TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.semibold)),
              ),
              const SizedBox(height: AppSpace.md),
              OutlinedButton(
                onPressed: _found ? _open : null,
                style: style.merge(OutlinedButton.styleFrom(foregroundColor: p.text, side: BorderSide(color: p.glassBorder))),
                child: Text(l.alarmOpen, style: const TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.semibold)),
              ),
              const SizedBox(height: AppSpace.md),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: style.merge(TextButton.styleFrom(foregroundColor: p.text2)),
                child: Text(l.alarmDismiss, style: const TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.semibold)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
