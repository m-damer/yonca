import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../app_controller.dart';
import '../../data/backup_runner.dart';
import '../../data/backup_service.dart';
import '../../data/drive_backup.dart';
import '../../data/system_channel.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/leaf_logo.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../importing/import_page.dart';
import '../settings/settings_widgets.dart' show SettingsGroup, SettingsRow;
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

/// First run: language, restore a backup (or start fresh), main currency, look, profile, import, reminders.
/// A restored backup skips the rest: it only needs the notification permission and a restart.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

enum _Rs { choose, working, done, failed }

class _OnboardingPageState extends State<OnboardingPage> {
  static const _steps = 7;
  int _step = 0;
  _Rs _rs = _Rs.choose;
  double _rp = 0;
  String _rError = '';
  String _rSource = '';
  late final BackupRunner _runner = BackupRunner(c);
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
    if (_step == 4) await _saveProfile();
    if (!mounted) return;
    if (_step == 5 && _importNow && c.contacts != null) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ImportPage(repo: c.contacts!)));
      if (!mounted) return;
    }
    if (_step == 6) {
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
                  Text(title, style: TextStyle(fontSize: AppFont.bodyL, fontWeight: AppWeight.semibold, color: p.text)),
                  if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: AppFont.meta, height: AppLine.loose, color: p.text2)),
                ]),
              ),
              if (check)
                selected
                    ? Container(
                        width: AppSize.s24,
                        height: AppSize.s24,
                        decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                        child: Icon(Lu.check, size: AppIcon.sm, color: p.onPrimary),
                      )
                    : Container(
                        width: AppSize.s24,
                        height: AppSize.s24,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.text2, width: AppStroke.thin)),
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
      width: AppSize.s44,
      height: AppControl.lg,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: AppFont.bodyL, fontWeight: AppWeight.bold, color: p.text),
        child: IconTheme(data: IconThemeData(size: AppSize.s22, color: p.text), child: child),
      ),
    );
  }

  Widget _heading(String title, String? body, {Widget? icon}) {
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (icon != null) ...[icon, const SizedBox(height: AppSpace.xxl)],
      Text(title, style: TextStyle(fontSize: AppFont.headline, height: AppLine.tight, fontWeight: AppWeight.bold, color: p.text)),
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
      const Padding(padding: EdgeInsets.only(top: AppSpace.sm), child: Align(alignment: AlignmentDirectional.centerStart, child: LeafLogo(size: AppSize.s54))),
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
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.meta, fontWeight: on ? AppWeight.semibold : AppWeight.medium, color: on ? p.text : p.text2))),
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
            Expanded(child: Text(l.sectionToday, style: TextStyle(fontSize: AppFont.subtitle, fontWeight: AppWeight.bold, color: p.text))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
              decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.xs)),
              child: Text(l.kindMeeting, style: TextStyle(fontSize: AppFont.badge, fontWeight: AppWeight.semibold, color: p.text2)),
            ),
          ]),
          const SizedBox(height: AppSpace.md),
          Row(children: [
          _tile(const Icon(Lu.users)),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Text(l.onbPreviewMeeting, style: const TextStyle(fontSize: AppFont.bodyL, fontWeight: AppWeight.medium))),
          Container(
            height: AppControl.md,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Lu.check, size: AppIcon.sm, color: p.onPrimary),
              const SizedBox(width: AppSpace.xs),
              Text(l.done, style: TextStyle(fontSize: AppFont.meta, fontWeight: AppWeight.semibold, color: p.onPrimary)),
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
            width: AppSize.s88,
            height: AppSize.s88,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.avBg, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: v.text.trim().isEmpty
                ? Icon(Lu.user, size: AppIcon.x3, color: p.avFg)
                : Text(
                    v.text.trim().characters.first.toUpperCase(),
                    style: TextStyle(fontSize: AppFont.amount, fontWeight: AppWeight.semibold, color: p.avFg),
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

  String _driveText(AppLocalizations l, Object e) {
    if (e is DriveException && e.problem == DriveProblem.offline) return l.driveOffline;
    final detail = e is DriveException ? e.detail : driveErrorDetail(e);
    return detail.isEmpty ? l.driveFailed : '${l.driveFailed}\n$detail';
  }

  void _fail(String text) {
    if (!mounted) return;
    setState(() {
      _rs = _Rs.failed;
      _rError = text;
    });
  }

  Future<String?> _askPw(String name, {bool wrong = false}) async {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final ctrl = TextEditingController();
    final r = await showGlassSheet<String>(
      context,
      builder: (ctx) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.enterBackupPw),
          Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.md), child: Text(name, textDirection: TextDirection.ltr, style: TextStyle(fontSize: AppFont.body, color: p.text2))),
          GlassField(controller: ctrl, label: l.pwLabel, obscure: true, autofocus: true, error: wrong ? l.pwWrong : null),
          const SizedBox(height: AppSpace.lg),
          SheetButtons(secondary: l.cancel, onSecondary: () => Navigator.of(ctx).pop(), primary: wrong ? l.stateRetry : l.restoreBackup, onPrimary: () => Navigator.of(ctx).pop(ctrl.text)),
        ]),
      ),
    );
    return r;
  }

  /// Restores from Google Drive (`drive`) or a file on the phone (`file`). The restore is staged and
  /// applied when the app starts again, so success here means "ready"; the Go to home button restarts.
  Future<void> _restore(String source) async {
    final l = AppLocalizations.of(context);
    _rSource = source;
    try {
      File file;
      String name;
      if (source == 'drive') {
        if (!await DriveBackup.online()) {
          _fail(l.driveOffline);
          return;
        }
        setState(() {
          _rs = _Rs.working;
          _rp = 0;
        });
        final drive = _runner.drive;
        final email = await drive.connect();
        if (email == null) {
          if (mounted) setState(() => _rs = _Rs.choose);
          return;
        }
        await c.setPref(AppController.keyDriveEmail, email);
        final info = await drive.latest();
        if (info == null) {
          _fail(l.driveNoBackup);
          return;
        }
        final tmp = await getTemporaryDirectory();
        file = await drive.download(info, File('${tmp.path}/${info.name.isEmpty ? 'yonca-drive.zip' : info.name}'), onProgress: (v) {
          if (mounted) setState(() => _rp = v * .8);
        });
        name = info.name;
      } else {
        final res = await FilePicker.platform.pickFiles(type: FileType.any);
        final path = res?.files.single.path;
        if (path == null || !mounted) return;
        file = File(path);
        name = res!.files.single.name;
        setState(() {
          _rs = _Rs.working;
          _rp = .1;
        });
      }
      final svc = await _runner.service();
      String? pw;
      var wrong = false;
      while (true) {
        if (svc.needsPassword(file)) {
          pw = await _askPw(name, wrong: wrong);
          if (pw == null || !mounted) {
            if (mounted) setState(() => _rs = _Rs.choose);
            return;
          }
        }
        try {
          await svc.inspect(file, password: pw);
          break;
        } on BackupException catch (e) {
          if (e.problem == 'wrong_password') {
            wrong = true;
            continue;
          }
          _fail(l.notABackup);
          return;
        }
      }
      if (mounted) setState(() => _rp = .85);
      await svc.stageRestoreInBackground(file, password: pw);
      if (mounted) {
        setState(() {
          _rp = 1;
          _rs = _Rs.done;
        });
      }
    } catch (e) {
      _fail(source == 'drive' ? _driveText(l, e) : l.notABackup);
    }
  }

  Future<void> _goHomeRestored() async {
    await c.allowNotifications();
    await SystemChannel.restartApp();
  }

  Future<void> _skipToHome() async {
    await c.completeOnboarding();
  }

  Widget _restoreChoose(AppLocalizations l) {
    final p = context.palette;
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.x4, AppSpace.xxl, AppSpace.sm), children: [
      _heading(l.onbRestoreTitle, l.onbRestoreBody, icon: _bigIcon(Lu.history)),
      _choice(leading: _tile(const Icon(Lu.cloud)), title: l.onbRestoreDrive, subtitle: l.onbRestoreDriveSub, selected: false, check: false, onTap: () => _restore('drive')),
      _choice(leading: _tile(const Icon(Lu.fileText)), title: l.onbRestoreFile, subtitle: l.onbRestoreFileSub, selected: false, check: false, onTap: () => _restore('file')),
      Padding(padding: const EdgeInsets.only(top: AppSpace.sm), child: Text(l.onbRestoreLater, style: TextStyle(fontSize: AppFont.meta, height: AppLine.loose, color: p.text2))),
    ]);
  }

  /// Full-screen states while a backup is restored: working, ready, failed.
  Widget _restoreView(AppLocalizations l) {
    final p = context.palette;
    final working = _rs == _Rs.working;
    final done = _rs == _Rs.done;
    return Scaffold(
      body: GlassBackdrop(
        child: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.x4, AppSpace.xxl, AppSpace.sm), children: [
                const SizedBox(height: AppSpace.x4),
                IconTile(
                  icon: working ? Lu.history : (done ? Lu.check : Lu.triangleAlert),
                  size: AppControl.hero,
                  iconSize: AppIcon.x3,
                  background: _rs == _Rs.failed ? p.errorContainer : p.surface2,
                  color: _rs == _Rs.failed ? p.onErrorContainer : p.primary,
                ),
                const SizedBox(height: AppSpace.xxl),
                Text(
                  working ? l.onbRestoringTitle : (done ? l.onbRestoredTitle : l.onbRestoreFailedTitle),
                  style: TextStyle(fontSize: AppFont.headline, height: AppLine.tight, fontWeight: AppWeight.bold, color: p.text),
                ),
                const SizedBox(height: AppSpace.sm),
                if (working) ...[
                  const SizedBox(height: AppSpace.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(value: _rp > 0 ? _rp : null, minHeight: AppSize.s8, backgroundColor: p.separator, color: p.primary),
                  ),
                ] else if (done)
                  Text(l.onbRestoredBody, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: p.text2))
                else ...[
                  Text(_rError, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: p.text2)),
                  const SizedBox(height: AppSpace.lg),
                  Text(l.onbRestoreLater, style: TextStyle(fontSize: AppFont.meta, height: AppLine.loose, color: p.text2)),
                ],
              ]),
            ),
            if (done)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.sm, AppSpace.xxl, AppSpace.xl),
                child: PillButton(label: l.onbGoHome, onPressed: _goHomeRestored),
              ),
            if (_rs == _Rs.failed) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.sm, AppSpace.xxl, AppSpace.xs),
                child: PillButton(label: l.onbTryAgain, onPressed: () => _restore(_rSource)),
              ),
              TextButton(onPressed: _skipToHome, child: Text(l.onbSkipToHome, style: TextStyle(fontWeight: AppWeight.semibold, color: p.primary))),
              const SizedBox(height: AppSpace.xs),
            ],
          ]),
        ),
      ),
    );
  }

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
    if (_rs != _Rs.choose) return PopScope(canPop: false, child: _restoreView(l));
    final last = _step == _steps - 1;
    final body = switch (_step) {
      0 => _language(l),
      1 => _restoreChoose(l),
      2 => _currency(l),
      3 => _theme(l),
      4 => _profile(l),
      5 => _import(l),
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
                  width: AppSize.s44,
                  child: _step == 0
                      ? null
                      : GlassIconButton(icon: Lu.chevronLeft, tooltip: l.onbBack, size: AppSize.s44, onTap: () => setState(() => _step--)),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Row(children: [
                    for (var i = 0; i < _steps; i++)
                      Expanded(
                        child: Container(
                          height: AppSize.s4,
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
              child: PillButton(label: last ? l.onbAllow : (_step == 1 ? l.onbStartFresh : l.onbNext), onPressed: _next),
            ),
            if (_step == 1)
              const SizedBox(height: AppSpace.xl)
            else
              TextButton(
                onPressed: _finish,
                child: Text(last ? l.onbNotNow : l.onbSkip, style: TextStyle(fontWeight: AppWeight.semibold, color: p.primary)),
              ),
            const SizedBox(height: AppSpace.xs),
          ]),
        ),
      ),
    );
  }
}
