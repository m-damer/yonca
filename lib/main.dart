import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'data/open_database.dart';
import 'l10n/app_localizations.dart';
import 'shell/app_shell.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        theme: buildYoncaTheme(Brightness.light, arabic: controller.locale.languageCode == 'ar'),
        darkTheme: buildYoncaTheme(Brightness.dark, arabic: controller.locale.languageCode == 'ar'),
        themeMode: controller.themeMode,
        home: AppShell(controller: controller),
      ),
    );
  }
}
