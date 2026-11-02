import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/leaf_logo.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../importing/import_page.dart';
import '../settings/settings_widgets.dart' show SettingsGroup, SettingsRow;
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

/// First run (design A1–A8): language, main currency, look, profile, import, reminders.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _steps = 6;
  int _step = 0;
  bool _importNow = false;
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _phone = TextEditingController();

  AppController get c => widget.controller;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final db = c.database;
    if (db == null) return;
    for (final e in {'profile.name': _name, 'profile.company': _company, 'profile.phone': _phone}.entries) {
      final v = e.value.text.trim();
      if (v.isNotEmpty) await db.putSetting(e.key, v);
    }
  }

  Future<void> _finish() => c.completeOnboarding();

  Future<void> _next() async {
    if (_step == 3) await _saveProfile();
    if (!mounted) return;
    if (_step == 4 && _importNow && c.contacts != null) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ImportPage(repo: c.contacts!)));
      if (!mounted) return;
    }
    if (_step == 5) {
      await c.allowNotifications();
      await _finish();
      return;
    }
    setState(() => _step++);
  }

  Widget _choice({
    required Widget leading,
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool check = true,
  }) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Material(
        color: p.glass,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: selected ? p.primary : p.glassBorder, width: selected ? 2 : 1),
            ),
            child: Row(children: [
              leading,
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: AppFont.bodyL, fontWeight: FontWeight.w600, color: p.text)),
                  if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: AppFont.meta, height: AppLine.loose, color: p.text2)),
                ]),
              ),
              if (check)
                selected
                    ? Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                        child: Icon(Lu.check, size: AppIcon.sm, color: p.onPrimary),
                      )
                    : Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.text2, width: 1.5)),
                      ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tile(Widget child) {
    final p = context.palette;
    return Container(
      width: 44,
      height: AppControl.lg,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: AppFont.bodyL, fontWeight: FontWeight.w700, color: p.text),
        child: IconTheme(data: IconThemeData(size: 22, color: p.text), child: child),
      ),
    );
  }

  Widget _heading(String title, String? body, {Widget? icon}) {
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (icon != null) ...[icon, const SizedBox(height: AppSpace.xxl)],
      Text(title, style: TextStyle(fontSize: AppFont.headline, height: AppLine.tight, fontWeight: FontWeight.w700, color: p.text)),
      if (body != null) ...[
        const SizedBox(height: AppSpace.sm),
        Text(body, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: p.text2)),
      ],
      const SizedBox(height: AppSpace.x3),
    ]);
  }

  Widget _language(AppLocalizations l) {
    final ar = c.locale.languageCode == 'ar';
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.x4, AppSpace.xxl, AppSpace.sm), children: [
      const Padding(padding: EdgeInsets.only(top: AppSpace.sm), child: Align(alignment: AlignmentDirectional.centerStart, child: LeafLogo(size: 54))),
      const SizedBox(height: AppSpace.xxl),
      _heading(l.onbWelcome, l.onbChooseLanguage),
      _choice(
        leading: _tile(const Text('En')),
        title: 'English',
        subtitle: l.onbLtr,
        selected: !ar,
        onTap: () => c.setLocale(const Locale('en')),
      ),
      _choice(
        leading: _tile(const Text('ع')),
        title: 'العربية',
        subtitle: l.onbRtl,
        selected: ar,
        onTap: () => c.setLocale(const Locale('ar')),
      ),
    ]);
  }

  Widget _currency(AppLocalizations l) {
    final cur = c.mainCurrency;
    Widget row(String code, String sym, String name) => _choice(
          leading: _tile(Text(sym)),
          title: code,
          subtitle: name,
          selected: cur == code,
          onTap: () => c.setMainCurrency(code),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.x4, AppSpace.xxl, AppSpace.sm), children: [
      _heading(l.onbCurrencyTitle, l.onbCurrencyBody),
      row('USD', r'$', l.onbCurUsd),
      row('SYP', 'SYP', l.onbCurSyp),
      row('EUR', '€', l.onbCurEur),
    ]);
  }

  Widget _theme(AppLocalizations l) {
    final p = context.palette;
    final mode = c.themeMode;
    Widget seg(ThemeMode m, String label, IconData icon) {
      final on = mode == m;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => c.setThemeMode(m),
          child: Container(
            height: AppControl.md,
            decoration: BoxDecoration(color: on ? p.glass : null, borderRadius: BorderRadius.circular(AppRadius.sm), border: on ? Border.all(color: p.glassBorder) : null),
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: AppIcon.sm, color: on ? p.text : p.text2),
              const SizedBox(width: AppSpace.xs),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.meta, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? p.text : p.text2))),
            ]),
          ),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.x4, AppSpace.xxl, AppSpace.sm), children: [
      _heading(l.onbThemeTitle, l.onbThemeBody),
      SectionLabel(l.onbMode, padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.sm, AppSpace.xs, AppSpace.sm)),
      Container(
        padding: const EdgeInsets.all(AppSpace.xs),
        decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(children: [
          seg(ThemeMode.system, l.themeSystem, Lu.smartphone),
          seg(ThemeMode.light, l.themeLight, Lu.sun),
          seg(ThemeMode.dark, l.themeDark, Lu.moon),
        ]),
      ),
      const SizedBox(height: AppSpace.lg),
      GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.lg),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(l.sectionToday, style: TextStyle(fontSize: AppFont.subtitle, fontWeight: FontWeight.w700, color: p.text))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
              decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.xs)),
              child: Text(l.kindMeeting, style: TextStyle(fontSize: AppFont.badge, fontWeight: FontWeight.w600, color: p.text2)),
            ),
          ]),
          const SizedBox(height: AppSpace.md),
          Row(children: [
          _tile(const Icon(Lu.users)),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Text(l.onbPreviewMeeting, style: const TextStyle(fontSize: AppFont.bodyL, fontWeight: FontWeight.w500))),
          Container(
            height: AppControl.md,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Lu.check, size: AppIcon.sm, color: p.onPrimary),
              const SizedBox(width: AppSpace.xs),
              Text(l.done, style: TextStyle(fontSize: AppFont.meta, fontWeight: FontWeight.w600, color: p.onPrimary)),
            ]),
          ),
        ]),
        ]),
      ),
    ]);
  }

  Widget _profile(AppLocalizations l) {
    final p = context.palette;
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.x4, AppSpace.xxl, AppSpace.sm), children: [
      _heading(l.onbProfileTitle, l.onbProfileBody),
      Center(
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (_, v, __) => Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.avBg, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: v.text.trim().isEmpty
                ? Icon(Lu.user, size: AppIcon.x3, color: p.avFg)
                : Text(
                    v.text.trim().characters.first.toUpperCase(),
                    style: TextStyle(fontSize: AppFont.amount, fontWeight: FontWeight.w600, color: p.avFg),
                  ),
          ),
        ),
      ),
      const SizedBox(height: AppSpace.xl),
      GlassField(controller: _name, label: l.fieldName),
      const SizedBox(height: AppSpace.md),
      GlassField(controller: _company, label: l.fieldCompany),
      const SizedBox(height: AppSpace.md),
      GlassField(controller: _phone, label: l.fieldPhone, keyboardType: TextInputType.phone),
    ]);
  }

  Widget _import(AppLocalizations l) => ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.x4, AppSpace.xxl, AppSpace.sm), children: [
        _heading(l.onbImportTitle, l.onbImportBody, icon: _bigIcon(Lu.users)),
        _choice(
          leading: _tile(const Icon(Lu.download)),
          title: l.onbImportNow,
          subtitle: l.onbImportNowBody,
          selected: _importNow,
          onTap: () => setState(() => _importNow = true),
        ),
        _choice(
          leading: _tile(const Icon(Lu.clock)),
          title: l.onbLater,
          subtitle: l.onbLaterBody,
          selected: !_importNow,
          onTap: () => setState(() => _importNow = false),
        ),
      ]);

  Widget _bigIcon(IconData i) {
    return IconTile(icon: i, size: AppControl.hero, iconSize: AppIcon.x3);
  }

  Widget _reminders(AppLocalizations l) {
    Widget row(IconData i, String t, String sub) => SettingsRow(icon: i, title: t, subtitle: sub);
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.x4, AppSpace.xxl, AppSpace.sm), children: [
      _heading(l.onbRemindersTitle, l.onbRemindersBody, icon: _bigIcon(Lu.bell)),
      const SizedBox(height: AppSpace.xs),
      SettingsGroup(children: [
        row(Lu.bell, l.onbNotifications, l.onbNotificationsBody),
        row(Lu.alarmClock, l.onbAlarms, l.onbAlarmsBody),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final last = _step == _steps - 1;
    final body = switch (_step) {
      0 => _language(l),
      1 => _currency(l),
      2 => _theme(l),
      3 => _profile(l),
      4 => _import(l),
      _ => _reminders(l),
    };
    return Scaffold(
      body: GlassBackdrop(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, 0),
              child: Row(children: [
                SizedBox(
                  width: 44,
                  child: _step == 0
                      ? null
                      : GlassIconButton(icon: Lu.chevronLeft, tooltip: l.onbBack, size: 44, onTap: () => setState(() => _step--)),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Row(children: [
                    for (var i = 0; i < _steps; i++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                          decoration: BoxDecoration(color: i <= _step ? p.primary : p.track, borderRadius: BorderRadius.circular(AppRadius.xxs)),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
            Expanded(child: body),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.sm, AppSpace.xxl, AppSpace.xs),
              child: PillButton(label: last ? l.onbAllow : l.onbNext, onPressed: _next),
            ),
            TextButton(
              onPressed: _finish,
              child: Text(last ? l.onbNotNow : l.onbSkip, style: TextStyle(fontWeight: FontWeight.w600, color: p.primary)),
            ),
            const SizedBox(height: AppSpace.xs),
          ]),
        ),
      ),
    );
  }
}
