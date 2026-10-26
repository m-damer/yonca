import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../domain/contact_models.dart';
import '../domain/deal_models.dart';
import 'app_database.dart';

/// Deals, their stages, stage history and documents.
class DealsRepository {
  DealsRepository(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  /// Goes up after every change, so screens can reload.
  final ValueNotifier<int> revision = ValueNotifier(0);

  void _changed() => revision.value++;

  // ---- stages ----

  Future<void> _ensureStages() async {
    final n = await db.select(db.dealStages).get();
    if (n.isNotEmpty) return;
    var pos = 0;
    for (final k in defaultStageKeys) {
      await db.into(db.dealStages).insert(DealStagesCompanion.insert(key: Value(k), tint: Value(pos), position: Value(pos)));
      pos++;
    }
    await db.into(db.dealStages)
        .insert(DealStagesCompanion.insert(key: const Value('won'), kind: const Value('won'), tint: const Value(5), position: Value(pos++)));
    await db.into(db.dealStages)
        .insert(DealStagesCompanion.insert(key: const Value('lost'), kind: const Value('lost'), tint: const Value(6), position: Value(pos)));
  }

  /// All stages in order: open ones, then Won, then Lost.
  Future<List<DealStage>> stages() async {
    await _ensureStages();
    final all = await (db.select(db.dealStages)..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    int rank(DealStage s) => switch (stageKindFromName(s.kind)) { StageKind.open => 0, StageKind.won => 1, StageKind.lost => 2 };
    final list = [...all]..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.position.compareTo(b.position);
      });
    return list;
  }

  Future<List<DealStage>> openStages() async => [for (final s in await stages()) if (s.kind == 'open') s];

  Future<DealStage> stageOfKind(StageKind k) async => (await stages()).firstWhere((s) => stageKindFromName(s.kind) == k);

  Future<int> addStage(String name, int tint) async {
    final n = name.trim();
    if (n.isEmpty || n.length > 30) throw const DealValidationException('stage_name');
    final open = await openStages();
    if (open.length >= maxOpenStages) throw const DealValidationException('stage_max');
    final id = await db.into(db.dealStages).insert(DealStagesCompanion.insert(
          name: Value(n),
          tint: Value(tint % stageTintCount),
          position: Value(open.isEmpty ? 0 : open.last.position + 1),
        ));
    _changed();
    return id;
  }

  /// Renames a stage everywhere. A built-in stage becomes a custom one with the new name.
  Future<void> renameStage(int id, String name) async {
    final n = name.trim();
    if (n.isEmpty || n.length > 30) throw const DealValidationException('stage_name');
    final s = await (db.select(db.dealStages)..where((t) => t.id.equals(id))).getSingle();
    if (s.kind != 'open') throw const DealValidationException('stage_fixed');
    await (db.update(db.dealStages)..where((t) => t.id.equals(id))).write(DealStagesCompanion(name: Value(n), key: const Value(null)));
    _changed();
  }

  Future<void> setStageTint(int id, int tint) async {
    await (db.update(db.dealStages)..where((t) => t.id.equals(id))).write(DealStagesCompanion(tint: Value(tint % stageTintCount)));
    _changed();
  }

  /// Saves a new order for the open stages.
  Future<void> reorderOpenStages(List<int> ids) async {
    await db.transaction(() async {
      for (var i = 0; i < ids.length; i++) {
        await (db.update(db.dealStages)..where((t) => t.id.equals(ids[i]))).write(DealStagesCompanion(position: Value(i)));
      }
    });
    _changed();
  }

  /// Deletes an open stage. Its deals move to [moveTo] (required when it holds any).
  Future<void> removeStage(int id, {int? moveTo}) async {
    final s = await (db.select(db.dealStages)..where((t) => t.id.equals(id))).getSingle();
    if (s.kind != 'open') throw const DealValidationException('stage_fixed');
    final open = await openStages();
    if (open.length <= 1) throw const DealValidationException('stage_last');
    final held = await (db.select(db.deals)..where((t) => t.stageId.equals(id))).get();
    if (held.isNotEmpty) {
      if (moveTo == null || moveTo == id) throw const DealValidationException('stage_move');
      for (final d in held) {
        await moveDeal(d.id, moveTo);
      }
    }
    await (db.delete(db.dealStages)..where((t) => t.id.equals(id))).go();
    _changed();
  }

