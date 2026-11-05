import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../app_controller.dart';
import '../../data/system_channel.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/permission_primer.dart';
import '../../theme/glass.dart';
import '../../theme/lucide.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import 'settings_widgets.dart';

/// One permission the app needs and whether the phone allows it right now.
class _Perm {
  const _Perm(this.icon, this.title, this.body, this.ok, this.fix);
  final IconData icon;
  final String title;
  final String body;
  final bool ok;
  final Future<void> Function() fix;
}

/// Settings → Permissions check: every permission YONCA needs, what is off, and a tap to fix it.
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> with WidgetsBindingObserver {
  bool _loaded = false;
  bool _notifications = true, _exact = true, _full = true, _contacts = true, _files = true, _install = true, _battery = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the phone's settings: read everything again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.controller.reminderPermissions();
      final full = await SystemChannel.canUseFullScreenIntent();
      final contacts = await SystemChannel.hasContactsPermission();
      final files = await SystemChannel.canManageStorage();
      final install = await SystemChannel.canInstallPackages();
      final battery = await SystemChannel.isIgnoringBatteryOptimizations();
      if (!mounted) return;
      setState(() {
        _notifications = p.notifications;
        _exact = p.exactAlarms;
        _full = full;
        _contacts = contacts;
        _files = files;
        _install = install;
        _battery = battery;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  /// Explains the permission on its own page, then runs [open] when the person agrees.
  Future<void> _explain(_Perm p, Future<void> Function() open) async {
    final l = AppLocalizations.of(context);
    if (await PermissionPrimer.show(context, icon: p.icon, title: p.title, body: p.body, primary: l.openPhoneSettings)) {
      await open();
      await _load();
    }
  }

  Future<void> _askContacts() async {
    var ok = false;
    try {
      ok = await FlutterContacts.requestPermission(readonly: false);
    } catch (_) {}
    // Refused for good: the phone no longer shows its question, so send the person to the app settings.
    if (!ok) await SystemChannel.openAppSettings();
  }

  List<_Perm> _needed(AppLocalizations l) {
    final c = widget.controller;
    return [
      _Perm(Lu.download, l.permInstall, l.permInstallBody, _install, SystemChannel.openInstallSettings),
      _Perm(Lu.bell, l.permNotifications, l.permNotifBody, _notifications, c.askReminderPermissions),
      _Perm(Lu.alarmClock, l.permExact, l.permExactBody, _exact, c.askReminderPermissions),
      _Perm(Lu.smartphone, l.permFull, l.permFullBody, _full, SystemChannel.openFullScreenSettings),
      _Perm(Lu.contact, l.permContacts, l.permContactsRowBody, _contacts, _askContacts),
      _Perm(Lu.database, l.permFiles, l.permFilesBody, _files, SystemChannel.openStorageSettings),
      _Perm(Lu.refreshCw, l.permBattery, l.permBatteryBody, _battery, SystemChannel.requestIgnoreBatteryOptimizations),
    ];
  }

  Future<void> _sendTest() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await widget.controller.sendTestReminder();
    messenger.showSnackBar(SnackBar(content: Text(l.testReminderSent)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final needed = _needed(l);
    final off = needed.where((x) => !x.ok).length;
    final allOk = off == 0;

    Widget chip(String text, bool ok) => Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
          decoration: BoxDecoration(color: ok ? p.surface2 : p.noticeBg, borderRadius: BorderRadius.circular(AppRadius.xs)),
          child: Text(text, style: TextStyle(fontSize: AppFont.badge, fontWeight: FontWeight.w600, color: ok ? p.text2 : p.noticeFg)),
        );

    Widget info(IconData icon, String title, String body, String chipText) {
      final item = _Perm(icon, title, body, true, SystemChannel.openAppSettings);
      return SettingsRow(icon: icon, title: title, trailing: chip(chipText, true), onTap: () => _explain(item, item.fix));
    }

    return SettingsScaffold(title: l.permCheckTitle, children: [
      if (_loaded)
        GlassCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(children: [
            IconTile(icon: allOk ? Lu.circleCheck : Lu.triangleAlert, background: allOk ? p.surface2 : p.noticeBg, color: allOk ? p.onPrimaryContainer : p.noticeFg),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(allOk ? l.permAllReady : l.permNeedAttention(off), style: const TextStyle(fontSize: AppFont.subtitle, height: AppLine.normal, fontWeight: FontWeight.w600)),
                Text(allOk ? l.permAllReadyBody : l.permNeedAttentionBody, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
              ]),
            ),
          ]),
        ),
      const SizedBox(height: AppSpace.lg),
      SectionLabel(l.permissionsLabel),
      SettingsGroup(children: [
        for (final x in needed)
          SettingsRow(
            icon: x.icon,
            title: x.title,
            trailing: chip(x.ok ? l.permAllowed : l.permFix, x.ok),
            onTap: x.ok ? null : () => _explain(x, x.fix),
          ),
      ]),
      SectionLabel(l.permOther),
      SettingsGroup(children: [
        info(Lu.settings, l.permBackground, l.permBackgroundBody, l.permCheckRow),
        info(Lu.camera, l.permCamera, l.permCameraBody, l.permAskedWhenNeeded),
        info(Lu.mic, l.permMic, l.permMicRowBody, l.permAskedWhenNeeded),
      ]),
      const SizedBox(height: AppSpace.lg),
      PillButton(label: l.testReminderBtn, icon: Lu.bell, height: AppControl.lg, outlined: true, onPressed: _sendTest),
    ]);
  }
}
