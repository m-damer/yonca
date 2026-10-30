import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/app_controller.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/domain/activity_models.dart';
import 'package:yonca/domain/contact_models.dart';
import 'package:yonca/main.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump();
  }

  Future<AppController> seeded(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = AppController(database: db);
    await tester.runAsync(() async {
      await c.contacts!.save(const ContactInput(firstName: 'Sara', lastName: 'Hot', phones: [PhoneInput(number: '944123456')]));
    });
    return c;
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('logging a call from a contact needs an outcome, then shows on its Timeline', (tester) async {
    final c = await seeded(tester);
    await tester.pumpWidget(YoncaApp(controller: c));
    await tester.pump();
    await tester.tap(find.text('Contacts').first);
    await tester.pump();
    await settle(tester);
    await tester.tap(find.text('Sara Hot'));
    await tester.pumpAndSettle();
    expect(find.text('No activity yet. Log a call or add a note.'), findsOneWidget);
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log activity'));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Sara Hot'), findsWidgets);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Choose an outcome.'), findsOneWidget);
    await tester.tap(find.text('Interested'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Set a follow-up task?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.text('Activity saved'), findsOneWidget);
    expect(find.text('Call · Interested'), findsOneWidget);
    await end(tester);
  });

  testWidgets('global Timeline lists activities and filters by type', (tester) async {
    final c = await seeded(tester);
    await tester.runAsync(() async {
      final cid = (await c.contacts!.list()).first.contact.id;
      final o = (await c.activities!.outcomes()).first.id;
      await c.activities!.save(ActivityInput(
          type: ActivityType.call, contactId: cid, occurredAt: DateTime.now(), direction: 'in', outcomeId: o));
      await c.activities!.save(ActivityInput(type: ActivityType.note, title: 'Idea for the expo', occurredAt: DateTime.now()));
    });
    await tester.pumpWidget(YoncaApp(controller: c));
    await tester.pump();
    await tester.tap(find.text('More').first);
    await tester.pump();
    await tester.tap(find.text('Timeline'));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.text('Call · Interested'), findsOneWidget);
    expect(find.text('Note · Idea for the expo'), findsOneWidget);
    expect(find.text('General note'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await settle(tester);
    await tester.tap(find.textContaining('Show '));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.text('Call · Incoming'), findsNothing);
    expect(find.text('Note · Idea for the expo'), findsOneWidget);
    await end(tester);
  });

  testWidgets('Outcome list shows the defaults and adds a new outcome', (tester) async {
    final c = await seeded(tester);
    await tester.pumpWidget(YoncaApp(controller: c));
    await tester.pump();
    await tester.tap(find.text('More').first);
    await tester.pump();
    await tester.tap(find.text('Outcome list'));
    await tester.pumpAndSettle();
    await settle(tester);
    for (final n in ['Interested', 'Needs time', 'Not interested', 'No answer']) {
      expect(find.text(n), findsOneWidget);
    }
    await tester.tap(find.text('New outcome'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Send quote');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Send quote'), findsOneWidget);
    await end(tester);
  });
}