  /// Adds any default stage the user has deleted.
  Future<void> restoreDefaultStages() async {
    await _ensureStages();
    final open = await openStages();
    final have = open.map((s) => s.key).toSet();
    var pos = open.isEmpty ? 0 : open.last.position + 1;
    var i = 0;
    for (final k in defaultStageKeys) {
      if (!have.contains(k) && open.length + i < maxOpenStages) {
        await db.into(db.dealStages).insert(DealStagesCompanion.insert(key: Value(k), tint: Value(defaultStageKeys.indexOf(k)), position: Value(pos++)));
        i++;
      }
    }
    _changed();
  }

  // ---- deals ----

  Future<int> saveDeal(DealInput input, {int? id}) async {
    final problem = input.problem();
    if (problem != null) throw DealValidationException(problem);
    await _ensureStages();
    final now = _clock();
    final out = await db.transaction(() async {
      final fields = DealsCompanion(
        title: Value(input.title.trim()),
        contactId: Value(input.contactId!),
        amount: Value(input.amount),
        currency: Value(input.currency),
        expectedClose: Value(input.expectedClose),
        description: Value(input.description.trim()),
      );
      if (id == null) {
        final did = await db.into(db.deals).insert(fields.copyWith(
              stageId: Value(input.stageId),
              stageChangedAt: Value(now),
              createdAt: Value(now),
            ));
        await db.into(db.dealStageHistory)
            .insert(DealStageHistoryCompanion.insert(dealId: did, toStageId: input.stageId, at: now));
        return did;
      }
      await (db.update(db.deals)..where((t) => t.id.equals(id))).write(fields);
      final cur = await (db.select(db.deals)..where((t) => t.id.equals(id))).getSingle();
      final stage = await (db.select(db.dealStages)..where((t) => t.id.equals(cur.stageId))).getSingle();
      if (stage.kind == 'open' && cur.stageId != input.stageId) await moveDeal(id, input.stageId);
      return id;
    });
    _changed();
    return out;
  }

  Future<void> _history(int dealId, int? from, int to) => db.into(db.dealStageHistory)
      .insert(DealStageHistoryCompanion.insert(dealId: dealId, fromStageId: Value(from), toStageId: to, at: _clock()));

  /// Moves a deal to an open stage (also clears Won/Lost data, which makes this the reopen action).
  Future<void> moveDeal(int id, int stageId) async {
    final cur = await (db.select(db.deals)..where((t) => t.id.equals(id))).getSingle();
    final target = await (db.select(db.dealStages)..where((t) => t.id.equals(stageId))).getSingle();
    if (target.kind != 'open') throw const DealValidationException('stage_open');
    if (cur.stageId == stageId) return;
    await db.transaction(() async {
      await (db.update(db.deals)..where((t) => t.id.equals(id))).write(DealsCompanion(
        stageId: Value(stageId),
        stageChangedAt: Value(_clock()),
        closedAt: const Value(null),
        lostReason: const Value(''),
        lostNote: const Value(''),
      ));
      await _history(id, cur.stageId, stageId);
    });
    _changed();
  }

  /// Won: sets the final amount and date, and turns a Lead contact into a Client.
  Future<void> winDeal(int id, {double? finalAmount, DateTime? date}) async {
    final cur = await (db.select(db.deals)..where((t) => t.id.equals(id))).getSingle();
    final won = await stageOfKind(StageKind.won);
    await db.transaction(() async {
      await (db.update(db.deals)..where((t) => t.id.equals(id))).write(DealsCompanion(
        stageId: Value(won.id),
        amount: finalAmount != null ? Value(finalAmount) : const Value.absent(),
        closedAt: Value(date ?? _clock()),
        stageChangedAt: Value(_clock()),
        lostReason: const Value(''),
        lostNote: const Value(''),
      ));
      await _history(id, cur.stageId, won.id);
      final roles = await (db.select(db.contactRoles)..where((r) => r.contactId.equals(cur.contactId))).get();
      if (roles.any((r) => r.role == Role.lead.name)) {
        await (db.delete(db.contactRoles)..where((r) => r.contactId.equals(cur.contactId) & r.role.equals(Role.lead.name))).go();
        if (!roles.any((r) => r.role == Role.client.name)) {
          await db.into(db.contactRoles).insert(ContactRolesCompanion.insert(contactId: cur.contactId, role: Role.client.name));
        }
      }
    });
    _changed();
  }

  Future<void> loseDeal(int id, {required String reason, String note = '', DateTime? date}) async {
    final cur = await (db.select(db.deals)..where((t) => t.id.equals(id))).getSingle();
    final lost = await stageOfKind(StageKind.lost);
    await db.transaction(() async {
      await (db.update(db.deals)..where((t) => t.id.equals(id))).write(DealsCompanion(
        stageId: Value(lost.id),
        closedAt: Value(date ?? _clock()),
        stageChangedAt: Value(_clock()),
        lostReason: Value(reason),
        lostNote: Value(note.trim()),
      ));
      await _history(id, cur.stageId, lost.id);
    });
    _changed();
  }

