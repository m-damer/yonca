import '../../data/system_channel.dart';
import 'package:flutter/material.dart';
import '../../shared/pickers.dart';

import '../../app_controller.dart';
import '../../core/format.dart' show Look;
import '../../domain/contact_models.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../deals/stages_page.dart';
import 'currency_sheet.dart';
import '../schedule/schedule_labels.dart' show formatClock;
import 'permissions_page.dart';
import 'settings_widgets.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

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
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => c.setThemeMode(m),
              child: Container(
                height: AppControl.md,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? p.segmentOn : null,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: on ? [BoxShadow(color: p.segmentShadow, blurRadius: 2, offset: const Offset(0, 1))] : null,
                ),
                child: Text(themeName(l, m), style: TextStyle(fontSize: AppFont.meta, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? p.text : p.text2)),
              ),
            ),
          );
        }

        return SettingsScaffold(title: l.hubAppearance, children: [
          SectionLabel(l.secLightDark),
          Container(
            padding: const EdgeInsets.all(AppSpace.xs),
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(children: [
              seg(ThemeMode.light, Lu.sun),
              seg(ThemeMode.dark, Lu.moon),
              seg(ThemeMode.system, Lu.smartphone),
            ]),
          ),
          const SizedBox(height: AppSpace.md),
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

    Future<T?> choose<T>(String title, List<(T, String)> options, T current) => showGlassSheet<T>(
          context,
          builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SheetTitle(title),
            for (final (i, o) in options.indexed) SheetItem(first: i == 0, title: o.$2, bold: o.$1 == current, selected: o.$1 == current, onTap: () => Navigator.of(ctx).pop(o.$1)),
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
                final v = await choose<String>(l.settingDefaultCurrency, [for (final x in pickableCurrencyCodes(keep: c.mainCurrency)) (x, x)], c.mainCurrency);
                if (v != null) await c.setMainCurrency(v);
              },
            ),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.lg, AppSpace.xs, 0), child: Text(l.langSwitchNote, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2))),
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
  Future<void> _pickSound() async {
    final c = widget.controller;
    final r = await SystemChannel.pickRingtone(c.alarmSoundUri);
    if (r != null) await c.setAlarmSound(r.uri, r.title);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.controller;
    String hm(int m) => formatClock(context, DateTime(2000, 1, 1, m ~/ 60, m % 60)).replaceFirst(RegExp(r'^0(?=\d)'), '');
    Future<int?> pickMinutes(int cur) async {
      final t = await pickTime(context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
      return t == null ? null : t.hour * 60 + t.minute;
    }

    Future<void> pick(String key, int cur) async {
      final v = await pickMinutes(cur);
      if (v != null) await c.setPref(key, '$v');
    }

    Future<void> pickQuiet() async {
      final from = await pickMinutes(c.quietFrom);
      if (from == null) return;
      if (!context.mounted) return;
      final to = await pickMinutes(c.quietTo);
      if (to == null) return;
      await c.setPref(AppController.keyQuietFrom, '$from');
      await c.setPref(AppController.keyQuietTo, '$to');
      await c.setFlag(AppController.keyQuietOn, true);
    }

    Future<void> pickEvery() async {
      final res = await showGlassSheet<int>(
        context,
        builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.settingNoteEvery),
          for (final (i, h) in const [1, 2, 3, 6, 12, 24].indexed) SheetItem(first: i == 0, title: l.noteEveryValue(h), onTap: () => Navigator.of(ctx).pop(h)),
        ]),
      );
      if (res != null) await c.setPref(AppController.keyNoteEvery, '$res');
    }

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
          SettingsRow(vpad: 13, title: l.settingAlarmSound, value: c.alarmSoundName.isEmpty ? l.alarmSoundDefault : c.alarmSoundName, chevron: true, onTap: _pickSound),
          SettingsSwitch(vpad: 10, title: l.settingHideLock, value: c.hideLockDetails, onChanged: (v) => c.setFlag(AppController.keyHideLock, v)),
          SettingsSwitch(vpad: 10, title: l.settingTargetAlerts, value: c.targetAlerts, onChanged: (v) => c.setFlag(AppController.keyTargetAlerts, v)),
        ]),
        SectionLabel(l.permissionsLabel),
        SettingsGroup(children: [
          SettingsRow(
            vpad: 13,
            icon: Lu.circleCheck,
            title: l.permCheckTitle,
            chevron: true,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PermissionsPage(controller: c))),
          ),
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
    final p = context.palette;
    Future<void> pick(String title, String key, int current) async {
      final res = await showGlassSheet<int>(
        context,
        builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(title),
          for (final (i, d) in const [3, 7, 14, 21, 30, 45, 60].indexed)
            SheetItem(first: i == 0, title: l.filterDays(d), bold: d == current, selected: d == current, onTap: () => Navigator.of(ctx).pop(d)),
        ]),
      );
      if (res != null) await c.setPref(key, '$res');
    }

    Widget card(IconData icon, String label, Rating r, String key) {
      final days = c.inactiveDays(r);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
          child: Row(children: [
            IconTile(icon: icon),
            const SizedBox(width: AppSpace.md),
            Expanded(child: Text(label, style: const TextStyle(fontSize: AppFont.bodyL, fontWeight: FontWeight.w500))),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => pick(label, key, days),
              child: Container(
                constraints: const BoxConstraints(minWidth: 96, minHeight: 46),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
                decoration: BoxDecoration(color: p.glass, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: p.glassBorder)),
                child: Text(l.filterDays(days), style: TextStyle(fontSize: AppFont.subtitle, height: AppLine.normal, color: p.text)),
              ),
            ),
          ]),
        ),
      );
    }

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => SettingsScaffold(title: l.hubInact, children: [
        Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.md), child: Text(l.inactIntro, style: TextStyle(color: p.text2))),
        card(Lu.flame, l.ratingHot, Rating.hot, AppController.keyInactHot),
        card(Lu.sun, l.ratingWarm, Rating.warm, AppController.keyInactWarm),
        card(Lu.moon, l.ratingCold, Rating.cold, AppController.keyInactCold),
        card(Lu.star, l.inactUnrated, Rating.none, AppController.keyInactNone),
        SettingsGroup(children: [
          SettingsSwitch(title: l.inactOffAll, value: c.inactivityOff, onChanged: (v) => c.setFlag(AppController.keyInactOff, v)),
        ]),
      ]),
    );
  }
}

