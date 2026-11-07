import 'dart:ui' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/l10n/app_localizations.dart';

void main() {
  test('Arabic minutes and seconds use the right plural form', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(ar.callLogMin(1), 'دقيقة واحدة');
    expect(ar.callLogMin(2), 'دقيقتان');
    expect(ar.callLogMin(3), '3 دقائق');
    expect(ar.callLogMin(10), '10 دقائق');
    expect(ar.callLogMin(11), '11 دقيقة');
    expect(ar.callLogMin(100), '100 دقيقة');
    expect(ar.callLogSec(1), 'ثانية واحدة');
    expect(ar.callLogSec(2), 'ثانيتان');
    expect(ar.callLogSec(5), '5 ثوانٍ');
    expect(ar.callLogSec(30), '30 ثانية');
    expect(ar.reminderMinBefore(5), 'قبل 5 دقائق');
    expect(ar.reminderMinBefore(15), 'قبل 15 دقيقة');
  });

  test('English minutes stay as they were', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.callLogMin(1), '1 min');
    expect(en.callLogMin(5), '5 min');
    expect(en.reminderMinBefore(15), '15 min before');
  });
}
