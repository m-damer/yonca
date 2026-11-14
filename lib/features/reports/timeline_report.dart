import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/format.dart';
import '../../data/app_database.dart' show DealStage;
import '../../data/timeline_builder.dart';
import '../../domain/contact_models.dart';
import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../activities/activity_labels.dart';
import '../contacts/contact_widgets.dart';
import '../deals/deal_widgets.dart';
import '../schedule/schedule_labels.dart';

/// Width the timeline is drawn at before it is scaled onto an A4 page (about 9 pt text on paper).
const double timelineDrawWidth = 700;

/// What one timeline entry says, in the report's language.
class TlText {
  const TlText(this.kind, this.head, this.lines);
  final String kind;
  final String head;
  final List<String> lines;
}

String _clock(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

String _stage(AppLocalizations l, DealStage? s) => s == null ? '' : stageLabel(l, s);

TlText describeEntry(AppLocalizations l, String locale, TlEntry e) {
  String day(DateTime d) => dfmt(DateFormat.yMMMd(locale), d);
  String money(double a, String c) => formatMoneyAt(locale, a, c);
  final lines = <String>[];
  void add(String t) {
    if (t.trim().isNotEmpty) lines.add(t.trim());
  }

  String fileName(TlFile f) => f.pages > 1 ? l.tlFilePages(f.name, f.pages) : f.name;

  void filesLine() {
    if (e.files.isEmpty) return;
    add(l.tlFiles(e.files.map(fileName).join(', ')));
    final left = e.files.fold<int>(0, (a, f) => a + f.skipped);
    if (left > 0) add(l.tlMorePages(left));
  }

  void voiceAndFiles() {
    if (e.hasVoice) add(l.tlVoice(e.voiceMs > 0 ? _clock(e.voiceMs) : l.voiceNote));
    filesLine();
  }

  switch (e.kind) {
    case TlKind.added:
      return TlText(l.sysContactAddedLabel, '', const []);
    case TlKind.call:
      add(e.text);
      add(e.place);
      voiceAndFiles();
      return TlText(
        l.typeCall,
        [
          if (directionLabel(l, e.direction).isNotEmpty) directionLabel(l, e.direction),
          if (e.minutes != null && e.minutes! > 0) l.callLogMin(e.minutes!),
          if (e.outcome != null) outcomeLabel(l, e.outcome!),
        ].join(' · '),
        lines,
      );
    case TlKind.visit:
      add(e.text);
      voiceAndFiles();
      return TlText(
        l.typeVisit,
        [if (e.place.isNotEmpty) e.place, if (e.outcome != null) outcomeLabel(l, e.outcome!)].join(' · '),
        lines,
      );
    case TlKind.message:
      add(e.text);
      voiceAndFiles();
      return TlText(
        l.typeMessage,
        [if (e.channel.isNotEmpty) channelLabel(l, e.channel), if (directionLabel(l, e.direction).isNotEmpty) directionLabel(l, e.direction)].join(' · '),
        lines,
      );
    case TlKind.note:
      add(e.text);
      voiceAndFiles();
      return TlText(l.typeNote, e.title, lines);
    case TlKind.task:
      final p = Priority.values.firstWhere((x) => x.name == e.priority, orElse: () => Priority.normal);
      add(e.done
          ? l.tlDoneAt(e.doneAt == null ? '' : day(e.doneAt!))
          : '${l.tlOpen} · ${l.tlDue(day(e.at) + (e.hasTime ? ' ${dfmt(DateFormat.Hm(locale), e.at)}' : ''))}');
      if (p != Priority.normal) add(priorityLabel(l, p));
      add(e.text);
      voiceAndFiles();
      return TlText(l.tlTask, e.title, lines);
    case TlKind.meeting:
      final t = MeetingType.values.firstWhere((x) => x.name == e.meetingType, orElse: () => MeetingType.inPerson);
      add([
        meetingTypeLabel(l, t),
        switch (e.status) {
          'held' => l.tlHeld,
          'cancelled' => l.meetingCancelled,
          _ => l.tlScheduled,
        },
        if (e.minutes != null) l.callLogMin(e.minutes!),
      ].join(' · '));
      add(e.place);
      add(e.link);
      add(e.text);
      return TlText(l.tlMeeting, e.title, lines);
    case TlKind.dealCreated:
      if (e.amount != null) add(money(e.amount!, e.currency));
      add(e.text);
      return TlText(l.sysDealCreatedLabel, e.title, lines);
    case TlKind.dealMoved:
      add(l.dealMoved(_stage(l, e.fromStage), _stage(l, e.stage)));
      return TlText(l.sysDealMovedLabel, e.title, lines);
    case TlKind.dealWon:
      if (e.amount != null) add(money(e.amount!, e.currency));
      return TlText(l.sysDealWonLabel, e.title, lines);
    case TlKind.dealLost:
      if (e.reason.isNotEmpty) add(l.tlReason(lostReasonLabel(l, e.reason)));
      add(e.text);
      return TlText(l.sysDealLostLabel, e.title, lines);
    case TlKind.document:
      add(e.dealTitle);
      if (e.amount != null) add(money(e.amount!, e.currency));
      filesLine();
      return TlText(l.tlDoc, e.title, lines);
  }
}

/// The "who is this" part: roles, phones, emails, addresses, tags, requirements, dates and custom fields.
List<String> contactDetailLines(AppLocalizations l, String locale, ContactTimeline t) {
  final s = t.summary;
  final c = s.contact;
  final out = <String>[];
  void add(String v) {
    if (v.trim().isNotEmpty) out.add(v.trim());
  }

  if (c.company.isNotEmpty && c.company != s.displayName) add(c.company);
  if (c.jobTitle.isNotEmpty) add(c.jobTitle);
  add([s.roles.map((r) => roleLabel(l, r)).join(', '), ratingLabel(l, ratingFromName(c.rating))].where((x) => x.isNotEmpty).join(' · '));
  for (final p in s.phones) {
    add(p.number);
  }
  for (final e in s.emails) {
    add(e.value);
  }
  for (final a in s.addresses) {
    add(a.value);
  }
  for (final w in s.websites) {
    add(w.value);
  }
  if (s.tags.isNotEmpty) add('${l.tlTags}: ${s.tags.map((x) => x.name).join(', ')}');
  for (final ev in s.events) {
    add('${ev.title}: ${dfmt(DateFormat.yMMMd(locale), ev.date)}${ev.yearly ? ' (${l.tlYearly})' : ''}');
  }
  if (c.requirements.isNotEmpty) add('${l.fieldRequirements}: ${c.requirements}');
  for (final f in t.fieldValues) {
    add('${f.$1}: ${f.$3 ? (f.$2 == '1' ? '✓' : '✗') : f.$2}');
  }
  add(l.tlAddedOn(dfmt(DateFormat.yMMMd(locale), c.createdAt)));
  return out;
}

/// The title block of one contact in the PDF.
class TimelineHeader extends StatelessWidget {
  const TimelineHeader({super.key, required this.timeline, this.title, this.owner = ''});
  final ContactTimeline timeline;
  final String? title;
  final String owner;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final s = timeline.summary;
    return Container(
      width: double.infinity,
      color: PrintInk.paper,
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.sm),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: PrintInk.ink),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[
            Text(owner.isEmpty ? l.appName : '$owner · ${l.appName}', style: const TextStyle(fontSize: AppFont.tiny, height: AppLine.normal, color: PrintInk.soft)),
            if (title!.isNotEmpty) Text(title!, style: const TextStyle(fontSize: AppFont.body, height: AppLine.snug, fontWeight: AppWeight.semibold)),
            const SizedBox(height: AppSpace.lg),
          ],
          Text(s.fullName, style: const TextStyle(fontSize: AppFont.title, height: AppLine.snug, fontWeight: AppWeight.semibold)),
          const SizedBox(height: AppSpace.xs),
          for (final line in contactDetailLines(l, locale, timeline))
            Padding(padding: const EdgeInsets.only(top: AppSpace.xs), child: Text(line, style: const TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: PrintInk.soft))),
          const SizedBox(height: AppSpace.md),
          const Divider(height: AppStroke.hairline, thickness: AppStroke.hairline, color: PrintInk.divider),
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Text(
              timeline.entries.isEmpty ? l.tlEmpty : l.tlCount(timeline.entries.length),
              style: const TextStyle(fontSize: AppFont.meta, height: AppLine.normal, fontWeight: AppWeight.semibold),
            ),
          ),
        ]),
      ),
    );
  }
}

