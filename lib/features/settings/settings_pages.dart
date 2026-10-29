import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart' show Look;
import '../../data/reminders.dart';
import '../../diagnostics/alarm_test.dart';
import '../../domain/contact_models.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import '../deals/stages_page.dart';
import 'currency_sheet.dart';
import '../schedule/schedule_labels.dart' show formatClock;
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
                  color: on ? (dark ? const Color(0xFF48484A) : p.glass) : null,
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

/// Language and region: language, digits, month names, then first day, name order and main currency.
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    final p = context.palette;

    Future<T?> choose<T>(String title, List<(T, String)> options, T current) => showDialog<T>(
          context: context,
          builder: (ctx) => SimpleDialog(title: Text(title), children: [
            for (final o in options)
              SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(o.$1),
                child: Row(children: [
                  Expanded(child: Text(o.$2, style: TextStyle(fontWeight: o.$1 == current ? FontWeight.w600 : FontWeight.w400))),
                  if (o.$1 == current) Icon(Icons.check, size: 20, color: p.primary),
                ]),
              ),
          ]),
        );

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final ar = c.locale.languageCode == 'ar';
        final week = c.weekStart ?? MaterialLocalizations.of(context).firstDayOfWeekIndex;
        final dayName = switch (week) { 6 => l.daySaturday, 0 => l.daySunday, _ => l.dayMonday };
        return SettingsScaffold(title: l.hubLanguage, children: [
          SectionLabel(l.settingLanguage),
          SegControl(labels: const ['English', 'العربية'], selected: ar ? 1 : 0, onSelect: (i) => c.setLocale(Locale(i == 0 ? 'en' : 'ar'))),
          SectionLabel(l.settingDigits),
          SegControl(labels: [l.segDigitsWestern, l.segDigitsIndic], selected: c.indicDigits ? 1 : 0, onSelect: (i) => c.setFlag(AppController.keyIndic, i == 1)),
          SectionLabel(l.settingMonths),
          SegControl(labels: [l.segSyrian, l.segGulf], selected: c.levantMonths ? 0 : 1, onSelect: (i) => c.setFlag(AppController.keyLevant, i == 0)),
          SectionLabel(l.secRegion),
          SettingsGroup(children: [
            SettingsRow(
              vpad: 13,
              title: l.settingFirstDay,
              value: dayName,
              chevron: true,
              onTap: () async {
                final v = await choose<int>(l.settingFirstDay, [(6, l.daySaturday), (0, l.daySunday), (1, l.dayMonday)], week);
                if (v != null) await c.setPref(AppController.keyWeekStart, '$v');
              },
            ),
            SettingsRow(
              vpad: 13,
              title: l.settingNameOrder,
              value: Look.lastFirst ? l.nameLastFirst : l.nameFirstLast,
              chevron: true,
              onTap: () async {
                final v = await choose<bool>(l.settingNameOrder, [(false, l.nameFirstLast), (true, l.nameLastFirst)], Look.lastFirst);
                if (v != null) await c.setFlag(AppController.keyLastFirst, v);
              },
            ),
            SettingsRow(
              vpad: 13,
              title: l.settingDefaultCurrency,
              value: c.mainCurrency,
              chevron: true,
              onTap: () async {
                final v = await choose<String>(l.settingDefaultCurrency, [for (final x in allCurrencyCodes()) (x, x)], c.mainCurrency);
                if (v != null) await c.setMainCurrency(v);
              },
            ),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 0), child: Text(l.langSwitchNote, style: TextStyle(fontSize: 13, height: 18.2 / 13, color: p.text2))),
        ]);
      },
    );
  }
}

