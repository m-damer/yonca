import '../../data/system_channel.dart';
import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart' show Look;
import '../../data/reminders.dart';
import '../../diagnostics/alarm_test.dart';
import '../../domain/contact_models.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
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
                final v = await choose<String>(l.settingDefaultCurrency, [for (final x in pickableCurrencyCodes(keep: c.mainCurrency)) (x, x)], c.mainCurrency);
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

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> with WidgetsBindingObserver {
  ReminderPermissions? _perm;
  bool _fullScreen = true;
  bool _install = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPerm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the phone's settings screens: read the permissions again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadPerm();
  }

  Future<void> _loadPerm() async {
    try {
      final p = await widget.controller.reminderPermissions();
      final fs = await SystemChannel.canUseFullScreenIntent();
      final ins = await SystemChannel.canInstallPackages();
      if (mounted) {
        setState(() {
          _perm = p;
          _fullScreen = fs;
          _install = ins;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickSound() async {
    final c = widget.controller;
    final r = await SystemChannel.pickRingtone(c.alarmSoundUri);
    if (r != null) await c.setAlarmSound(r.uri, r.title);
  }

  /// The "Not now / Open phone settings" dialog (design Sys PE, PF).
  Future<bool> _askOpen(String title, String body) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          DialogCancel(l.notNowBtn, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.openPhoneSettings, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    return ok == true;
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

    Widget permRow(String title, bool ok, Future<void> Function() fix) => SettingsRow(
          vpad: 13.6,
          title: title,
          trailing: chip(ok ? l.permOn : l.permOffFix, ok),
          onTap: ok
              ? null
              : () async {
                  await fix();
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
          SettingsRow(vpad: 13, title: l.settingAlarmSound, value: c.alarmSoundName.isEmpty ? l.alarmSoundDefault : c.alarmSoundName, chevron: true, onTap: _pickSound),
          SettingsSwitch(vpad: 10, title: l.settingHideLock, value: c.hideLockDetails, onChanged: (v) => c.setFlag(AppController.keyHideLock, v)),
          SettingsSwitch(vpad: 10, title: l.settingTargetAlerts, value: c.targetAlerts, onChanged: (v) => c.setFlag(AppController.keyTargetAlerts, v)),
        ]),
        const SizedBox(height: 14),
        PillButton(
          label: l.settingAlarmTest,
          icon: Icons.notifications_none,
          outlined: true,
          height: 48,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AlarmTestPage())),
        ),
        SectionLabel(l.permissionsLabel),
        SettingsGroup(children: [
          permRow(l.permNotifications, _perm?.notifications ?? true, c.askReminderPermissions),
          permRow(l.permExact, _perm?.exactAlarms ?? true, () async {
            if (await _askOpen(l.permExact, l.permExactBody)) await c.askReminderPermissions();
          }),
          permRow(l.permFull, _fullScreen, () async {
            if (await _askOpen(l.permFull, l.permFullBody)) await SystemChannel.openFullScreenSettings();
          }),
          permRow(l.permInstall, _install, () async {
            if (await _askOpen(l.permInstall, l.permInstallBody)) await SystemChannel.openInstallSettings();
          }),
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
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 20, color: p.primary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => pick(label, key, days),
              child: Container(
                constraints: const BoxConstraints(minWidth: 96, minHeight: 46),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: p.glass, borderRadius: BorderRadius.circular(8), border: Border.all(color: p.glassBorder)),
                child: Text(l.filterDays(days), style: TextStyle(fontSize: 17, height: 24 / 17, color: p.text)),
              ),
            ),
          ]),
        ),
      );
    }

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => SettingsScaffold(title: l.hubInact, children: [
        Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 12), child: Text(l.inactIntro, style: TextStyle(color: p.text2))),
        card(Icons.local_fire_department_outlined, l.inactHot, Rating.hot, AppController.keyInactHot),
        card(Icons.wb_sunny_outlined, l.inactWarm, Rating.warm, AppController.keyInactWarm),
        card(Icons.dark_mode_outlined, l.inactCold, Rating.cold, AppController.keyInactCold),
        card(Icons.star_outline, l.inactUnrated, Rating.none, AppController.keyInactNone),
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
          SheetTitle(l.dealSortBy),
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
      builder: (context, _) => SettingsScaffold(title: l.hubDeals, children: [
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
        const SizedBox(height: 10),
        PillButton(label: l.addCustomCurrency, icon: Icons.add, outlined: true, onPressed: () => showCurrencySheet(context, c)),
        Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 4), child: Text(l.dealCurrenciesNote, style: TextStyle(fontSize: 13, color: p.text2))),
        SectionLabel(l.dealSortInStage),
        SettingsGroup(children: [
          SettingsRow(vpad: 13, title: l.dealSortBy, value: byLabel(dealSortBy), chevron: true, onTap: pickBy),
          SettingsRow(vpad: 13, title: l.dealDirection, value: dealSortDesc ? l.dealDesc : l.dealAsc, chevron: true, onTap: pickDir),
        ]),
        const SizedBox(height: 16),
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

/// The Home sections that can be switched off, in the order they appear.
const homeSections = AppController.homeSectionKeys;

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
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 12), child: Text(l.homeIntro, style: TextStyle(color: p.text2))),
          GlassCard(
            padding: EdgeInsets.zero,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
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
                    if (i > 0) Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: p.separator),
                    SettingsRow(
                      leadingWidget: ReorderableDragStartListener(index: i, child: Icon(Icons.drag_indicator, size: 22, color: p.text2)),
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
