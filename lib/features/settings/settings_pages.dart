import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../diagnostics/alarm_test.dart';
import '../../domain/contact_models.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import '../deals/stages_page.dart';
import 'settings_widgets.dart';

String themeName(AppLocalizations l, ThemeMode m) => switch (m) {
      ThemeMode.system => l.themeSystem,
      ThemeMode.light => l.themeLight,
      ThemeMode.dark => l.themeDark,
    };

/// Appearance: light or dark, high contrast, Arabic font.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        Widget seg(ThemeMode m, IconData icon) {
          final on = c.themeMode == m;
          final dark = Theme.of(context).brightness == Brightness.dark;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => c.setThemeMode(m),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? (dark ? const Color(0xFF48484A) : p.surface) : null,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: on ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 2, offset: Offset(0, 1))] : null,
                ),
                child: Text(themeName(l, m), style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? p.text : p.text2)),
              ),
            ),
          );
        }

        return SettingsScaffold(title: l.hubAppearance, children: [
          SectionLabel(l.secLightDark),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              seg(ThemeMode.light, Icons.light_mode_outlined),
              seg(ThemeMode.dark, Icons.dark_mode_outlined),
              seg(ThemeMode.system, Icons.phone_android),
            ]),
          ),
          const SizedBox(height: 12),
          SettingsGroup(children: [
            SettingsSwitch(title: l.settingHighContrast, subtitle: l.settingHighContrastHint, value: c.highContrast, onChanged: c.setHighContrast),
          ]),
          SectionLabel(l.settingArabicFont),
          SettingsGroup(children: [
            for (final f in const [('noto', 'Noto Sans Arabic', 'NotoSansArabic'), ('cairo', 'Cairo', 'Cairo'), ('plex', 'IBM Plex Sans Arabic', 'IBMPlexSansArabic')])
              SettingsChoice(
                title: f.$2,
                subtitle: 'أحمد خوري · عرض سعر',
                subtitleFamily: f.$3,
                titleFamily: f.$3,
                selected: c.arabicFont == f.$1,
                onTap: () => c.setPref(AppController.keyArabicFont, f.$1),
              ),
            SettingsChoice(title: l.fontSystem, selected: c.arabicFont == 'system', onTap: () => c.setPref(AppController.keyArabicFont, 'system')),
          ]),
        ]);
      },
    );
  }
}

/// Language and region: language, main currency, month names, digits.
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final ar = c.locale.languageCode == 'ar';
        return SettingsScaffold(title: l.hubLanguage, children: [
          SectionLabel(l.settingLanguage),
          SettingsGroup(children: [
            SettingsChoice(title: 'English', subtitle: l.onbLtr, selected: !ar, onTap: () => c.setLocale(const Locale('en'))),
            SettingsChoice(title: 'العربية', subtitle: l.onbRtl, selected: ar, onTap: () => c.setLocale(const Locale('ar'))),
          ]),
          SectionLabel(l.settingMainCurrency),
          SettingsGroup(children: [
            for (final code in dealCurrencies)
              SettingsChoice(title: code, selected: c.mainCurrency == code, onTap: () => c.setMainCurrency(code)),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(4, 6, 4, 0), child: Text(l.currencyNote, style: TextStyle(fontSize: 12.5, color: context.palette.text2))),
          SectionLabel(l.settingMonths),
          SettingsGroup(children: [
            SettingsChoice(title: l.monthsStandard, selected: !c.levantMonths, onTap: () => c.setFlag(AppController.keyLevant, false)),
            SettingsChoice(title: l.monthsLevant, selected: c.levantMonths, onTap: () => c.setFlag(AppController.keyLevant, true)),
          ]),
          SectionLabel(l.settingWeekStart),
          SettingsGroup(children: [
            for (final d in [(6, l.daySaturday), (0, l.daySunday), (1, l.dayMonday)])
              SettingsChoice(
                title: d.$2,
                selected: (c.weekStart ?? MaterialLocalizations.of(context).firstDayOfWeekIndex) == d.$1,
                onTap: () => c.setPref(AppController.keyWeekStart, '${d.$1}'),
              ),
          ]),
          SectionLabel(l.settingDigits),
          SettingsGroup(children: [
            SettingsChoice(title: l.digitsWestern, selected: !c.indicDigits, onTap: () => c.setFlag(AppController.keyIndic, false)),
            SettingsChoice(title: l.digitsIndic, selected: c.indicDigits, onTap: () => c.setFlag(AppController.keyIndic, true)),
          ]),
        ]);
      },
    );
  }
}

