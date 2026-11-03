import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/app_controller.dart';
import 'package:yonca/domain/contact_models.dart';
import 'package:yonca/shared/glass_widgets.dart';
import 'package:yonca/theme/theme.dart';

void main() {
  test('saved Contacts sort and role tab come back; unknown values are ignored', () async {
    final c = AppController();
    expect(c.contactSort, isNull);
    expect(c.contactRole, isNull);
    await c.setPref(AppController.keyContactSort, ContactSort.name.name);
    await c.setPref(AppController.keyContactRole, Role.client.name);
    expect(c.contactSort, ContactSort.name);
    expect(c.contactRole, Role.client);
    await c.setPref(AppController.keyContactSort, 'nonsense');
    await c.setPref(AppController.keyContactRole, '');
    expect(c.contactSort, isNull);
    expect(c.contactRole, isNull);
  });

  testWidgets('SheetDialog turns Cancel / Confirm into two sheet buttons and returns the choice', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: buildYoncaTheme(Brightness.light),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showSheetDialog<bool>(
              context: context,
              builder: (ctx) => SheetDialog(
                title: const Text('Delete?'),
                content: const Text('This cannot be undone.'),
                actions: [
                  DialogCancel('Cancel', onPressed: () => Navigator.of(ctx).pop(false)),
                  DialogConfirm('Delete', danger: true, onPressed: () => Navigator.of(ctx).pop(true)),
                ],
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Delete?'), findsOneWidget);
    expect(find.byType(PillButton), findsNWidgets(2));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