  /// Deletes the deal; returns the document file paths so the caller can delete the files.
  Future<List<String>> deleteDeal(int id) async {
    final docs = await documents(id);
    await (db.delete(db.deals)..where((t) => t.id.equals(id))).go();
    _changed();
    return [for (final d in docs) if (d.path != null) d.path!];
  }

  Future<DealItem?> getDeal(int id) async {
    final list = await _items((q) => q.where(db.deals.id.equals(id)));
    return list.isEmpty ? null : list.first;
  }

  Future<List<DealItem>> _items(void Function(JoinedSelectStatement<HasResultSet, dynamic>) filter) async {
    final q = db.select(db.deals).join([
      innerJoin(db.dealStages, db.dealStages.id.equalsExp(db.deals.stageId)),
      innerJoin(db.contacts, db.contacts.id.equalsExp(db.deals.contactId)),
    ]);
    filter(q);
    final now = _clock();
    return [
      for (final r in await q.get())
        DealItem(
          deal: r.readTable(db.deals),
          stage: r.readTable(db.dealStages),
          contactName: contactDisplayName(r.readTable(db.contacts)),
          now: now,
        ),
    ];
  }

  /// Deals of one stage (or all), optionally of one contact; soonest expected close first, no date last.
  Future<List<DealItem>> listDeals({int? stageId, int? contactId, String query = ''}) async {
    final items = await _items((q) {
      if (stageId != null) q.where(db.deals.stageId.equals(stageId));
      if (contactId != null) q.where(db.deals.contactId.equals(contactId));
    });
    final qn = query.trim().toLowerCase();
    final out = [
      for (final i in items)
        if (qn.isEmpty || i.deal.title.toLowerCase().contains(qn) || i.contactName.toLowerCase().contains(qn)) i,
    ];
    out.sort((a, b) {
      final x = a.deal.expectedClose, y = b.deal.expectedClose;
      if (x == null && y == null) return b.deal.createdAt.compareTo(a.deal.createdAt);
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
    return out;
  }

  /// One summary per stage (in stage order), with totals per currency; deals without an amount add nothing.
  Future<List<StageSummary>> summaries() async {
    final list = await stages();
    final all = await db.select(db.deals).get();
    return [
      for (final s in list)
        () {
          final mine = all.where((d) => d.stageId == s.id).toList();
          final totals = <String, double>{};
          for (final d in mine) {
            if (d.amount != null) totals[d.currency] = (totals[d.currency] ?? 0) + d.amount!;
          }
          return StageSummary(stage: s, count: mine.length, totals: totals);
        }(),
    ];
  }

  Future<List<StageMove>> history(int dealId) async {
    final byId = {for (final s in await stages()) s.id: s};
    final rows = await (db.select(db.dealStageHistory)
          ..where((t) => t.dealId.equals(dealId))
          ..orderBy([(t) => OrderingTerm.desc(t.at), (t) => OrderingTerm.desc(t.id)]))
        .get();
    return [
      for (final r in rows)
        if (byId[r.toStageId] != null)
          StageMove(fromStage: r.fromStageId == null ? null : byId[r.fromStageId], toStage: byId[r.toStageId]!, at: r.at),
    ];
  }

  // ---- documents ----

  Future<List<DealDocument>> documents(int dealId) =>
      (db.select(db.dealDocuments)..where((t) => t.dealId.equals(dealId))..orderBy([(t) => OrderingTerm.desc(t.date)])).get();

  Future<int> saveDocument(int dealId,
      {int? id, String reference = '', double? amount, String currency = 'USD', required DateTime date, String? path, String name = ''}) async {
    final fields = DealDocumentsCompanion(
      dealId: Value(dealId),
      reference: Value(reference.trim()),
      amount: Value(amount),
      currency: Value(currency),
      date: Value(date),
      path: Value(path),
      name: Value(name),
    );
    final int out;
    if (id == null) {
      out = await db.into(db.dealDocuments).insert(fields);
    } else {
      await (db.update(db.dealDocuments)..where((t) => t.id.equals(id))).write(fields);
      out = id;
    }
    _changed();
    return out;
  }

  Future<String?> deleteDocument(int id) async {
    final d = await (db.select(db.dealDocuments)..where((t) => t.id.equals(id))).getSingleOrNull();
    await (db.delete(db.dealDocuments)..where((t) => t.id.equals(id))).go();
    _changed();
    return d?.path;
  }
}
