import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';

/// First run: three short pages (welcome with language, privacy, reminders), then the app.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= 2) {
      widget.controller.completeOnboarding();
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final isArabic = widget.controller.locale.languageCode == 'ar';
    Widget page(IconData icon, String title, String body, {Widget? extra}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 72, color: p.primary),
            const SizedBox(height: 24),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 12),
            Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.5, color: p.text2)),
            if (extra != null) ...[const SizedBox(height: 24), extra],
          ]),
        );
    return Scaffold(
      body: GlassBackdrop(
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(onPressed: widget.controller.completeOnboarding, child: Text(l.onbSkip)),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  page(
                    Icons.spa_outlined,
                    l.onbWelcome,
                    l.onbWelcomeBody,
                    extra: PillButton(
                      label: l.switchLanguage,
                      outlined: true,
                      height: 48,
                      onPressed: () => widget.controller.setLocale(Locale(isArabic ? 'en' : 'ar')),
                    ),
                  ),
                  page(Icons.lock_outline, l.onbPrivateTitle, l.onbPrivateBody),
                  page(Icons.notifications_active_outlined, l.onbRemindTitle, l.onbRemindBody),
                ],
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: i == _page ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(color: i == _page ? p.primary : p.track, borderRadius: BorderRadius.circular(4)),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.all(20),
              child: PillButton(label: _page >= 2 ? l.onbStart : l.onbNext, onPressed: _next),
            ),
          ]),
        ),
      ),
    );
  }
}
