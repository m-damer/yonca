import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../data/call_card_sync.dart';
import '../../data/system_channel.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/permission_primer.dart';
import '../../theme/lucide.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import 'settings_widgets.dart';

/// Writes the card's switch, language and texts for the Android side (also called when the app starts or the language changes).
Future<void> refreshCallCard(BuildContext context, AppController c) {
  final l = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context);
  return syncCallCard(l, enabled: c.flag(AppController.keyCallCard), rtl: Directionality.of(context) == TextDirection.rtl, lang: locale.languageCode);
}

/// Settings → Incoming call card: the switch, the two permissions it needs, and a preview.
class CallCardPage extends StatefulWidget {
  const CallCardPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<CallCardPage> createState() => _CallCardPageState();
}

class _CallCardPageState extends State<CallCardPage> with WidgetsBindingObserver {
  bool _phone = false, _overlay = false, _loaded = false;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final s = await SystemChannel.callCardStatus();
    if (!mounted) return;
    setState(() {
      _phone = s.phone;
      _overlay = s.overlay;
      _loaded = true;
    });
    await refreshCallCard(context, widget.controller);
  }

  Future<void> _askPhone() async {
    final ok = await SystemChannel.requestCallPermissions();
    // Refused for good: the phone no longer shows its question, so send the person to the app settings.
    if (!ok) await SystemChannel.openAppSettings();
    await _load();
  }

  Future<void> _askOverlay() async {
    final l = AppLocalizations.of(context);
    if (await PermissionPrimer.show(context, icon: Lu.smartphone, title: l.callCardOverlayPerm, body: l.callCardOverlayPermBody, primary: l.openPhoneSettings)) {
      await SystemChannel.openOverlaySettings();
    }
    await _load();
  }

  Future<void> _toggle(bool on) async {
    final c = widget.controller;
    await c.setFlag(AppController.keyCallCard, on);
    if (on && !_phone) await _askPhone();
    if (on && !_overlay) await _askOverlay();
    if (!mounted) return;
    await refreshCallCard(context, c);
    setState(() {});
  }

  Future<void> _preview() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await refreshCallCard(context, widget.controller);
    if (!_overlay) {
      messenger.showSnackBar(SnackBar(content: Text(l.callCardNeedOverlay)));
      return;
    }
    final shown = await SystemChannel.previewCallCard();
    if (!shown) messenger.showSnackBar(SnackBar(content: Text(l.callCardPreviewNone)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final on = widget.controller.flag(AppController.keyCallCard);

    Widget chip(bool ok) => Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
          decoration: BoxDecoration(color: ok ? p.surface2 : p.noticeBg, borderRadius: BorderRadius.circular(AppRadius.xs)),
          child: Text(ok ? l.permAllowed : l.permFix, style: TextStyle(fontSize: AppFont.badge, fontWeight: AppWeight.semibold, color: ok ? p.text2 : p.noticeFg)),
        );

    return SettingsScaffold(title: l.callCardTitle, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.lg),
        child: Text(l.callCardIntro, style: TextStyle(fontSize: AppFont.label, height: AppLine.loose, color: p.text2)),
      ),
      SettingsGroup(children: [
        SettingsSwitch(title: l.callCardSwitch, value: on, onChanged: _toggle),
      ]),
      if (_loaded) ...[
        SectionLabel(l.permissionsLabel),
        SettingsGroup(children: [
          SettingsRow(icon: Lu.phone, title: l.callCardPhonePerm, subtitle: l.callCardPhonePermBody, trailing: chip(_phone), onTap: _phone ? null : _askPhone),
          SettingsRow(icon: Lu.smartphone, title: l.callCardOverlayPerm, subtitle: l.callCardOverlayPermBody, trailing: chip(_overlay), onTap: _overlay ? null : _askOverlay),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.md, AppSpace.xs, AppSpace.lg),
          child: Text(l.callCardPhoneNote, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
        ),
      ],
      PillButton(label: l.callCardPreview, icon: Lu.phoneCall, height: AppControl.lg, outlined: true, onPressed: _preview),
    ]);
  }
}
