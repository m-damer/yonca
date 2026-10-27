import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../data/data_page.dart';
import '../fields/fields_page.dart';
import '../importing/profile_page.dart';
import '../stats/targets_page.dart';
import 'about_page.dart';
import '../../data/update_service.dart' show appVersion;
import 'settings_pages.dart';
import 'settings_widgets.dart';

class _Hub {
  const _Hub(this.icon, this.title, this.subtitle, this.keywords, this.page);
  final IconData icon;
  final String title;
  final String? subtitle;
  final String keywords;
  final Widget Function() page;
}

/// Settings hub (design G1): a search box and one row per settings page.
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

  Future<void> _reset() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.resetTitle),
        content: Text(l.resetBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.resetAll)),
        ],
      ),
    );
    if (ok != true) return;
    await c.resetSettings();
    messenger.showSnackBar(SnackBar(content: Text(l.resetDone)));
  }

  List<_Hub> _hubs(AppLocalizations l) {
    final lang = c.locale.languageCode == 'ar' ? 'العربية' : 'English';
    final digits = c.indicDigits ? l.digitsIndic : l.digitsWestern;
    final quiet = c.quietHoursOn
        ? '${TimeOfDay(hour: c.quietFrom ~/ 60, minute: c.quietFrom % 60).format(context)} – ${TimeOfDay(hour: c.quietTo ~/ 60, minute: c.quietTo % 60).format(context)}'
        : null;
    return [
      _Hub(Icons.palette_outlined, l.hubAppearance, l.hubAppearanceSub,
          '${l.settingAccent} ${l.settingTheme} ${l.settingHighContrast} ${l.settingArabicFont}', () => AppearancePage(controller: c)),
      _Hub(Icons.language, l.hubLanguage, '$lang · $digits · ${c.mainCurrency}',
          '${l.settingLanguage} ${l.settingMonths} ${l.settingDigits} ${l.settingMainCurrency}', () => LanguagePage(controller: c)),
      _Hub(Icons.notifications_outlined, l.hubNotif, quiet == null ? null : '${l.settingQuietHours} $quiet',
          '${l.settingQuietHours} ${l.settingAlarmTest} ${l.settingWeeklyUpdates}', () => NotificationsSettingsPage(controller: c)),
      _Hub(Icons.schedule, l.hubInact, l.hubInactSub(c.inactiveDays(Rating.hot), c.inactiveDays(Rating.warm), c.inactiveDays(Rating.cold)),
          l.inactIntro, () => InactivityPage(controller: c)),
      if (c.deals != null)
        _Hub(Icons.paid_outlined, l.hubDeals, l.hubDealsSub, '${l.settingMainCurrency} ${l.stagesTitle}', () => DealsSettingsPage(controller: c)),
      _Hub(Icons.home_outlined, l.hubHome, l.hubHomeSub, l.homeIntro, () => HomeSettingsPage(controller: c)),
      if (c.stats != null) _Hub(Icons.flag_outlined, l.hubTargets, null, l.targetsTitle, () => TargetsPage(stats: c.stats!)),
      if (c.database != null) _Hub(Icons.account_circle_outlined, l.profileTitle, null, l.profileName, () => ProfilePage(db: c.database!)),
      if (c.fields != null) _Hub(Icons.tune, l.customFieldsTitle, null, l.customFieldsTitle, () => FieldsPage(fields: c.fields!)),
      if (c.database != null) _Hub(Icons.lock_outline, l.hubData, null, l.dataTitle, () => DataPage(controller: c)),
      _Hub(Icons.info_outline, l.hubAbout, l.aboutVersion(appVersion), l.aboutTitle, () => AboutPage(controller: c)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final q = _query.trim().toLowerCase();
        final hubs = [
          for (final h in _hubs(l))
            if (q.isEmpty || '${h.title} ${h.keywords}'.toLowerCase().contains(q)) h
        ];
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: GlassField(controller: _search, label: l.settingsSearch, onChanged: (v) => setState(() => _query = v)),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
                  if (hubs.isEmpty)
                    Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l.settingsNone, style: TextStyle(color: p.text2))))
                  else
                    SettingsGroup(children: [
                      for (final h in hubs)
                        SettingsRow(
                          icon: h.icon,
                          title: h.title,
                          subtitle: h.subtitle,
                          chevron: true,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => h.page())),
                        ),
                    ]),
                  if (q.isEmpty) ...[
                    const SizedBox(height: 28),
                    Center(
                      child: TextButton(
                        onPressed: _reset,
                        child: Text(l.resetAll, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.error)),
                      ),
                    ),
                    Center(child: Text(l.resetNote, style: TextStyle(fontSize: 13, color: p.text2))),
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
