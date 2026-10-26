import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../../theme/theme.dart';
import '../../diagnostics/alarm_test.dart';
import '../data/data_page.dart';
import '../deals/stages_page.dart';
import '../fields/fields_page.dart';
import '../importing/profile_page.dart';
import '../stats/targets_page.dart';
import 'about_page.dart';

class _Entry {
  const _Entry(this.group, this.icon, this.label, {this.value, this.onTap, this.trailing});
  final String group;
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
}

/// Settings in groups, with a search box that filters the rows by name.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _search = TextEditingController();
  String _query = '';

  AppController get c => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _pickLanguage() async {
    final l = AppLocalizations.of(context);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(title: Text(l.settingLanguage), children: [
        SimpleDialogOption(onPressed: () => Navigator.of(ctx).pop('en'), child: const Text('English')),
        SimpleDialogOption(onPressed: () => Navigator.of(ctx).pop('ar'), child: const Text('العربية')),
      ]),
    );
    if (res != null) await c.setLocale(Locale(res));
  }

  Future<void> _pickTheme() async {
    final l = AppLocalizations.of(context);
    final res = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(title: Text(l.settingTheme), children: [
        for (final m in ThemeMode.values)
          SimpleDialogOption(onPressed: () => Navigator.of(ctx).pop(m), child: Text(_themeName(l, m))),
      ]),
    );
    if (res != null) await c.setThemeMode(res);
  }

  String _themeName(AppLocalizations l, ThemeMode m) => switch (m) {
        ThemeMode.system => l.themeSystem,
        ThemeMode.light => l.themeLight,
        ThemeMode.dark => l.themeDark,
      };

  String _accentName(AppLocalizations l, int i) => switch (i) {
        1 => l.accentTeal,
        2 => l.accentBlue,
        3 => l.accentPlum,
        4 => l.accentClay,
        _ => l.accentForest,
      };

  Future<void> _pickAccent() async {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(title: Text(l.settingAccent), children: [
        for (var i = 0; i < accentChoices.length; i++)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(i),
            child: Row(children: [
              CircleAvatar(radius: 10, backgroundColor: dark ? accentChoices[i].$2 : accentChoices[i].$1),
              const SizedBox(width: 12),
              Text(_accentName(l, i)),
            ]),
          ),
      ]),
    );
    if (res != null) await c.setAccent(res);
  }

  Future<T?> _choose<T>(String title, List<(T, String)> options) => showDialog<T>(
        context: context,
        builder: (ctx) => SimpleDialog(title: Text(title), children: [
          for (final o in options) SimpleDialogOption(onPressed: () => Navigator.of(ctx).pop(o.$1), child: Text(o.$2)),
        ]),
      );

  Future<void> _pickFont() async {
    final l = AppLocalizations.of(context);
    final v = await _choose<bool>(l.settingArabicFont, [(false, l.fontBundled), (true, l.fontSystem)]);
    if (v != null) await c.setFlag(AppController.keySystemFont, v);
  }

  Future<void> _pickMonths() async {
    final l = AppLocalizations.of(context);
    final v = await _choose<bool>(l.settingMonths, [(false, l.monthsStandard), (true, l.monthsLevant)]);
    if (v != null) await c.setFlag(AppController.keyLevant, v);
  }

  Future<void> _pickDigits() async {
    final l = AppLocalizations.of(context);
    final v = await _choose<bool>(l.settingDigits, [(false, l.digitsWestern), (true, l.digitsIndic)]);
    if (v != null) await c.setFlag(AppController.keyIndic, v);
  }

  String _hm(int minutes) => TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  Future<void> _pickTime(String key, int current) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60));
    if (t != null) await c.setPref(key, '${t.hour * 60 + t.minute}');
  }

  List<_Entry> _entries(AppLocalizations l) => [
        _Entry(l.groupAppearance, Icons.language, l.settingLanguage,
            value: c.locale.languageCode == 'ar' ? 'العربية' : 'English', onTap: _pickLanguage),
        _Entry(l.groupAppearance, Icons.brightness_6_outlined, l.settingTheme, value: _themeName(l, c.themeMode), onTap: _pickTheme),
        _Entry(l.groupAppearance, Icons.palette_outlined, l.settingAccent, value: _accentName(l, c.accent), onTap: _pickAccent),
        _Entry(l.groupAppearance, Icons.contrast, l.settingHighContrast,
            value: l.settingHighContrastHint,
            trailing: Switch(value: c.highContrast, onChanged: (v) => c.setHighContrast(v)),
            onTap: () => c.setHighContrast(!c.highContrast)),
        _Entry(l.groupAppearance, Icons.font_download_outlined, l.settingArabicFont,
            value: c.systemArabicFont ? l.fontSystem : l.fontBundled, onTap: _pickFont),
        _Entry(l.groupAppearance, Icons.calendar_month_outlined, l.settingMonths,
            value: c.levantMonths ? l.monthsLevant : l.monthsStandard, onTap: _pickMonths),
        _Entry(l.groupAppearance, Icons.pin_outlined, l.settingDigits, value: c.indicDigits ? l.digitsIndic : l.digitsWestern, onTap: _pickDigits),
        _Entry(l.groupNotifications, Icons.bedtime_outlined, l.settingQuietHours,
            value: c.quietHoursOn ? '${_hm(c.quietFrom)} – ${_hm(c.quietTo)}' : null,
            trailing: Switch(value: c.quietHoursOn, onChanged: (v) => c.setFlag(AppController.keyQuietOn, v)),
            onTap: () => c.setFlag(AppController.keyQuietOn, !c.quietHoursOn)),
        if (c.quietHoursOn) ...[
          _Entry(l.groupNotifications, Icons.schedule, l.settingQuietFrom,
              value: _hm(c.quietFrom), onTap: () => _pickTime(AppController.keyQuietFrom, c.quietFrom)),
          _Entry(l.groupNotifications, Icons.schedule, l.settingQuietTo,
              value: _hm(c.quietTo), onTap: () => _pickTime(AppController.keyQuietTo, c.quietTo)),
          _Entry(l.groupNotifications, Icons.volume_off_outlined, l.settingQuietAlarms,
              trailing: Switch(value: c.silenceAlarmsInQuiet, onChanged: (v) => c.setFlag(AppController.keyQuietAlarms, v)),
              onTap: () => c.setFlag(AppController.keyQuietAlarms, !c.silenceAlarmsInQuiet)),
        ],
        _Entry(l.groupNotifications, Icons.alarm, l.settingAlarmTest, onTap: () => _push(const AlarmTestPage())),
        _Entry(l.groupAbout, Icons.notifications_active_outlined, l.settingWeeklyUpdates,
            value: l.settingWeeklyUpdatesHint,
            trailing: Switch(value: c.weeklyUpdateCheck, onChanged: (v) => c.setFlag(AppController.keyWeeklyUpdate, v)),
            onTap: () => c.setFlag(AppController.keyWeeklyUpdate, !c.weeklyUpdateCheck)),
        if (c.database != null) _Entry(l.groupWork, Icons.account_circle_outlined, l.profileTitle, onTap: () => _push(ProfilePage(db: c.database!))),
        if (c.stats != null) _Entry(l.groupWork, Icons.flag_outlined, l.targetsTitle, onTap: () => _push(TargetsPage(stats: c.stats!))),
        if (c.deals != null) _Entry(l.groupWork, Icons.view_kanban_outlined, l.stagesTitle, onTap: () => _push(StagesPage(deals: c.deals!))),
        if (c.fields != null) _Entry(l.groupWork, Icons.tune, l.customFieldsTitle, onTap: () => _push(FieldsPage(fields: c.fields!))),
        if (c.database != null) _Entry(l.groupData, Icons.backup_outlined, l.dataTitle, onTap: () => _push(DataPage(controller: c))),
        _Entry(l.groupAbout, Icons.info_outline, l.aboutTitle, onTap: () => _push(AboutPage(controller: c))),
      ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final q = _query.trim().toLowerCase();
        final all = _entries(l).where((e) => q.isEmpty || e.label.toLowerCase().contains(q) || e.group.toLowerCase().contains(q)).toList();
        final order = [l.groupAppearance, l.groupNotifications, l.groupWork, l.groupData, l.groupAbout];
        final groups = [for (final g in order) if (all.any((e) => e.group == g)) g];
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: GlassBackdrop(
            child: Column(children: [
              HeaderBand(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: SafeArea(
                  bottom: false,
                  child: Row(children: [
                    GlassIconButton(icon: Icons.arrow_back, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                    const SizedBox(width: 14),
                    Expanded(child: Text(l.settingsTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.onHeader))),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GlassField(controller: _search, label: l.settingsSearch, onChanged: (v) => setState(() => _query = v)),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
                  if (all.isEmpty)
                    Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l.settingsNone, style: TextStyle(color: p.text2)))),
                  for (final g in groups) ...[
                    SectionLabel(g),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Material(
                        type: MaterialType.transparency,
                        child: Column(children: [
                          for (final e in all.where((e) => e.group == g))
                            ListTile(
                              leading: Icon(e.icon, color: p.primary),
                              title: Text(e.label),
                              subtitle: e.value == null ? null : Text(e.value!),
                              trailing: e.trailing ?? const Icon(Icons.chevron_right),
                              onTap: e.onTap,
                            ),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