/// One timeline entry: date and time on the start side, then what happened.
class TimelineRow extends StatelessWidget {
  const TimelineRow({super.key, required this.entry});
  final TlEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final t = describeEntry(l, locale, entry);
    return Container(
      width: double.infinity,
      color: PrintInk.paper,
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: PrintInk.ink),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: AppSize.s110,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dfmt(DateFormat.yMMMd(locale), entry.at), style: const TextStyle(fontSize: AppFont.meta, height: AppLine.normal, fontWeight: AppWeight.semibold)),
                if (entry.hasTime) Text(dfmt(DateFormat.Hm(locale), entry.at), style: const TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: PrintInk.soft)),
              ]),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.kind, style: const TextStyle(fontSize: AppFont.tiny, height: AppLine.normal, fontWeight: AppWeight.semibold, color: PrintInk.soft)),
                if (t.head.isNotEmpty) Text(t.head, style: const TextStyle(fontSize: AppFont.body, height: AppLine.snug, fontWeight: AppWeight.semibold)),
                for (final line in t.lines) Padding(padding: const EdgeInsets.only(top: AppSpace.xs), child: Text(line, style: const TextStyle(fontSize: AppFont.meta, height: AppLine.normal))),
              ]),
                    ),
              ]),
            ),
          ]),
          const SizedBox(height: AppSpace.sm),
          const Divider(height: AppStroke.hairline, thickness: AppStroke.hairline, color: PrintInk.divider),
        ]),
      ),
    );
  }
}

/// One row per contact detail block and per entry, for Excel.
List<List<String>> timelineCsv(AppLocalizations l, String locale, List<ContactTimeline> timelines) {
  final rows = <List<String>>[
    [l.colName, l.colCompany, l.tlColDate, l.tlColTime, l.tlColType, l.tlColTitle, l.tlColDetails],
  ];
  for (final t in timelines) {
    final name = t.summary.fullName;
    final company = t.summary.contact.company;
    rows.add([name, company, '', '', l.tlSectionDetails, '', contactDetailLines(l, locale, t).join(' | ')]);
    for (final e in t.entries) {
      final d = describeEntry(l, locale, e);
      rows.add([
        name,
        company,
        dfmt(DateFormat('yyyy-MM-dd', locale), e.at),
        e.hasTime ? dfmt(DateFormat.Hm(locale), e.at) : '',
        d.kind,
        d.head,
        d.lines.join(' | '),
      ]);
    }
  }
  return rows;
}