/// Deals (design G7): which currencies are offered, how deals are sorted in a stage, and the stages.
class DealsSettingsPage extends StatelessWidget {
  const DealsSettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    final p = context.palette;
    String nameOf(String code) {
      for (final x in customCurrencies.value) {
        if (x.code == code) return x.name;
      }
      return switch (code) {
        'USD' => l.onbCurUsd,
        'SYP' => l.onbCurSyp,
        'EUR' => l.onbCurEur,
        'TRY' => l.onbCurTry,
        _ => code,
      };
    }

    String byLabel(String k) => switch (k) {
          'amount' => l.dealSortAmount,
          'created' => l.dealSortCreated,
          _ => l.dealSortClose,
        };

    Future<void> pickBy() async {
      final v = await showGlassSheet<String>(
        context,
        builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.sortTitle),
          for (final (i, k) in const ['close', 'amount', 'created'].indexed)
            SheetItem(first: i == 0, title: byLabel(k), bold: k == dealSortBy, selected: k == dealSortBy, onTap: () => Navigator.of(ctx).pop(k)),
        ]),
      );
      if (v != null) await c.setDealSort(v, dealSortDesc);
    }

    Future<void> pickDir() async {
      final v = await showGlassSheet<bool>(
        context,
        builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.dealDirection),
          SheetItem(first: true, title: l.dealAsc, bold: !dealSortDesc, selected: !dealSortDesc, onTap: () => Navigator.of(ctx).pop(false)),
          SheetItem(title: l.dealDesc, bold: dealSortDesc, selected: dealSortDesc, onTap: () => Navigator.of(ctx).pop(true)),
        ]),
      );
      if (v != null) await c.setDealSort(dealSortBy, v);
    }

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => SettingsScaffold(title: l.navDeals, children: [
        SectionLabel(l.dealCurrenciesTitle),
        ValueListenableBuilder<List<CurrencyDef>>(
          valueListenable: customCurrencies,
          builder: (context, _, __) => SettingsGroup(children: [
            for (final code in allCurrencyCodes())
              SettingsSwitch(
                title: code,
                subtitle: nameOf(code),
                value: !hiddenCurrencies.value.contains(code),
                onChanged: (v) {
                  if (code == c.mainCurrency && !v) return;
                  c.setCurrencyHidden(code, !v);
                },
              ),
          ]),
        ),
        const SizedBox(height: AppSpace.md),
        PillButton(label: l.addCustomCurrency, icon: Lu.plus, outlined: true, onPressed: () => showCurrencySheet(context, c)),
        Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.sm, AppSpace.xs, AppSpace.xs), child: Text(l.dealCurrenciesNote, style: TextStyle(fontSize: AppFont.meta, color: p.text2))),
        SectionLabel(l.dealSortInStage),
        SettingsGroup(children: [
          SettingsRow(vpad: 13, title: l.sortTitle, value: byLabel(dealSortBy), chevron: true, onTap: pickBy),
          SettingsRow(vpad: 13, title: l.dealDirection, value: dealSortDesc ? l.dealDesc : l.dealAsc, chevron: true, onTap: pickDir),
        ]),
        const SizedBox(height: AppSpace.lg),
        if (c.deals != null)
          SettingsGroup(children: [
            SettingsRow(
              vpad: 13,
              title: l.stagesTitle,
              chevron: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StagesPage(deals: c.deals!))),
            ),
          ]),
      ]),
    );
  }
}

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

  static void _toggle(AppController c, Set<String> hidden, String k, bool on) {
    final next = {...hidden};
    on ? next.remove(k) : next.add(k);
    c.setPref(AppController.keyHomeHidden, next.join(','));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final hidden = c.homeHidden;
        final order = c.homeOrder;
        final p = context.palette;
        return SettingsScaffold(title: l.hubHome, children: [
          Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.md), child: Text(l.homeIntro, style: TextStyle(color: p.text2))),
          GlassCard(
            padding: EdgeInsets.zero,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              proxyDecorator: (child, _, __) => Material(color: Colors.transparent, child: child),
              itemCount: order.length,
              onReorderItem: (from, to) {
                final next = [...order];
                next.insert(to, next.removeAt(from));
                c.setPref(AppController.keyHomeOrder, next.join(','));
              },
              itemBuilder: (context, i) {
                final k = order[i];
                final on = !hidden.contains(k);
                return Material(
                  key: ValueKey(k),
                  type: MaterialType.transparency,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (i > 0) Divider(height: 1, thickness: 1, indent: AppSpace.lg, endIndent: AppSpace.lg, color: p.separator),
                    SettingsRow(
                      leadingWidget: ReorderableDragStartListener(index: i, child: Icon(Lu.gripVertical, size: AppIcon.lg, color: p.text2)),
                      title: label(l, k),
                      trailing: AppSwitch(value: on, onChanged: (v) => _toggle(c, hidden, k, v)),
                      onTap: () => _toggle(c, hidden, k, !on),
                    ),
                  ]),
                );
              },
            ),
          ),
        ]);
      },
    );
  }
}
