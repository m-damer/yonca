import 'package:flutter/material.dart';

import '../../shared/ds.dart';

import '../../app_controller.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../data/data_page.dart';
import '../schedule/schedule_labels.dart' show formatClock;
import '../stats/targets_page.dart';
import 'about_page.dart';
import '../../data/update_service.dart' show appVersion;
import 'call_card_page.dart';
import 'permissions_page.dart';
import 'settings_pages.dart';
import 'settings_widgets.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

class _Hub {
  const _Hub(this.group, this.icon, this.title, this.subtitle, this.keywords, this.page);
  final int group;
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
    final ok = await showSheetDialog<bool>(
      context: context,
      builder: (ctx) => SheetDialog(
        title: Text(l.resetTitle),
        content: Text(l.resetBody),
        actions: [
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.resetAll, onPressed: () => Navigator.of(ctx).pop(true), danger: true),
        ],
      ),
    );
    if (ok != true) return;
    await c.resetSettings();
    messenger.showSnackBar(SnackBar(content: Text(l.resetDone)));
  }

  List<_Hub> _hubs(AppLocalizations l) {
    final lang = c.locale.languageCode == 'ar' ? 'العربية' : 'English';
    final digits = c.indicDigits ? l.digitsIndicShort : l.digitsWesternShort;
    final quiet = c.quietHoursOn
        ? l.quietRange(formatClock(context, DateTime(2000, 1, 1, c.quietFrom ~/ 60, c.quietFrom % 60)), formatClock(context, DateTime(2000, 1, 1, c.quietTo ~/ 60, c.quietTo % 60)))
        : null;
    return [
      _Hub(0, Lu.globe, l.hubLanguage, '$lang · $digits · ${c.mainCurrency}',
          '${l.settingLanguage} ${l.settingMonths} ${l.settingDigits} ${l.settingMainCurrency}', () => LanguagePage(controller: c)),
      _Hub(0, Lu.palette, l.hubAppearance, l.hubAppearanceSub,
          '${l.settingAccent} ${l.settingTheme} ${l.settingHighContrast} ${l.settingArabicFont}', () => AppearancePage(controller: c)),
      _Hub(1, Lu.bell, l.hubNotif, quiet,
          '${l.settingQuietHours} ${l.settingHideLock} ${l.permissionsLabel}', () => NotificationsSettingsPage(controller: c)),
      _Hub(1, Lu.circleCheck, l.permCheckTitle, l.permCheckSub, '${l.permCheckTitle} ${l.permNotifications} ${l.permContacts} ${l.permInstall} ${l.permBattery}', () => PermissionsPage(controller: c)),
      _Hub(1, Lu.phoneCall, l.callCardTitle, l.callCardSub, '${l.callCardTitle} ${l.callCardSwitch} ${l.callCardPhonePerm}', () => CallCardPage(controller: c)),
      _Hub(1, Lu.clock, l.hubInact, l.hubInactSub(c.inactiveDays(Rating.hot), c.inactiveDays(Rating.warm), c.inactiveDays(Rating.cold)),
          l.inactIntro, () => InactivityPage(controller: c)),
      if (c.deals != null)
        _Hub(2, Lu.banknote, l.navDeals, l.hubDealsSub, '${l.settingMainCurrency} ${l.stagesTitle}', () => DealsSettingsPage(controller: c)),
      _Hub(2, Lu.house, l.hubHome, l.hubHomeSub, l.homeIntro, () => HomeSettingsPage(controller: c)),
      if (c.stats != null) _Hub(2, Lu.target, l.hubTargets, l.hubTargetsSub, l.targetsTitle, () => TargetsPage(stats: c.stats!, onChanged: c.resyncReminders)),
      if (c.database != null) _Hub(3, Lu.lock, l.hubData, null, l.dataTitle, () => DataPage(controller: c)),
      _Hub(4, Lu.info, l.hubAbout, l.aboutHubSub(appVersion), l.aboutTitle, () => AboutPage(controller: c)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final groups = [(0, l.groupGeneral), (1, l.groupAlerts), (2, l.moreWork), (3, l.groupData), (4, l.hubAbout)];
        final q = _query.trim().toLowerCase();
        final hubs = [
          for (final h in _hubs(l))
            if (q.isEmpty || '${h.title} ${h.keywords}'.toLowerCase().contains(q)) h
        ];
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: GlassBackdrop(
            child: Column(children: [
              PageHeader(title: l.settingsTitle),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.sm),
                child: SearchPill(controller: _search, hint: l.settingsSearch, onChanged: (v) => setState(() => _query = v)),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.x4), children: [
                  if (hubs.isEmpty)
                    Padding(padding: const EdgeInsets.all(AppSpace.x4), child: Center(child: Text(l.settingsNone, style: TextStyle(color: p.text2))))
                  else
                    for (final g in groups)
                      if (hubs.any((h) => h.group == g.$1)) ...[
                        SectionLabel(g.$2),
                        SettingsGroup(children: [
                          for (final h in hubs.where((h) => h.group == g.$1))
                            SettingsRow(
                              icon: h.icon,
                              title: h.title,
                              subtitle: h.subtitle,
                              chevron: true,
                              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => h.page())),
                            ),
                        ]),
                      ],
                  if (q.isEmpty) ...[
                    const SizedBox(height: AppSpace.x3),
                    Center(
                      child: TextButton(
                        onPressed: _reset,
                        child: Text(l.resetAll, style: TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.semibold, color: p.error)),
                      ),
                    ),
                    Center(child: Text(l.resetNote, style: TextStyle(fontSize: AppFont.meta, color: p.text2))),
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
