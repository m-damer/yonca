import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'l10n/app_localizations.dart';
import 'shell/app_shell.dart';
import 'theme/theme.dart';

void main() => runApp(YoncaApp(controller: AppController()));

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
        theme: buildYoncaTheme(Brightness.light),
        darkTheme: buildYoncaTheme(Brightness.dark),
        themeMode: controller.themeMode,
        home: AppShell(controller: controller),
      ),
    );
  }
}
