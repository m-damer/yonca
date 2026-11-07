import 'dart:io' show Platform;

import 'package:home_widget/home_widget.dart';

import '../l10n/app_localizations.dart';

/// Hands the incoming-call card what it needs from the app: the on/off switch, the language and every
/// text it draws. The card is drawn by Android code that runs without the app, so it reads these from
/// the shared preferences the home-screen widget already uses.
Future<void> syncCallCard(AppLocalizations l, {required bool enabled, required bool after, required bool rtl, required String lang, required String theme}) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return;
  try {
    Future<void> put<T>(String k, T v) => HomeWidget.saveWidgetData<T>(k, v);
    await put('cc_enabled', enabled);
    await put('cc_rtl', rtl);
    await put('cc_lang', lang);
    await put('cc_after', after);
    // system, light or dark: the card follows the app's own theme choice.
    await put('cc_theme', theme);
    await put('cc_channel', l.callLogChannel);
    await put('cc_log_title', l.callLogTitle('{name}'));
    await put('cc_unsaved_title', l.callLogUnsaved('{number}'));
    await put('cc_save_log', l.callLogSaveHint);
    await put('cc_save_log_btn', l.callLogSaveBtn);
    await put('cc_add_note', l.callLogAddNote);
    await put('cc_log_prompt', l.callLogPrompt);
    await put('cc_dir_in', l.callLogIncoming);
    await put('cc_dir_out', l.callLogOutgoing);
    await put('cc_dir_missed', l.callLogMissed);
    // One text per Arabic plural form (1, 2, 3-10, 11-99, 100+); the card picks by the count. The number is a marker.
    for (final (name, n, tag) in const [('one', 1, ''), ('two', 2, ''), ('few', 7, '7'), ('many', 77, '77'), ('other', 777, '777')]) {
      String form(String s) => tag.isEmpty ? s : s.replaceAll(tag, '{n}');
      await put('cc_dur_sec_$name', form(l.callLogSec(n)));
      await put('cc_dur_min_$name', form(l.callLogMin(n)));
    }
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
