import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/app_controller.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/domain/contact_models.dart';
import 'package:yonca/domain/stats_models.dart';

/// Times the work the app does on start and on every change with a big contact book.
/// The numbers are printed as TIMING lines (CI shows them); the asserts only catch runaway cases.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a contact book of 3,000 stays quick', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = AppController(database: db);
    final repo = c.contacts!;
    final sw = Stopwatch();

    Future<T> time<T>(String name, Future<T> Function() f) async {
      sw
        ..reset()
        ..start();
      final r = await f();
      // ignore: avoid_print
      print('TIMING $name ${sw.elapsedMilliseconds} ms');
      return r;
    }

    // Changes while a list is watching: how many reloads happen and how long until things go quiet.
    var emissions = 0;
    final sub = repo.watchList().listen((_) => emissions++);
    await time('add 3000 contacts', () => repo.addTestContacts(3000));
    await time('drain watchers', () async {
      var last = -1;
      while (last != emissions) {
        last = emissions;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    });
    // ignore: avoid_print
    print('TIMING watchList emissions $emissions');
    await sub.cancel();

    await c.stats!.setTarget(Metric.newContacts, StatsPeriod.week, 10);
    await c.stats!.setTarget(Metric.calls, StatsPeriod.month, 10);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    await time('contacts.list()', () => repo.list());
    await time('contacts.list(sort name)', () => repo.list(sort: ContactSort.name));
    await time('contacts.get(id)', () => repo.get(1500));
    await time('schedule.overdueTasks', () => c.schedule!.overdueTasks());
    await time('schedule.itemsBetween x2', () async {
      await c.schedule!.itemsBetween(start, start.add(const Duration(days: 4)), includeDone: false);
      await c.schedule!.itemsBetween(start.subtract(const Duration(days: 3)), now, includeDone: false);
    });
    await time('deals.summaries', () => c.deals!.summaries());
    await time('activities.list(8)', () => c.activities!.list(limit: 8));
    await time('stats.progress', () => c.stats!.progress());
    await time('schedule.pendingReminders', () => c.schedule!.pendingReminders(now));
    await time('home reload total (as the app does it)', () async {
      await c.schedule!.overdueTasks();
      await c.schedule!.itemsBetween(start, start.add(const Duration(days: 4)), includeDone: false);
      await c.schedule!.itemsBetween(start.subtract(const Duration(days: 3)), now, includeDone: false);
      await repo.list(inactiveForDays: 7, sort: ContactSort.needsAttention);
      await repo.list(sort: ContactSort.recentActivity);
      await c.deals!.summaries();
      await c.activities!.list(limit: 8);
      await c.stats!.progress();
    });
    final fast = await time('duplicatePairs (new)', () => repo.duplicatePairs());
    final slow = await time('duplicatePairs (old way, every pair)', () async {
      final all = await repo.list();
      String norm(String s) => s.trim().toLowerCase().replaceAll('.', '');
      var found = 0;
      for (var i = 0; i < all.length; i++) {
        for (var j = i + 1; j < all.length; j++) {
          final a = all[i], b = all[j];
          final pa = {for (final p in a.phones) if (p.normalized.isNotEmpty) p.normalized};
          if (b.phones.any((p) => pa.contains(p.normalized))) {
            found++;
          } else {
            final ea = {for (final e in a.emails) e.value.trim().toLowerCase()}..remove('');
            if (b.emails.any((e) => ea.contains(e.value.trim().toLowerCase()))) {
              found++;
            } else if (norm(contactDisplayName(a.contact)) == norm(contactDisplayName(b.contact))) {
              found++;
            }
          }
        }
      }
      return found;
    });
    // ignore: avoid_print
    print('TIMING duplicates found: new ${fast.length}, old-way exact matches $slow');
    await time('remove test contacts', () => repo.removeTestContacts());
    expect(emissions, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
