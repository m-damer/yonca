import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/app_controller.dart';
import 'package:yonca/data/app_database.dart';
import 'package:yonca/domain/contact_models.dart';
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

  testWidgets('contacts tab lists saved contacts and filters by rating', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = AppController(database: db);
    await tester.runAsync(() async {
      await c.contacts!.save(const ContactInput(firstName: 'Sara', lastName: 'Hot', rating: Rating.hot));
      await c.contacts!.save(const ContactInput(firstName: 'Omar', lastName: 'Cold', rating: Rating.cold));
    });
    await tester.pumpWidget(YoncaApp(controller: c));
    await tester.pump();
    await tester.tap(find.text('Contacts').first);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.text('Sara Hot'), findsOneWidget);
    expect(find.text('Omar Cold'), findsOneWidget);
    await tester.tap(find.textContaining('Hot ').first);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.text('Omar Cold'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  });
}