/// Notifications and alarms: quiet hours, weekly update check, alarm test.
class NotificationsSettingsPage extends StatelessWidget {
  const NotificationsSettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    String hm(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context);
    Future<void> pick(String key, int cur) async {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
      if (t != null) await c.setPref(key, '${t.hour * 60 + t.minute}');
    }

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => SettingsScaffold(title: l.hubNotif, children: [
        SettingsGroup(children: [
          SettingsSwitch(
            title: l.settingQuietHours,
            subtitle: c.quietHoursOn ? '${hm(c.quietFrom)} – ${hm(c.quietTo)}' : null,
            value: c.quietHoursOn,
            onChanged: (v) => c.setFlag(AppController.keyQuietOn, v),
          ),
          if (c.quietHoursOn) ...[
            SettingsRow(title: l.settingQuietFrom, value: hm(c.quietFrom), chevron: true, onTap: () => pick(AppController.keyQuietFrom, c.quietFrom)),
            SettingsRow(title: l.settingQuietTo, value: hm(c.quietTo), chevron: true, onTap: () => pick(AppController.keyQuietTo, c.quietTo)),
            SettingsSwitch(title: l.settingQuietAlarms, value: c.silenceAlarmsInQuiet, onChanged: (v) => c.setFlag(AppController.keyQuietAlarms, v)),
          ],
          SettingsSwitch(
            title: l.settingWeeklyUpdates,
            subtitle: l.settingWeeklyUpdatesHint,
            value: c.weeklyUpdateCheck,
            onChanged: (v) => c.setFlag(AppController.keyWeeklyUpdate, v),
          ),
        ]),
        const SizedBox(height: 16),
        PillButton(
          label: l.settingAlarmTest,
          outlined: true,
          height: 48,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AlarmTestPage())),
        ),
      ]),
    );
  }
}

/// Inactivity alerts: how many idle days put a contact under Needs attention, by rating.
class InactivityPage extends StatelessWidget {
  const InactivityPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    Future<void> pick(String title, String key) async {
      final res = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(title: Text(title), children: [
          for (final d in const [3, 7, 14, 21, 30, 45, 60])
            SimpleDialogOption(onPressed: () => Navigator.of(ctx).pop(d), child: Text(l.filterDays(d))),
        ]),
      );
      if (res != null) await c.setPref(key, '$res');
    }

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => SettingsScaffold(title: l.hubInact, children: [
        Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 12), child: Text(l.inactIntro, style: TextStyle(color: context.palette.text2))),
        SettingsGroup(children: [
          SettingsRow(title: l.inactHot, value: l.filterDays(c.inactiveDays(Rating.hot)), chevron: true, onTap: () => pick(l.inactHot, AppController.keyInactHot)),
          SettingsRow(title: l.inactWarm, value: l.filterDays(c.inactiveDays(Rating.warm)), chevron: true, onTap: () => pick(l.inactWarm, AppController.keyInactWarm)),
          SettingsRow(title: l.inactCold, value: l.filterDays(c.inactiveDays(Rating.cold)), chevron: true, onTap: () => pick(l.inactCold, AppController.keyInactCold)),
        ]),
      ]),
    );
  }
}

/// Deals: main currency and the stage list.
class DealsSettingsPage extends StatelessWidget {
  const DealsSettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => SettingsScaffold(title: l.hubDeals, children: [
        SectionLabel(l.settingMainCurrency),
        SettingsGroup(children: [
          for (final code in dealCurrencies) SettingsChoice(title: code, selected: c.mainCurrency == code, onTap: () => c.setMainCurrency(code)),
        ]),
        Padding(padding: const EdgeInsets.fromLTRB(4, 6, 4, 12), child: Text(l.currencyNote, style: TextStyle(fontSize: 12.5, color: context.palette.text2))),
        if (c.deals != null)
          SettingsGroup(children: [
            SettingsRow(
              title: l.stagesTitle,
              chevron: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StagesPage(deals: c.deals!))),
            ),
          ]),
      ]),
    );
  }
}

/// The Home sections that can be switched off, in the order they appear.
const homeSections = ['overdue', 'today', 'upcoming', 'complete', 'attention', 'recent', 'pipeline', 'targets', 'activity'];

/// Home: turn sections on or off.
class HomeSettingsPage extends StatelessWidget {
  const HomeSettingsPage({super.key, required this.controller});
  final AppController controller;

  static String label(AppLocalizations l, String key) => switch (key) {
        'overdue' => l.sectionOverdue,
        'today' => l.sectionToday,
        'upcoming' => l.sectionUpcoming,
        'complete' => l.homeToComplete,
        'attention' => l.sectionNeedsAttention,
        'recent' => l.sectionRecentContacts,
        'pipeline' => l.sectionPipeline,
        'targets' => l.targetsTitle,
        _ => l.sectionRecentActivity,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final hidden = c.homeHidden;
        return SettingsScaffold(title: l.hubHome, children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 12), child: Text(l.homeIntro, style: TextStyle(color: context.palette.text2))),
          SettingsGroup(children: [
            for (final k in homeSections)
              SettingsSwitch(
                title: label(l, k),
                value: !hidden.contains(k),
                onChanged: (on) {
                  final next = {...hidden};
                  on ? next.remove(k) : next.add(k);
                  c.setPref(AppController.keyHomeHidden, next.join(','));
                },
              ),
          ]),
        ]);
      },
    );
  }
}
