import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/update_scheduler.dart';

import '../../shared/ds.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_controller.dart';
import '../../core/developer.dart';
import '../../data/update_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/leaf_logo.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'settings_widgets.dart' show SettingsGroup, SettingsRow, SettingsSwitch;
import 'error_log_page.dart';
import 'test_data_sheet.dart';
import 'updates_page.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

/// About YONCA (design AB1): version, updates, privacy, feedback and the developer.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(title: l.aboutTitle),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.xxl), children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.md, bottom: AppSpace.xl),
                child: Column(children: [
                  const LeafLogo(size: 134, gap: 6, radius: 28),
                  const SizedBox(height: AppSpace.md),
                  Text('YONCA',
                      style: TextStyle(fontSize: AppFont.pageTitle, fontWeight: FontWeight.w700, letterSpacing: 6, color: p.text)),
                  _VersionLabel(text: l.aboutVersion(appVersionLabel), onSevenTaps: () => showTestDataSheet(context, controller)),
                ]),
              ),
              SettingsGroup(children: [
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final checked = controller.pref(AppController.keyLastUpdateCheck) != null;
                    final newer = (controller.pref(AppController.keyUpdateAvailable) ?? '').isNotEmpty;
                    return SettingsRow(
                      icon: Lu.refreshCw,
                      title: l.aboutUpdates,
                      value: !checked ? null : (newer ? l.aboutUpdateAvailable : l.aboutUpToDate),
                      chevron: true,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => UpdatesPage(controller: controller))),
                    );
                  },
                ),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => SettingsSwitch(
                    title: l.settingWeeklyUpdates,
                    subtitle: l.settingWeeklyUpdatesHint,
                    value: controller.weeklyUpdateCheck,
                    onChanged: (v) async {
                      await controller.setFlag(AppController.keyWeeklyUpdate, v);
                      unawaited(UpdateScheduler.sync(controller));
                    },
                  ),
                ),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => SettingsSwitch(
                    title: l.settingAutoUpdate,
                    subtitle: l.settingAutoUpdateHint,
                    value: controller.autoUpdateDownload,
                    onChanged: (v) async {
                      await controller.setFlag(AppController.keyAutoUpdate, v);
                      unawaited(UpdateScheduler.sync(controller));
                    },
                  ),
                ),
              ]),
              const SizedBox(height: AppSpace.md),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.lg),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.aboutPrivacyTitle, style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
                  const SizedBox(height: AppSpace.xs),
                  Text(l.aboutPrivacyText, style: TextStyle(fontSize: AppFont.label, color: p.text2)),
                ]),
              ),
              const SizedBox(height: AppSpace.md),
              SettingsGroup(children: [
                SettingsRow(
                  icon: Lu.mail,
                  title: l.aboutFeedback,
                  subtitle: l.aboutFeedbackSub,
                  chevron: true,
                  onTap: () => _open(Uri(scheme: 'mailto', path: developerEmail, queryParameters: {'subject': 'YONCA $appVersion'})),
                ),
                SettingsRow(
                  icon: Lu.fileText,
                  title: l.logTitle,
                  subtitle: l.logSub,
                  chevron: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ErrorLogPage())),
                ),
                SettingsRow(
                  icon: Lu.user,
                  title: l.aboutDeveloper,
                  chevron: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DeveloperPage())),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xxl),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: l.aboutMadePre),
                    WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Lu.heart, size: AppIcon.sm, color: p.error)),
                    TextSpan(text: l.aboutMadePost),
                  ]),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: AppFont.meta, color: p.text2),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<void> _open(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// About the developer (design AB2).
class DeveloperPage extends StatelessWidget {
  const DeveloperPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    Widget link(IconData icon, String label, Uri? uri) => Expanded(
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: uri == null ? null : () => _open(uri),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
                  child: Row(children: [
                    Icon(icon, size: AppIcon.lg, color: p.text),
                    const SizedBox(width: AppSpace.md),
                    Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w500, color: p.text))),
                  ]),
                ),
              ),
            ),
          ),
        );
    Uri? web(String s) => s.isEmpty ? null : Uri.tryParse(s.startsWith('http') ? s : 'https://$s');
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(title: l.aboutDeveloper),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.xxl), children: [
              const SizedBox(height: AppSpace.sm),
              Center(
                child: Container(
                  width: 160,
                  height: 160,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.surface2, shape: BoxShape.circle),
                  child: Text(l.aboutDevInitials, style: TextStyle(fontSize: AppFont.hero, fontWeight: FontWeight.w700, color: p.text)),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(l.aboutDevName, textAlign: TextAlign.center, style: TextStyle(fontSize: AppFont.headline, fontWeight: FontWeight.w700, color: p.text)),
              Text(l.aboutDevRole, textAlign: TextAlign.center, style: TextStyle(color: p.text2)),
              const SizedBox(height: AppSpace.lg),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.lg),
                child: Text(l.aboutDevBio, style: TextStyle(color: p.text2)),
              ),
              const SizedBox(height: AppSpace.md),
              Row(children: [
                link(Lu.mail, l.aboutDevEmail, developerEmail.isEmpty ? null : Uri(scheme: 'mailto', path: developerEmail)),
                const SizedBox(width: AppSpace.md),
                link(Lu.messageCircle, l.aboutDevWhatsApp, developerWhatsApp.isEmpty ? null : Uri.parse('https://wa.me/$developerWhatsApp')),
              ]),
              const SizedBox(height: AppSpace.md),
              Row(children: [
                link(Lu.globe, l.aboutDevWebsite, web(developerWebsite)),
                const SizedBox(width: AppSpace.md),
                link(Lu.link, l.aboutDevLinkedIn, web(developerLinkedIn)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The version line. Seven quick taps open the hidden Test data tool.
class _VersionLabel extends StatefulWidget {
  const _VersionLabel({required this.text, required this.onSevenTaps});
  final String text;
  final VoidCallback onSevenTaps;

  @override
  State<_VersionLabel> createState() => _VersionLabelState();
}

class _VersionLabelState extends State<_VersionLabel> {
  var _taps = 0;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  void _tap() {
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () => _taps = 0);
    if (++_taps >= 7) {
      _taps = 0;
      widget.onSevenTaps();
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: Text(widget.text, style: TextStyle(color: context.palette.text2)),
        ),
      );
}
