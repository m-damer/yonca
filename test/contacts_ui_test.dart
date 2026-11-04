import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/app_controller.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/domain/contact_models.dart';
import 'package:yonca/features/contacts/contact_row.dart';
import 'package:yonca/features/contacts/quick_add_sheet.dart';
import 'package:yonca/main.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('splitName puts the last word in the last name', () {
    expect(splitName('Ali'), (first: 'Ali', last: ''));
    expect(splitName('  Ali  Hassan '), (first: 'Ali', last: 'Hassan'));
    expect(splitName('Mary Ann Smith'), (first: 'Mary Ann', last: 'Smith'));
    expect(splitName(''), (first: '', last: ''));
  });

  Future<AppController> seeded(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = AppController(database: db);
    await tester.runAsync(() async {
      await c.contacts!.save(const ContactInput(
          firstName: 'Sara', lastName: 'Hot', company: 'Hot Co', rating: Rating.hot, roles: [Role.client]));
      await c.contacts!.save(const ContactInput(firstName: 'Omar', lastName: 'Cold', rating: Rating.cold));
    });
    return c;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('contacts tab shows the design list and filters by rating', (tester) async {
    final c = await seeded(tester);
    await tester.pumpWidget(YoncaApp(controller: c));
    await tester.pump();
    await tester.tap(find.text('Contacts').first);
    await tester.pump();
    await settle(tester);
    expect(find.text('Sara Hot'), findsOneWidget);
    expect(find.text('Omar Cold'), findsOneWidget);
    expect(find.text('2 contacts · Recent activity'), findsOneWidget);
    expect(find.text('New contact'), findsOneWidget);
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hot').last);
    await tester.pump();
    await settle(tester);
    await tester.tap(find.textContaining('Show'));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.text('Omar Cold'), findsNothing);
    expect(find.text('Sara Hot'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a long contact list builds only the rows on screen and the letter rail still jumps', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = AppController(database: db);
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    await tester.runAsync(() async {
      for (var i = 0; i < 520; i++) {
        final l = letters[i % letters.length];
        await c.contacts!.save(ContactInput(firstName: 'Name', lastName: '${l}x$i'));
      }
    });
    await tester.pumpWidget(YoncaApp(controller: c));
    await tester.pump();
    await tester.tap(find.text('Contacts').first);
    await tester.pump();
    await settle(tester);
    final built = tester.widgetList(find.byType(ContactRow)).length;
    expect(built, greaterThan(5));
    expect(built, lessThan(80), reason: 'only the visible rows (plus a small margin) may be built');
    // Tapping a letter in the rail brings that letter to the top.
    await tester.tap(find.text('T').last);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Tx'), findsWidgets);
    expect(find.textContaining('Ax'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('quick add asks for a name or a phone number', (tester) async {
    final c = await seeded(tester);
    await tester.pumpWidget(YoncaApp(controller: c));
    await tester.pump();
    await tester.tap(find.text('Contacts').first);
    await tester.pump();
    await settle(tester);
    await tester.tap(find.text('New contact'));
    await tester.pumpAndSettle();
    expect(find.text('More details'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter a name, a company or a phone number.'), findsOneWidget);
    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();
    expect(find.text('New contact'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('details page shows the tabs and the Call action', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = AppController(database: db);
    await tester.runAsync(() async {
      await c.contacts!.save(const ContactInput(
        firstName: 'Sara',
        lastName: 'Hot',
        phones: [PhoneInput(number: '944123456')],
      ));
    });
    await tester.pumpWidget(YoncaApp(controller: c));
    await tester.pump();
    await tester.tap(find.text('Contacts').first);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.tap(find.text('Sara Hot'));
    await tester.pumpAndSettle();
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget); // a mobile number can open WhatsApp even when not marked
    for (final t in ['Timeline', 'Calendar', 'Deals', 'Files', 'Details']) {
      expect(find.text(t), findsWidgets);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
