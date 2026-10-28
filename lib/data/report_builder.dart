import '../domain/contact_models.dart';
import '../domain/deal_models.dart';
import 'activities_repository.dart';
import 'contacts_repository.dart';
import 'deals_repository.dart';
import 'fields_repository.dart';
import '../domain/field_models.dart';

/// What a client report contains.
class ReportOptions {
  const ReportOptions({this.basics = true, this.requirements = true, this.history = true, this.deals = true, this.fields = true, this.performance = true, this.targets = false});
  final bool performance;
  final bool targets;
  final bool basics;
  final bool requirements;
  final bool history;
  final bool deals;
  final bool fields;

  ReportOptions copyWith({bool? basics, bool? requirements, bool? history, bool? deals, bool? fields, bool? performance, bool? targets}) => ReportOptions(
        performance: performance ?? this.performance,
        targets: targets ?? this.targets,
        basics: basics ?? this.basics,
        requirements: requirements ?? this.requirements,
        history: history ?? this.history,
        deals: deals ?? this.deals,
        fields: fields ?? this.fields,
      );
}

/// One client's data for a report.
class ReportClient {
  const ReportClient({
    required this.summary,
    this.calls = 0,
    this.visits = 0,
    this.messages = 0,
    this.notes = 0,
    this.lastActivity,
    this.openDeals = const [],
    this.fieldValues = const [],
  });
  final ContactSummary summary;
  final int calls;
  final int visits;
  final int messages;
  final int notes;
  final DateTime? lastActivity;
  final List<DealItem> openDeals;

  /// (field name, shown value) for fields that are marked "show in reports" and have a value.
  final List<(String, String)> fieldValues;
}

/// Collects the data of the chosen contacts for a report.
class ReportBuilder {
  ReportBuilder({required this.contacts, required this.activities, this.deals, this.fields});
  final ContactsRepository contacts;
  final ActivitiesRepository activities;
  final DealsRepository? deals;
  final FieldsRepository? fields;

  Future<List<ReportClient>> build(List<int> ids, ReportOptions options) async {
    final out = <ReportClient>[];
    final contactFields = options.fields && fields != null ? await fields!.fields(FieldScope.contact) : const [];
    for (final id in ids) {
      final s = await contacts.get(id);
      if (s == null) continue;
      var calls = 0, visits = 0, messages = 0, notes = 0;
      DateTime? last;
      if (options.history) {
        for (final a in await activities.list(contactId: id)) {
          switch (a.activity.type) {
            case 'call':
              calls++;
            case 'visit':
              visits++;
            case 'message':
              messages++;
            case 'note':
              notes++;
          }
          if (last == null || a.activity.occurredAt.isAfter(last)) last = a.activity.occurredAt;
        }
      }
      final openDeals = options.deals && deals != null ? [for (final d in await deals!.listDeals(contactId: id)) if (d.isOpen) d] : const <DealItem>[];
      final fv = <(String, String)>[];
      if (contactFields.isNotEmpty) {
        final vals = await fields!.values(FieldScope.contact, id);
        for (final f in contactFields) {
          final v = vals[f.id] ?? '';
          if (f.showInReports && v.isNotEmpty) fv.add((f.name, f.type == 'bool' ? (v == '1' ? '✓' : '✗') : v));
        }
      }
      out.add(ReportClient(
        summary: s,
        calls: calls,
        visits: visits,
        messages: messages,
        notes: notes,
        lastActivity: last,
        openDeals: openDeals,
        fieldValues: fv,
      ));
    }
    return out;
  }
}

/// RFC 4180 CSV with a leading BOM so Excel reads Arabic correctly.
String toCsv(List<List<String>> rows) {
  String cell(String v) => (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) ? '"${v.replaceAll('"', '""')}"' : v;
  return '﻿${rows.map((r) => r.map(cell).join(',')).join('\r\n')}\r\n';
}
