import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'data/crash_log.dart';
import 'data/open_database.dart';
import 'l10n/app_localizations.dart';
import 'features/onboarding/onboarding_page.dart';
import 'shell/app_shell.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final docs = await getApplicationDocumentsDirectory();
    CrashLog.instance = CrashLog(docs);
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      CrashLog.instance?.record(details.exception, details.stack);
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      CrashLog.instance?.record(error, stack);
      return false;
    };
  } catch (_) {}
  final db = await openAppDatabase();
  final controller = await AppController.restore(db);
  runApp(YoncaApp(controller: controller));
}

class YoncaApp extends StatelessWidget {
  const YoncaApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (c) => AppLocalizations.of(c).appName,
        debugShowCheckedModeBanner: false,
        locale: controller.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildYoncaTheme(Brightness.light, arabic: controller.locale.languageCode == 'ar', accent: controller.accent, highContrast: controller.highContrast, systemFont: controller.systemArabicFont, indicDigits: controller.indicDigits),
        darkTheme: buildYoncaTheme(Brightness.dark, arabic: controller.locale.languageCode == 'ar', accent: controller.accent, highContrast: controller.highContrast, systemFont: controller.systemArabicFont, indicDigits: controller.indicDigits),
        themeMode: controller.themeMode,
        home: controller.onboarded ? AppShell(controller: controller) : OnboardingPage(controller: controller),
      ),
    );
  }
}
