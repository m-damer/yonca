import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../domain/activity_models.dart';
import '../../domain/contact_models.dart';
import '../../domain/deal_models.dart';
import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/leaf_logo.dart';
import '../../core/text_normalize.dart';
import '../../data/app_database.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../activities/activity_card.dart';
import '../activities/activity_feed.dart';
import '../activities/log_activity_page.dart';
import '../contacts/contact_row.dart';
import '../deals/deal_widgets.dart';
import '../schedule/schedule_labels.dart';
import '../schedule/schedule_widgets.dart';
import '../bell/bell_page.dart';
import '../schedule/meeting_form_page.dart';
import '../importing/import_page.dart';
import '../importing/scan_page.dart';
import '../search/search_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../stats/stats_page.dart';
import '../../domain/stats_models.dart';

/// Home (design S01): greeting, quick actions, what is due, who needs attention, pipeline, recent activity.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.controller, required this.onOpenContact, required this.onGoTab, required this.onNewContact});
  final AppController controller;
  final void Function(int contactId) onOpenContact;

  /// Switches the bottom bar to a tab index.
  final void Function(int index) onGoTab;
  final VoidCallback onNewContact;

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  List<ScheduleItem> _overdue = const [];
  List<ScheduleItem> _today = const [];
  List<ScheduleItem> _soon = const [];
  List<ScheduleItem> _ended = const [];
  List<ContactSummary> _attention = const [];
  List<ContactSummary> _recent = const [];
  List<ContactSummary> _toComplete = const [];
  List<StageSummary> _pipeline = const [];
  List<ActivityItem> _activity = const [];
  List<(TargetValue, double, DateTime)> _targets = const [];
  int _contactTotal = 0;
  String _name = '';
  bool _loaded = false;

  static const _hiddenKey = 'recent.hidden';

  @override
  void initState() {
    super.initState();
    widget.controller.schedule?.revision.addListener(reload);
    widget.controller.deals?.revision.addListener(reload);
    reload();
  }

  @override
  void dispose() {
    widget.controller.schedule?.revision.removeListener(reload);
    widget.controller.deals?.revision.removeListener(reload);
    super.dispose();
  }

  Future<Set<int>> _hidden() async {
    final raw = await widget.controller.database?.getSetting(_hiddenKey) ?? '';
    return {for (final e in raw.split(',')) if (int.tryParse(e) != null) int.parse(e)};
  }

  Future<void> reload() async {
    final c = widget.controller;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final s = c.schedule;
    final overdue = await s?.overdueTasks() ?? const <ScheduleItem>[];
    final week = await s?.itemsBetween(start, start.add(const Duration(days: 4)), includeDone: false) ?? const <ScheduleItem>[];
    final past = await s?.itemsBetween(start.subtract(const Duration(days: 3)), now, includeDone: false) ?? const <ScheduleItem>[];
    final end = start.add(const Duration(days: 1));
    final attention = await c.contacts?.list(inactiveForDays: 14, sort: ContactSort.needsAttention) ?? const <ContactSummary>[];
    final all = await c.contacts?.list(sort: ContactSort.recentActivity) ?? const <ContactSummary>[];
    final pipeline = await c.deals?.summaries() ?? const <StageSummary>[];
    final acts = await c.activities?.list(limit: 8) ?? const <ActivityItem>[];
    final targets = await c.stats?.progress() ?? const <(TargetValue, double, DateTime)>[];
    final name = await c.database?.getSetting('profile.name') ?? '';
    final hidden = await _hidden();
    if (!mounted) return;
    setState(() {
      _overdue = overdue;
      _today = [for (final i in week) if (i.at.isBefore(end)) i];
      _soon = [for (final i in week) if (!i.at.isBefore(end)) i];
      _ended = [
        for (final i in past)
          if (i.kind == ScheduleKind.meeting && !i.cancelled && !i.done && (i.endAt ?? i.at).isBefore(now)) i
      ];
      _attention = attention.where((x) => !x.isIncomplete).take(3).toList();
      _recent = all.where((x) => !x.isIncomplete && !hidden.contains(x.contact.id)).take(6).toList();
      _toComplete = all.where((x) => x.isIncomplete).take(3).toList();
      _contactTotal = all.length;
      _pipeline = [for (final p in pipeline) if (p.stage.kind == 'open') p];
      _activity = acts;
      _targets = targets;
      _name = name.trim();
      _loaded = true;
    });
  }

  // ---- small pieces ----

  Widget _title(String t, {String? trailing, VoidCallback? onTap, Color? color, IconData? icon, Widget? badge}) {
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 20, color: color), const SizedBox(width: 6)],
        Expanded(child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color ?? pal.text))),
        if (badge != null) badge,
        if (trailing != null)
          onTap != null
              ? InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(trailing, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: pal.primary))))
              : Text(trailing, style: TextStyle(fontSize: 13, color: pal.text2)),
      ]),
    );
  }

  Widget _group(List<Widget> rows) {
    final p = context.palette;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: p.glassBorder),
          rows[i],
        ],
      ]),
    );
  }

  Widget _btn(String label, VoidCallback onTap, {bool filled = false, Color? color, IconData? icon}) {
    final p = context.palette;
    final c = color ?? p.primary;
    final fg = filled ? (color == null ? p.onPrimary : Theme.of(context).colorScheme.onError) : c;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: filled ? c : null,
          borderRadius: BorderRadius.circular(20),
          border: filled ? null : Border.all(color: c, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
        ]),
      ),
    );
  }

  Future<void> _openItem(ScheduleItem i) async {
    final c = widget.controller;
    await openScheduleItem(context, item: i, schedule: c.schedule!, contacts: c.contacts!, onOpenContact: widget.onOpenContact);
    await reload();
  }

  Future<void> _toggle(ScheduleItem i) async {
    final s = widget.controller.schedule!;
    if (i.done) {
      await s.reopenTask(i.id);
    } else {
      await s.completeTask(i.id);
    }
  }

  Widget _row(ScheduleItem i, {bool date = false}) => ScheduleRow(
        item: i,
        showDate: date,
        flat: true,
        onTap: () => _openItem(i),
        onToggle: i.kind == ScheduleKind.task ? () => _toggle(i) : null,
      );

  String _since(ScheduleItem i) {
    final l = AppLocalizations.of(context);
    return l.homeOverdueSince(formatDay(context, i.at));
  }

  Future<void> _snooze(ScheduleItem i) async {
    final l = AppLocalizations.of(context);
    final s = widget.controller.schedule!;
    final now = DateTime.now();
    final pal = context.palette;
    Widget option(IconData icon, String text, Future<void> Function() run, BuildContext ctx) => Material(
          type: MaterialType.transparency,
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: pal.primaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: pal.onPrimaryContainer),
            ),
            title: Text(text, style: const TextStyle(fontSize: 16)),
            onTap: () async {
              Navigator.of(ctx).pop();
              await run();
            },
          ),
        );
    await showGlassSheet<void>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text(l.snoozeSheetTitle(i.title), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text([if (i.contactLabel != null) i.contactLabel!, _since(i)].join(' · '), style: TextStyle(color: pal.text2)),
        ),
        option(Icons.schedule, l.snoozeIn1h, () => s.snoozeTask(i.id, now.add(const Duration(hours: 1))), ctx),
        option(Icons.event, l.snoozeTomorrow, () => s.snoozeTask(i.id, DateTime(now.year, now.month, now.day + 1, 9)), ctx),
        option(Icons.edit_calendar_outlined, l.snoozePick, () async {
          final d = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: DateTime(now.year + 3));
          if (d == null || !mounted) return;
          final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
          if (t == null) return;
          await s.snoozeTask(i.id, DateTime(d.year, d.month, d.day, t.hour, t.minute));
        }, ctx),
      ]),
    );
    await reload();
  }

  Future<void> _recentMenu(ContactSummary s) async {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final c = widget.controller;
    ContactPhone? phone = s.phones.isEmpty ? null : s.phones.first;
    Widget item(IconData icon, String text, VoidCallback run, BuildContext ctx) => Material(
          type: MaterialType.transparency,
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: pal.primaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: pal.onPrimaryContainer),
            ),
            title: Text(text),
            onTap: () {
              Navigator.of(ctx).pop();
              run();
            },
          ),
        );
    final first = s.displayName.split(' ').first;
    await showGlassSheet<void>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        if (phone != null) ...[
          item(Icons.call_outlined, l.recentCall(first), () => launchUrl(Uri(scheme: 'tel', path: '${phone.countryCode}${phone.number}'.replaceAll(' ', ''))), ctx),
          item(Icons.chat_outlined, l.recentWhatsApp(first), () => launchUrl(Uri.parse('https://wa.me/${normalizePhone(phone.countryCode, phone.number)}'), mode: LaunchMode.externalApplication), ctx),
        ],
        item(Icons.person_outline, l.recentOpen, () => widget.onOpenContact(s.contact.id), ctx),
        item(Icons.visibility_off_outlined, l.recentRemove, () async {
          final hidden = await _hidden()
            ..add(s.contact.id);
          await c.database?.putSetting(_hiddenKey, hidden.join(','));
          await reload();
        }, ctx),
      ]),
    );
  }

  // ---- sections ----

  Widget _quickActions(AppLocalizations l) {
    final c = widget.controller;
    final p = context.palette;
    Widget card(IconData icon, String label, VoidCallback? onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GlassCard(
              padding: EdgeInsets.zero,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Column(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(14)),
                        child: Icon(icon, size: 22, color: p.onPrimaryContainer),
                      ),
                      const SizedBox(height: 6),
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
    return Row(children: [
      card(Icons.group_add_outlined, l.newContact, widget.onNewContact),
      card(Icons.edit_outlined, l.logActivity, c.activities == null || c.contacts == null
          ? null
          : () async {
              await Navigator.of(context).push<int>(MaterialPageRoute(
                builder: (_) => LogActivityPage(activities: c.activities!, contacts: c.contacts!, schedule: c.schedule),
              ));
              await reload();
            }),
      card(Icons.qr_code_scanner, l.scanQr, c.contacts == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ScanPage(repo: c.contacts!)))),
      card(Icons.task_alt_outlined, l.qaTask, c.schedule == null || c.contacts == null
          ? null
          : () => showAddSheet(context, schedule: c.schedule!, contacts: c.contacts!)),
    ]);
  }

  Widget _stateCard({required Widget icon, required String title, required String body, required List<Widget> buttons}) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(children: [
          icon,
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.4, color: p.text2)),
          const SizedBox(height: 16),
          ...buttons,
        ]),
      ),
    );
  }

  Widget _overdueBlock(AppLocalizations l) {
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title(
        l.sectionOverdue,
        icon: Icons.warning_amber_rounded,
        color: p.error,
        badge: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: p.error, borderRadius: BorderRadius.circular(10)),
          child: Text('${_overdue.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onError)),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: p.errorContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.error.withValues(alpha: .35)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          for (var k = 0; k < _overdue.take(5).length; k++) ...[
            if (k > 0) const SizedBox(height: 14),
            InkWell(
              onTap: () => _openItem(_overdue[k]),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_overdue[k].title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.onErrorContainer)),
                  Text(
                    [if (_overdue[k].contactLabel != null) _overdue[k].contactLabel!, _since(_overdue[k])].join(' · '),
                    style: TextStyle(fontSize: 13, color: p.onErrorContainer.withValues(alpha: .85)),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              _btn(l.done, () => _toggle(_overdue[k]), filled: true, color: p.error, icon: Icons.check),
              const SizedBox(width: 8),
              _btn(l.snooze, () => _snooze(_overdue[k]), color: p.error),
            ]),
          ],
        ]),
      ),
    ]);
  }

  Widget _endedCard(ScheduleItem i, AppLocalizations l) {
    final p = context.palette;
    final s = widget.controller.schedule!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.glass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.primary, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.groups_outlined, size: 16, color: p.primary),
            const SizedBox(width: 6),
            Text(l.didHappenTitle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6, color: p.primary)),
          ]),
          const SizedBox(height: 6),
          Text(
            [i.title, formatClock(context, i.at), if (i.contactLabel != null) i.contactLabel!].join(' · '),
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _btn(l.didHappenYes, () async {
              await s.setMeetingStatus(i.id, 'held');
              await reload();
            }, filled: true),
            _btn(l.didHappenReschedule, () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => MeetingFormPage(schedule: s, contacts: widget.controller.contacts!, id: i.id),
              ));
              await reload();
            }),
            _btn(l.cancel, () async {
              await s.setMeetingStatus(i.id, 'cancelled');
              await reload();
            }),
          ]),
        ]),
      ),
    );
  }

  Widget _attentionRow(ContactSummary s, AppLocalizations l) {
    final p = context.palette;
    final r = ratingFromName(s.contact.rating);
    final last = s.contact.lastActivityAt ?? s.contact.createdAt;
    final days = DateTime.now().difference(last).inDays;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => widget.onOpenContact(s.contact.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            ContactAvatar(summary: s),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (s.contact.company.trim().isNotEmpty && s.contact.company != s.displayName)
                  Text(s.contact.company, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.text2)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (r != Rating.none) TagPill(ratingLabel(l, r), icon: ratingIcon(r), bg: ratingBg(p, r), fg: ratingFg(p, r)),
              const SizedBox(height: 4),
              Text(l.homeDaysShort(days), style: TextStyle(fontSize: 12, color: p.text2)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _recentStrip() {
    final p = context.palette;
    return SizedBox(
      height: 84,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final s in _recent)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => widget.onOpenContact(s.contact.id),
              onLongPress: () => _recentMenu(s),
              child: SizedBox(
                width: 56,
                child: Column(children: [
                  ContactAvatar(summary: s, size: 52, showBadges: false),
                  const SizedBox(height: 6),
                  Text(s.displayName.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.text2)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _pipelineCard(AppLocalizations l) {
    final p = context.palette;
    final totals = <String, double>{};
    for (final st in _pipeline) {
      st.totals.forEach((k, v) => totals[k] = (totals[k] ?? 0) + v);
    }
    final total = _pipeline.fold<int>(0, (a, b) => a + b.count);
    return GlassCard(
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Row(children: [
            for (var k = 0; k < _pipeline.length; k++)
              if (_pipeline[k].count > 0)
                Expanded(
                  flex: _pipeline[k].count,
                  child: Container(height: 10, margin: EdgeInsetsDirectional.only(end: k == _pipeline.length - 1 ? 0 : 3), color: p.leaves[k % p.leaves.length]),
                ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          for (final st in _pipeline)
            Expanded(
              child: Column(children: [
                Text('${st.count}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(stageLabel(l, st.stage), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.text2)),
              ]),
            ),
        ]),
        if (total > 0 && totals.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            for (final e in totals.entries)
              Expanded(
                child: Container(
                  margin: const EdgeInsetsDirectional.only(end: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(border: Border.all(color: p.glassBorder), borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.homeOpenValue, style: TextStyle(fontSize: 11, color: p.text2)),
                    Text(formatMoney(context, e.value, e.key), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
          ]),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final c = widget.controller;
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? l.greetMorning : (hour < 18 ? l.greetAfternoon : l.greetEvening);
    final greeting = _name.isEmpty ? greet : l.homeGreetingName(greet, _name);
    final clear = _overdue.isEmpty && _today.isEmpty && _ended.isEmpty;
    final emptyApp = _loaded && _contactTotal == 0;
    final summary = !_loaded
        ? ''
        : (_overdue.isNotEmpty
            ? l.homeSummaryBoth(_overdue.length, _today.length)
            : (_today.isNotEmpty ? l.homeSummaryToday(_today.length) : formatDay(context, DateTime.now())));
    return Column(children: [
      HeaderBand(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const LeafLogo(size: 46),
            const SizedBox(width: 12),
            Text('YONCA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 4, color: pal.onHeader)),
            const Spacer(),
            GlassIconButton(
              icon: Icons.search,
              onHeader: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SearchPage(controller: c))),
            ),
            const SizedBox(width: 8),
            BellButton(controller: c),
          ]),
          const SizedBox(height: 16),
          Text(greeting, style: TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w700, color: pal.onHeader)),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (_overdue.isNotEmpty) ...[Icon(Icons.warning_amber_rounded, size: 18, color: pal.onHeader.withValues(alpha: .9)), const SizedBox(width: 6)],
              Text(summary, style: TextStyle(fontSize: 14, color: pal.onHeader.withValues(alpha: .9))),
            ]),
          ],
        ]),
      ),
      Expanded(
        child: !_loaded
            ? const SizedBox.shrink()
            : ListView(padding: const EdgeInsets.fromLTRB(12, 16, 12, 120), children: [
                _quickActions(l),
                if (emptyApp)
                  _stateCard(
                    icon: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(color: pal.primaryContainer, borderRadius: BorderRadius.circular(22)),
                      child: const Center(child: LeafLogo(size: 38)),
                    ),
                    title: l.homeEmptyTitle,
                    body: l.homeEmptyBody,
                    buttons: [
                      PillButton(label: l.homeAddFirst, height: 50, onPressed: widget.onNewContact),
                      const SizedBox(height: 8),
                      if (c.contacts != null)
                        PillButton(
                          label: l.homeImportContacts,
                          outlined: true,
                          height: 50,
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ImportPage(repo: c.contacts!))),
                        ),
                    ],
                  )
                else if (clear)
                  _stateCard(
                    icon: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: pal.primaryContainer, borderRadius: BorderRadius.circular(18)),
                      child: Icon(Icons.check, size: 28, color: pal.onPrimaryContainer),
                    ),
                    title: l.homeCaughtTitle,
                    body: l.homeCaughtBody,
                    buttons: [
                      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                        _btn(l.homePlan, () {
                          if (c.schedule != null && c.contacts != null) showAddSheet(context, schedule: c.schedule!, contacts: c.contacts!);
                        }, color: pal.text),
                        _btn(l.homeCallSomeone, () => widget.onGoTab(1), color: pal.text),
                      ]),
                    ],
                  ),
                if (_overdue.isNotEmpty) _overdueBlock(l),
                if (_today.isNotEmpty || _ended.isNotEmpty) ...[
                  _title(l.sectionToday, trailing: l.homeItemsCount(_today.length)),
                  for (final i in _ended) _endedCard(i, l),
                  if (_today.isNotEmpty) _group([for (final i in _today) _row(i)]),
                ],
                if (_soon.isNotEmpty) ...[
                  _title(l.sectionUpcoming, trailing: l.viewAllLink, onTap: () => widget.onGoTab(2)),
                  _group([for (final i in _soon.take(3)) _row(i, date: true)]),
                ],
                if (_toComplete.isNotEmpty) ...[
                  _title(l.homeToComplete, trailing: l.contactsCount(_toComplete.length)),
                  _group([
                    for (final s in _toComplete)
                      Material(
                        type: MaterialType.transparency,
                        child: ContactRow(summary: s, onTap: () => widget.onOpenContact(s.contact.id)),
                      ),
                  ]),
                ],
                if (_attention.isNotEmpty) ...[
                  _title(l.sectionNeedsAttention, trailing: l.viewAllLink, onTap: () => widget.onGoTab(1)),
                  _group([for (final s in _attention) _attentionRow(s, l)]),
                ],
                if (_recent.isNotEmpty) ...[
                  _title(l.sectionRecentContacts),
                  _recentStrip(),
                ],
                if (c.deals != null && _pipeline.any((p) => p.count > 0)) ...[
                  _title(l.sectionPipeline, trailing: l.homeOpenDeals, onTap: () => widget.onGoTab(3)),
                  _pipelineCard(l),
                ],
                if (_targets.isNotEmpty) ...[
                  _title(l.targetsTitle, trailing: l.homeOpenStats, onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StatsPage(controller: c)))),
                  GlassCard(child: Column(children: [for (final t in _targets) TargetBar(target: t.$1, value: t.$2, end: t.$3)])),
                ],
                if (_activity.isNotEmpty) ...[
                  _title(l.sectionRecentActivity),
                  for (final a in _activity.take(8))
                    ActivityCard(
                      item: a,
                      onTap: () async {
                        await showActivitySheet(context, item: a, activities: c.activities!, contacts: c.contacts!);
                        await reload();
                      },
                    ),
                  const SizedBox(height: 8),
                  PillButton(
                    label: l.homeViewMore,
                    outlined: true,
                    height: 48,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => TimelinePage(activities: c.activities!, contacts: c.contacts!),
                    )),
                  ),
                ],
              ]),
      ),
    ]);
  }
}