/// Notifications and alarms: quiet hours, weekly update check, alarm test.
class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<NotificationsSettingsPage> createState() => _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  ReminderPermissions? _perm;

  @override
  void initState() {
    super.initState();
    _loadPerm();
  }

  Future<void> _loadPerm() async {
    try {
      final p = await widget.controller.reminderPermissions();
      if (mounted) setState(() => _perm = p);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.controller;
    final p = context.palette;
    String hm(int m) => formatClock(context, DateTime(2000, 1, 1, m ~/ 60, m % 60)).replaceFirst(RegExp(r'^0(?=\d)'), '');
    Future<int?> pickTime(int cur) async {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
      return t == null ? null : t.hour * 60 + t.minute;
    }

    Future<void> pick(String key, int cur) async {
      final v = await pickTime(cur);
      if (v != null) await c.setPref(key, '$v');
    }

    Future<void> pickQuiet() async {
      final from = await pickTime(c.quietFrom);
      if (from == null) return;
      if (!context.mounted) return;
      final to = await pickTime(c.quietTo);
      if (to == null) return;
      await c.setPref(AppController.keyQuietFrom, '$from');
      await c.setPref(AppController.keyQuietTo, '$to');
      await c.setFlag(AppController.keyQuietOn, true);
    }

    Future<void> pickEvery() async {
      final res = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(title: Text(l.settingNoteEvery), children: [
          for (final h in const [1, 2, 3, 6, 12, 24]) SimpleDialogOption(onPressed: () => Navigator.of(ctx).pop(h), child: Text(l.noteEveryValue(h))),
        ]),
      );
      if (res != null) await c.setPref(AppController.keyNoteEvery, '$res');
    }

    Widget chip(String text, bool ok) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: ok ? p.surface2 : const Color(0xFFFFE5E2), borderRadius: BorderRadius.circular(4)),
          child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ok ? p.text2 : const Color(0xFFB3261E))),
        );

    Widget permRow(String title, bool ok) => SettingsRow(
          vpad: 13.6,
          title: title,
          trailing: chip(ok ? l.permOn : l.permOffFix, ok),
          onTap: ok
              ? null
              : () async {
                  await c.askReminderPermissions();
                  await _loadPerm();
                },
        );

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => SettingsScaffold(title: l.hubNotif, children: [
        SettingsGroup(children: [
          SettingsRow(
            vpad: 13,
            title: l.settingQuietHours,
            value: c.quietHoursOn ? l.notifQuietRange(hm(c.quietFrom), hm(c.quietTo)) : l.notifOff,
            chevron: true,
            onTap: pickQuiet,
          ),
          SettingsSwitch(vpad: 10, title: l.settingQuietAlarms, value: c.silenceAlarmsInQuiet, onChanged: (v) => c.setFlag(AppController.keyQuietAlarms, v)),
          SettingsRow(vpad: 13, title: l.settingNoteEvery, value: l.noteEveryValue(c.noteEveryHours), chevron: true, onTap: pickEvery),
          SettingsRow(vpad: 13, title: l.settingDateOnlyTime, value: hm(c.dateOnlyTime), chevron: true, onTap: () => pick(AppController.keyDateOnlyTime, c.dateOnlyTime)),
          SettingsRow(vpad: 13, title: l.settingEventTime, value: hm(c.eventTime), chevron: true, onTap: () => pick(AppController.keyEventTime, c.eventTime)),
          SettingsRow(vpad: 13, title: l.settingAlarmSound, value: l.alarmSoundDefault, chevron: true),
          SettingsSwitch(vpad: 10, title: l.settingHideLock, value: c.hideLockDetails, onChanged: (v) => c.setFlag(AppController.keyHideLock, v)),
          SettingsSwitch(vpad: 10, title: l.settingTargetAlerts, value: c.targetAlerts, onChanged: (v) => c.setFlag(AppController.keyTargetAlerts, v)),
        ]),
        const SizedBox(height: 14),
        PillButton(
          label: l.settingAlarmTest,
          outlined: true,
          height: 48,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AlarmTestPage())),
        ),
        SectionLabel(l.permissionsLabel),
        SettingsGroup(children: [
          permRow(l.permNotifications, _perm?.notifications ?? true),
          permRow(l.permExact, _perm?.exactAlarms ?? true),
        ]),
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
        ValueListenableBuilder<List<CurrencyDef>>(
          valueListenable: customCurrencies,
          builder: (context, _, __) => SettingsGroup(children: [
            for (final code in allCurrencyCodes()) SettingsChoice(title: code, selected: c.mainCurrency == code, onTap: () => c.setMainCurrency(code)),
            SettingsRow(title: l.addCustomCurrency, icon: Icons.add, onTap: () => showCurrencySheet(context, c)),
          ]),
        ),
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
