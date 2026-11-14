import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../domain/activity_models.dart';
import '../domain/contact_models.dart';
import '../domain/field_models.dart';
import 'activities_repository.dart';
import 'app_database.dart';
import 'contacts_repository.dart';
import 'deals_repository.dart';
import 'fields_repository.dart';

/// A file attached to an entry. [png] is a picture of it (a photo, or the first page of a PDF) once the previews are loaded.
class TlFile {
  TlFile({required this.name, required this.path, this.isImage = false});
  final String name;
  final String path;
  final bool isImage;
  bool get isPdf => name.toLowerCase().endsWith('.pdf') || path.toLowerCase().endsWith('.pdf');

  /// Set by the preview loader; null for other file types or when it could not be drawn.
  Uint8List? png;
  int pages = 0;
}

enum TlKind { added, call, visit, message, note, task, meeting, dealCreated, dealMoved, dealWon, dealLost, document }

/// One line of a contact's full timeline, as plain data (the report turns it into words in its own language).
class TlEntry {
  const TlEntry({
    required this.kind,
    required this.at,
    this.hasTime = true,
    this.title = '',
    this.text = '',
    this.direction = '',
    this.channel = '',
    this.outcome,
    this.minutes,
    this.place = '',
    this.link = '',
    this.hasVoice = false,
    this.voiceMs = 0,
    this.files = const <TlFile>[],
    this.done = false,
    this.doneAt,
    this.priority = '',
    this.meetingType = '',
    this.status = '',
    this.stage,
    this.fromStage,
    this.amount,
    this.currency = '',
    this.reason = '',
    this.dealTitle = '',
  });
  final TlKind kind;
  final DateTime at;
  final bool hasTime;
  final String title;
  final String text;
  final String direction;
  final String channel;
  final Outcome? outcome;
  final int? minutes;
  final String place;
  final String link;
  final bool hasVoice;
  final int voiceMs;
  final List<TlFile> files;
  final bool done;
  final DateTime? doneAt;
  final String priority;
  final String meetingType;
  final String status;
  final DealStage? stage;
  final DealStage? fromStage;
  final double? amount;
  final String currency;
  final String reason;
  final String dealTitle;
}

/// Everything about one contact: who they are, and every interaction, newest first.
class ContactTimeline {
  const ContactTimeline({required this.summary, required this.fieldValues, required this.entries});
  final ContactSummary summary;

  /// (field name, shown value) for every custom field that has a value. A yes/no field shows 1 or 0 as `1` or `0`.
  final List<(String, String, bool)> fieldValues;
  final List<TlEntry> entries;
}

/// Collects the full timeline of the chosen contacts.
class TimelineBuilder {
  TimelineBuilder({required this.contacts, required this.activities, this.deals, this.fields});
  final ContactsRepository contacts;
  final ActivitiesRepository activities;
  final DealsRepository? deals;
  final FieldsRepository? fields;

  AppDatabase get _db => contacts.db;

  Future<List<ContactTimeline>> build(List<int> ids) async {
    final out = <ContactTimeline>[];
    final contactFields = fields == null ? const <CustomField>[] : await fields!.fields(FieldScope.contact);
    for (final id in ids) {
      final s = await contacts.get(id);
      if (s == null) continue;
      final entries = <TlEntry>[
        TlEntry(kind: TlKind.added, at: s.contact.createdAt),
      ];
      for (final a in await activities.list(contactId: id)) {
        final x = a.activity;
        entries.add(TlEntry(
          kind: switch (a.type) {
            ActivityType.call => TlKind.call,
            ActivityType.visit => TlKind.visit,
            ActivityType.message => TlKind.message,
            ActivityType.note => TlKind.note,
          },
          at: x.occurredAt,
          title: x.title,
          text: x.description,
          direction: x.direction,
          channel: x.channel,
          outcome: a.outcome,
          minutes: x.durationMinutes,
          place: x.place,
          link: x.mapLink,
          hasVoice: x.voicePath != null && x.voicePath!.isNotEmpty,
          voiceMs: x.voiceMs,
          files: [for (final f in a.files) TlFile(name: f.name, path: f.path, isImage: f.isImage)],
        ));
      }
      for (final t in await (_db.select(_db.tasks)..where((t) => t.contactId.equals(id))).get()) {
        final files = await (_db.select(_db.taskFiles)..where((f) => f.taskId.equals(t.id))).get();
        entries.add(TlEntry(
          kind: TlKind.task,
          at: t.dueAt,
          hasTime: t.hasTime,
          title: t.title,
          text: t.description,
          done: t.doneAt != null,
          doneAt: t.doneAt,
          priority: t.priority,
          files: [for (final f in files) TlFile(name: f.name, path: f.path, isImage: f.isImage)],
        ));
      }
      final q = _db.select(_db.meetings).join([
        innerJoin(_db.meetingContacts, _db.meetingContacts.meetingId.equalsExp(_db.meetings.id)),
      ])
        ..where(_db.meetingContacts.contactId.equals(id));
      for (final r in await q.get()) {
        final m = r.readTable(_db.meetings);
        entries.add(TlEntry(
          kind: TlKind.meeting,
          at: m.startAt,
          title: m.title,
          text: m.description,
          minutes: m.durationMinutes,
          meetingType: m.type,
          place: m.place,
          link: m.link,
          status: m.status,
        ));
      }
      final d = deals;
      if (d != null) {
        for (final item in await d.listDeals(contactId: id)) {
          final deal = item.deal;
          entries.add(TlEntry(kind: TlKind.dealCreated, at: deal.createdAt, title: deal.title, text: deal.description, amount: deal.amount, currency: deal.currency, stage: item.stage));
          for (final m in await d.history(deal.id)) {
            if (m.fromStage == null) continue;
            final k = switch (m.toStage.kind) {
              'won' => TlKind.dealWon,
              'lost' => TlKind.dealLost,
              _ => TlKind.dealMoved,
            };
            entries.add(TlEntry(
              kind: k,
              at: m.at,
              title: deal.title,
              stage: m.toStage,
              fromStage: m.fromStage,
              amount: deal.amount,
              currency: deal.currency,
              reason: k == TlKind.dealLost ? deal.lostReason : '',
              text: k == TlKind.dealLost ? deal.lostNote : '',
            ));
          }
          for (final doc in await d.documents(deal.id)) {
            entries.add(TlEntry(
              kind: TlKind.document,
              at: doc.date,
              hasTime: false,
              title: doc.reference.isNotEmpty ? doc.reference : doc.name,
              dealTitle: deal.title,
              amount: doc.amount,
              currency: doc.currency,
              files: doc.path == null || doc.path!.isEmpty ? const <TlFile>[] : [TlFile(name: doc.name.isEmpty ? doc.path!.split('/').last : doc.name, path: doc.path!)],
            ));
          }
        }
      }
      entries.sort((a, b) => b.at.compareTo(a.at));
      final fv = <(String, String, bool)>[];
      if (contactFields.isNotEmpty) {
        final vals = await fields!.values(FieldScope.contact, id);
        for (final f in contactFields) {
          final v = vals[f.id] ?? '';
          if (v.isNotEmpty) fv.add((f.name, v, f.type == 'bool'));
        }
      }
      out.add(ContactTimeline(summary: s, fieldValues: fv, entries: entries));
    }
    return out;
  }
}
