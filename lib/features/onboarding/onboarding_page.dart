import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/leaf_logo.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../importing/import_page.dart';

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
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.glass,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? p.primary : p.glassBorder, width: selected ? 2 : 1),
            ),
            child: Row(children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
                  if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 12.5, height: 1.3, color: p.text2)),
                ]),
              ),
              if (check)
                selected
                    ? Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                        child: Icon(Icons.check, size: 16, color: p.onPrimary),
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
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(8)),
      child: DefaultTextStyle(
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.onPrimaryContainer),
        child: IconTheme(data: IconThemeData(size: 22, color: p.onPrimaryContainer), child: child),
      ),
    );
  }

  Widget _heading(String title, String? body, {Widget? icon}) {
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (icon != null) ...[icon, const SizedBox(height: 20)],
      Text(title, style: TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w700, color: p.text)),
      if (body != null) ...[
        const SizedBox(height: 8),
        Text(body, style: TextStyle(fontSize: 14.5, height: 1.4, color: p.text2)),
      ],
      const SizedBox(height: 20),
    ]);
  }

  Widget _language(AppLocalizations l) {
    final ar = c.locale.languageCode == 'ar';
    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 8), children: [
      const Align(alignment: AlignmentDirectional.centerStart, child: LeafLogo(size: 52)),
      const SizedBox(height: 20),
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
    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 8), children: [
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
          borderRadius: BorderRadius.circular(8),
          onTap: () => c.setThemeMode(m),
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: on ? p.primary : null, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: on ? p.onPrimary : p.text),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? p.onPrimary : p.text)),
            ]),
          ),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 8), children: [
      _heading(l.onbThemeTitle, l.onbThemeBody),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(l.onbMode, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.text2)),
      ),
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: p.glass, borderRadius: BorderRadius.circular(8), border: Border.all(color: p.glassBorder)),
        child: Row(children: [
          seg(ThemeMode.system, l.themeSystem, Icons.phone_android),
          seg(ThemeMode.light, l.themeLight, Icons.light_mode_outlined),
          seg(ThemeMode.dark, l.themeDark, Icons.dark_mode_outlined),
        ]),
      ),
      const SizedBox(height: 16),
      GlassCard(
        child: Row(children: [
          _tile(const Icon(Icons.groups_outlined)),
          const SizedBox(width: 12),
          Expanded(child: Text(l.onbPreviewMeeting, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check, size: 16, color: p.onPrimary),
              const SizedBox(width: 4),
              Text(l.done, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.onPrimary)),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _profile(AppLocalizations l) {
    final p = context.palette;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 8), children: [
      _heading(l.onbProfileTitle, l.onbProfileBody),
      Center(
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (_, v, __) => Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(8)),
            child: Text(
              v.text.trim().isEmpty ? '' : v.text.trim().characters.first.toUpperCase(),
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: p.onPrimary),
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      GlassField(controller: _name, label: l.fieldName),
      const SizedBox(height: 12),
      GlassField(controller: _company, label: l.fieldCompany),
      const SizedBox(height: 12),
      GlassField(controller: _phone, label: l.fieldPhone, keyboardType: TextInputType.phone),
    ]);
  }

  Widget _import(AppLocalizations l) => ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 8), children: [
        _heading(l.onbImportTitle, l.onbImportBody, icon: _bigIcon(Icons.groups_outlined)),
        _choice(
          leading: _tile(const Icon(Icons.download_outlined)),
          title: l.onbImportNow,
          subtitle: l.onbImportNowBody,
          selected: _importNow,
          onTap: () => setState(() => _importNow = true),
        ),
        _choice(
          leading: _tile(const Icon(Icons.schedule)),
          title: l.onbLater,
          subtitle: l.onbLaterBody,
          selected: !_importNow,
          onTap: () => setState(() => _importNow = false),
        ),
      ]);

  Widget _bigIcon(IconData i) {
    final p = context.palette;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Icon(i, size: 30, color: p.onPrimaryContainer),
    );
  }

  Widget _reminders(AppLocalizations l) {
    final p = context.palette;
    Widget row(IconData i, String t, String s) => Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _tile(Icon(i)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(s, style: TextStyle(fontSize: 12.5, height: 1.3, color: p.text2)),
              ]),
            ),
          ]),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 8), children: [
      _heading(l.onbRemindersTitle, l.onbRemindersBody, icon: _bigIcon(Icons.notifications_none)),
      GlassCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          row(Icons.notifications_none, l.onbNotifications, l.onbNotificationsBody),
          Divider(height: 1, color: p.glassBorder),
          row(Icons.alarm, l.onbAlarms, l.onbAlarmsBody),
        ]),
      ),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 0),
              child: Row(children: [
                SizedBox(
                  width: 40,
                  child: _step == 0
                      ? null
                      : GlassIconButton(icon: Icons.arrow_back, tooltip: l.onbBack, size: 40, onTap: () => setState(() => _step--)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(children: [
                    for (var i = 0; i < _steps; i++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(color: i <= _step ? p.primary : p.track, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
            Expanded(child: body),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: PillButton(label: last ? l.onbAllow : l.onbNext, onPressed: _next),
            ),
            TextButton(
              onPressed: _finish,
              child: Text(last ? l.onbNotNow : l.onbSkip, style: TextStyle(fontWeight: FontWeight.w600, color: p.primary)),
            ),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }
}
