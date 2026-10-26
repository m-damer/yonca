import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../schedule/meeting_form_page.dart';
import '../schedule/schedule_labels.dart';
import '../schedule/schedule_widgets.dart';
import '../schedule/task_form_page.dart';
import '../settings/updates_page.dart';

/// What needs a look: missed alarms, overdue tasks, and system news (a new version).
class BellData {
  const BellData({required this.missed, required this.overdue, required this.updateVersion});
  final List<ReminderSpec> missed;
  final List<ScheduleItem> overdue;
  final String? updateVersion;

  int get badge => missed.length + (updateVersion == null ? 0 : 1);
  bool get isEmpty => missed.isEmpty && overdue.isEmpty && updateVersion == null;
}

Future<BellData> loadBell(AppController c) async {
  final s = c.schedule;
  final v = c.pref(AppController.keyUpdateAvailable);
  if (s == null) return BellData(missed: const [], overdue: const [], updateVersion: v == null || v.isEmpty ? null : v);
  final now = DateTime.now();
  return BellData(
    missed: await s.missedAlarms(now, c.ackedAlarms),
    overdue: await s.overdueTasks(),
    updateVersion: v == null || v.isEmpty ? null : v,
  );
}

/// Bell icon for the Home header, with a count of missed alarms and news.
class BellButton extends StatefulWidget {
  const BellButton({super.key, required this.controller});
  final AppController controller;

  @override
  State<BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<BellButton> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.schedule?.revision.addListener(_load);
    widget.controller.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.controller.schedule?.revision.removeListener(_load);
    widget.controller.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final b = await loadBell(widget.controller);
    if (mounted && b.badge != _count) setState(() => _count = b.badge);
  }

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: _count > 0,
      label: Text('$_count'),
      child: GlassIconButton(
        icon: Icons.notifications_outlined,
        onHeader: true,
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BellPage(controller: widget.controller)));
          _load();
        },
      ),
    );
  }
}

class BellPage extends StatefulWidget {
  const BellPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<BellPage> createState() => _BellPageState();
}

class _BellPageState extends State<BellPage> {
  BellData? _data;

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await loadBell(c);
    if (mounted) setState(() => _data = d);
  }

  Future<void> _openMissed(ReminderSpec r) async {
    final s = c.schedule, contacts = c.contacts;
    if (s == null || contacts == null) return;
    await c.ackAlarm(r.kind, r.refId);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => r.kind == 'task'
          ? TaskFormPage(schedule: s, contacts: contacts, id: r.refId)
          : MeetingFormPage(schedule: s, contacts: contacts, id: r.refId),
    ));
    _load();
  }

  Future<void> _markAllSeen() async {
    final d = _data;
    if (d == null) return;
    for (final r in d.missed) {
      await c.ackAlarm(r.kind, r.refId);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final d = _data;
    Widget section(String title, List<Widget> rows, {Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionLabel(title),
          GlassCard(padding: EdgeInsets.zero, child: Material(type: MaterialType.transparency, child: Column(children: rows))),
        ]);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                GlassIconButton(icon: Icons.arrow_back, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 14),
                Expanded(child: Text(l.bellTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.onHeader))),
                if (d != null && d.missed.isNotEmpty) TextButton(onPressed: _markAllSeen, child: Text(l.bellMarkSeen, style: TextStyle(color: p.onHeader))),
              ]),
            ),
          ),
          Expanded(
            child: d == null
                ? const SizedBox.shrink()
                : d.isEmpty
                    ? Center(child: Text(l.bellEmpty, style: TextStyle(color: p.text2)))
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
                        if (d.missed.isNotEmpty)
                          section(l.bellMissed, [
                            for (final r in d.missed)
                              ListTile(
                                leading: Icon(Icons.alarm_off_outlined, color: p.error),
                                title: Text(r.title),
                                subtitle: Text('${formatDay(context, r.at)} · ${formatClock(context, r.at)}'),
                                onTap: () => _openMissed(r),
                              ),
                          ]),
                        if (d.overdue.isNotEmpty && c.schedule != null && c.contacts != null)
                          section(l.sectionOverdue, [
                            for (final i in d.overdue)
                              ScheduleRow(
                                item: i,
                                showDate: true,
                                onTap: () async {
                                  await openScheduleItem(context, item: i, schedule: c.schedule!, contacts: c.contacts!);
                                  _load();
                                },
                              ),
                          ]),
                        if (d.updateVersion != null)
                          section(l.bellSystem, [
                            ListTile(
                              leading: Icon(Icons.system_update_alt, color: p.primary),
                              title: Text(l.bellUpdate(d.updateVersion!)),
                              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => UpdatesPage(controller: c))),
                            ),
                          ]),
                      ]),
          ),
        ]),
      ),
    );
  }
}
