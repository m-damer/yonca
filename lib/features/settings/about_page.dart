import 'package:flutter/material.dart';

import '../../shared/ds.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_controller.dart';
import '../../core/developer.dart';
import '../../data/update_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/leaf_logo.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'settings_widgets.dart' show SettingsGroup, SettingsRow, SettingsSwitch;
import 'updates_page.dart';
import '../../theme/tokens.dart';

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
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, 10, AppSpace.xl, AppSpace.xxl), children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 18),
                child: Column(children: [
                  const LeafLogo(size: 134, gap: 6, radius: 28),
                  const SizedBox(height: 10),
                  Text('YONCA',
                      style: TextStyle(fontSize: AppFont.pageTitle, fontWeight: FontWeight.w700, letterSpacing: 6, color: p.text)),
                  Text(l.aboutVersion(appVersion), style: TextStyle(color: p.text2)),
                ]),
              ),
              SettingsGroup(children: [
                SettingsRow(
                  icon: Icons.sync,
                  title: l.aboutUpdates,
                  chevron: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => UpdatesPage(controller: controller))),
                ),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => SettingsSwitch(
                    title: l.settingWeeklyUpdates,
                    subtitle: l.settingWeeklyUpdatesHint,
                    value: controller.weeklyUpdateCheck,
                    onChanged: (v) => controller.setFlag(AppController.keyWeeklyUpdate, v),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpace.md),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.aboutPrivacyTitle, style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
                  const SizedBox(height: AppSpace.xs),
                  Text(l.aboutPrivacyText, style: TextStyle(fontSize: AppFont.meta2, color: p.text2)),
                ]),
              ),
              const SizedBox(height: AppSpace.md),
              SettingsGroup(children: [
                SettingsRow(
                  icon: Icons.mail_outline,
                  title: l.aboutFeedback,
                  subtitle: l.aboutFeedbackSub,
                  chevron: true,
                  onTap: () => _open(Uri(scheme: 'mailto', path: developerEmail, queryParameters: {'subject': 'YONCA $appVersion'})),
                ),
                SettingsRow(
                  icon: Icons.person_outline,
                  title: l.aboutDeveloper,
                  chevron: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DeveloperPage())),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: l.aboutMadePre),
                    WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.favorite, size: 14, color: p.error)),
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
                    Icon(icon, size: 24, color: p.text),
                    const SizedBox(width: 10),
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
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, 10, AppSpace.xl, AppSpace.xxl), children: [
              const SizedBox(height: 6),
              Center(
                child: Container(
                  width: 160,
                  height: 160,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.surface2, shape: BoxShape.circle),
                  child: Text(l.aboutDevInitials, style: TextStyle(fontSize: AppFont.hero, fontWeight: FontWeight.w700, color: p.text)),
                ),
              ),
              const SizedBox(height: 14),
              Text(l.aboutDevName, textAlign: TextAlign.center, style: TextStyle(fontSize: AppFont.headline, fontWeight: FontWeight.w700, color: p.text)),
              Text(l.aboutDevRole, textAlign: TextAlign.center, style: TextStyle(color: p.text2)),
              const SizedBox(height: AppSpace.lg),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 14),
                child: Text(l.aboutDevBio, style: TextStyle(color: p.text2)),
              ),
              const SizedBox(height: AppSpace.md),
              Row(children: [
                link(Icons.mail_outline, l.aboutDevEmail, developerEmail.isEmpty ? null : Uri(scheme: 'mailto', path: developerEmail)),
                const SizedBox(width: 10),
                link(Icons.chat_bubble_outline, l.aboutDevWhatsApp, developerWhatsApp.isEmpty ? null : Uri.parse('https://wa.me/$developerWhatsApp')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                link(Icons.language, l.aboutDevWebsite, web(developerWebsite)),
                const SizedBox(width: 10),
                link(Icons.link, l.aboutDevLinkedIn, web(developerLinkedIn)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
