import 'dart:io' show Platform;

import 'package:home_widget/home_widget.dart';

import '../l10n/app_localizations.dart';

/// Hands the incoming-call card what it needs from the app: the on/off switch, the language and every
/// text it draws. The card is drawn by Android code that runs without the app, so it reads these from
/// the shared preferences the home-screen widget already uses.
Future<void> syncCallCard(AppLocalizations l, {required bool enabled, required bool rtl, required String lang}) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return;
  try {
    Future<void> put<T>(String k, T v) => HomeWidget.saveWidgetData<T>(k, v);
    await put('cc_enabled', enabled);
    await put('cc_rtl', rtl);
    await put('cc_lang', lang);
    await put('cc_last_action', l.callCardLastAction);
    await put('cc_open_deal', l.callCardOpenDeal);
    // The number is a marker the card swaps for the real count.
    await put('cc_more_deals', l.callCardMoreDeals(7777).replaceAll('7777', '{n}'));
    await put('cc_t_call', l.typeCall);
    await put('cc_t_visit', l.typeVisit);
    await put('cc_t_message', l.typeMessage);
    await put('cc_t_note', l.typeNote);
    await put('cc_o_interested', l.outcomeInterested);
    await put('cc_o_needsTime', l.outcomeNeedsTime);
    await put('cc_o_notInterested', l.outcomeNotInterested);
    await put('cc_o_noAnswer', l.outcomeNoAnswer);
    await put('cc_st_lead', l.stageLead);
    await put('cc_st_contacted', l.stageContacted);
    await put('cc_st_quote', l.stageQuote);
    await put('cc_st_talks', l.stageTalks);
    await put('cc_ago_today', l.callCardAgoToday);
    await put('cc_ago_yesterday', l.callCardAgoYesterday);
    // Plural forms differ by count (Arabic has six), so every count the card can show is written out.
    for (var n = 2; n <= 13; n++) {
      await put('cc_ago_d_$n', l.callCardAgoDays(n));
    }
    for (var n = 2; n <= 8; n++) {
      await put('cc_ago_w_$n', l.callCardAgoWeeks(n));
    }
    for (var n = 2; n <= 24; n++) {
      await put('cc_ago_m_$n', l.callCardAgoMonths(n));
    }
    for (var n = 2; n <= 60; n++) {
      await put('cc_ago_y_$n', l.callCardAgoYears(n));
    }
  } catch (_) {
    // No shared preferences on this platform (tests, desktop).
  }
}
