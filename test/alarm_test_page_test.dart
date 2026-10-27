import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/app_controller.dart';
import 'package:yonca/main.dart';

void main() {
  testWidgets('Settings, Notifications and alarms links to the alarm test page', (tester) async {
    await tester.pumpWidget(YoncaApp(controller: AppController()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications and alarms'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test alarm'));
    await tester.pumpAndSettle();
    expect(find.text('Alarm clock in 2 min'), findsOneWidget);
    expect(find.text('Exact in 2 min'), findsOneWidget);
  });
}
