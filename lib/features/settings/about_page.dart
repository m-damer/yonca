import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../data/update_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../../shared/glass_widgets.dart';
import 'updates_page.dart';

/// About YONCA and the developer.
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
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                GlassIconButton(icon: Icons.arrow_back, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 14),
                Expanded(child: Text(l.aboutTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.onHeader))),
              ]),
            ),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              GlassCard(
                child: Column(children: [
                  Icon(Icons.spa_outlined, size: 56, color: p.primary),
                  const SizedBox(height: 8),
                  Text(l.appName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: p.text)),
                  Text(l.aboutVersion(appVersion), style: TextStyle(color: p.text2)),
                  const SizedBox(height: 12),
                  Text(l.aboutTagline, textAlign: TextAlign.center, style: TextStyle(color: p.text)),
                  const SizedBox(height: 8),
                  Text(l.aboutPrivacy, textAlign: TextAlign.center, style: TextStyle(color: p.text2)),
                ]),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    leading: Icon(Icons.system_update_alt, color: p.primary),
                    title: Text(l.aboutUpdates),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => UpdatesPage(controller: controller))),
                  ),
                ),
              ),
              SectionLabel(l.aboutDeveloper),
              GlassCard(child: Text(l.aboutDeveloperBody)),
            ]),
          ),
        ]),
      ),
    );
  }
}
