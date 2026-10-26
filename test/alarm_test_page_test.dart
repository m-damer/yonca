import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/app_controller.dart';
import 'package:yonca/main.dart';

void main() {
  testWidgets('More tab links to the temporary alarm test page', (tester) async {
    await tester.pumpWidget(YoncaApp(controller: AppController()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alarm test (temporary)'));
    await tester.pumpAndSettle();
    expect(find.text('Alarm clock in 2 min'), findsOneWidget);
    expect(find.text('Exact in 2 min'), findsOneWidget);
  });
}
