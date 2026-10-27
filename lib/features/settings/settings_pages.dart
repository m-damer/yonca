import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../diagnostics/alarm_test.dart';
import '../../domain/contact_models.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../../theme/theme.dart';
import '../deals/stages_page.dart';
import 'settings_widgets.dart';

String accentName(AppLocalizations l, int i) => switch (i) {
      1 => l.accentBlue,
      2 => l.accentSky,
      3 => l.accentPlum,
      4 => l.accentPink,
      5 => l.accentRed,
      6 => l.accentOrange,
      7 => l.accentMustard,
      8 => l.accentGreen,
      9 => l.accentTeal,
      10 => l.accentSlate,
      11 => l.accentClay,
      _ => l.accentForest,
    };

String themeName(AppLocalizations l, ThemeMode m) => switch (m) {
      ThemeMode.system => l.themeSystem,
      ThemeMode.light => l.themeLight,
      ThemeMode.dark => l.themeDark,
    };

/// Appearance: theme colour, light or dark, high contrast, Arabic font.
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
        final dark = Theme.of(context).brightness == Brightness.dark;
        Widget seg(ThemeMode m, IconData icon) {
          final on = c.themeMode == m;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => c.setThemeMode(m),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: on ? p.primary : null, borderRadius: BorderRadius.circular(20)),
                child: Text(themeName(l, m), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? p.onPrimary : p.text)),
              ),
            ),
          );
        }

        return SettingsScaffold(title: l.hubAppearance, children: [
          SectionLabel(l.secThemeColour),
          SettingsGroup(children: [
            SettingsChoice(title: l.followMyPhone, subtitle: l.followPhoneSettingsBody, selected: c.accent < 0, onTap: () => c.setAccent(-1)),
            SettingsChoice(
              title: l.onbChooseColour,
              selected: c.accent >= 0,
              onTap: () {
                if (c.accent < 0) c.setAccent(0);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Wrap(spacing: 14, runSpacing: 14, children: [
                for (var i = 0; i < accentChoices.length; i++)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => c.setAccent(i),
                    child: Tooltip(
                      message: accentName(l, i),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: dark ? accentChoices[i].$2 : accentChoices[i].$1,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.accent == i ? p.text : Colors.transparent, width: 3),
                        ),
                        child: c.accent == i ? Icon(Icons.check, color: dark ? Colors.black : Colors.white, size: 20) : null,
                      ),
                    ),
                  ),
              ]),
            ),
            SettingsRow(
              title: l.customRow,
              value: c.accent == accentCustom ? '#${(c.customAccent ?? Colors.black).toARGB32().toRadixString(16).substring(2).toUpperCase()}' : null,
              chevron: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CustomColourPage(controller: c))),
            ),
          ]),
          SectionLabel(l.secLightDark),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: p.glass, borderRadius: BorderRadius.circular(24), border: Border.all(color: p.glassBorder)),
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
                subtitle: 'أحمد خوري · عرض سعر · ٢٠٢٦',
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
          height: 50,
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

/// Custom colour: a hue slider or a hex code, with a live preview.
class CustomColourPage extends StatefulWidget {
  const CustomColourPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<CustomColourPage> createState() => _CustomColourPageState();
}

class _CustomColourPageState extends State<CustomColourPage> {
  late final TextEditingController _hex;
  late Color _colour;

  @override
  void initState() {
    super.initState();
    _colour = widget.controller.customAccent ?? const Color(0xFF1F6FAE);
    _hex = TextEditingController(text: _hexOf(_colour));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  String _hexOf(Color c) => '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  void _typed(String v) {
    final t = v.replaceAll('#', '').trim();
    final n = t.length == 6 ? int.tryParse(t, radix: 16) : null;
    if (n != null) setState(() => _colour = Color(0xFF000000 | n));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final shown = readableAccent(_colour);
    final darkened = shown != _colour;
    final hue = HSLColor.fromColor(_colour).hue;
    return SettingsScaffold(title: l.customColour, children: [
      Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 12), child: Text(l.customColourHint, style: TextStyle(color: p.text2))),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Slider(
            value: hue.clamp(0, 359.9),
            max: 359.9,
            activeColor: shown,
            onChanged: (v) {
              final c = HSLColor.fromAHSL(1, v, .6, .38).toColor();
              setState(() => _colour = c);
              _hex.text = _hexOf(c);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hex,
            onChanged: _typed,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: l.hexLabel, border: const OutlineInputBorder()),
          ),
          if (darkened) Padding(padding: const EdgeInsets.only(top: 10), child: Text(l.customDarkened, style: TextStyle(fontSize: 12.5, color: p.text2))),
        ]),
      ),
      SectionLabel(l.previewLabel),
      GlassCard(
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: shown, borderRadius: BorderRadius.circular(16)),
            child: const Text('AK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Ahmad Khoury', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: shown, borderRadius: BorderRadius.circular(18)),
            child: Text(l.save, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      PillButton(
        label: l.save,
        height: 52,
        onPressed: () async {
          final c = widget.controller;
          final nav = Navigator.of(context);
          await c.setPref(AppController.keyAccentCustom, '${_colour.toARGB32()}');
          await c.setAccent(accentCustom);
          nav.pop();
        },
      ),
    ]);
  }
}
