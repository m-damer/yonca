import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'data/backup_runner.dart';
import 'data/crash_log.dart';
import 'data/open_database.dart';
import 'data/reminders.dart';
import 'data/update_scheduler.dart';
import 'l10n/app_localizations.dart';
import 'features/onboarding/onboarding_page.dart';
import 'shared/leaf_logo.dart';
import 'shell/app_shell.dart';
import 'theme/theme.dart';
import './theme/tokens.dart';

/// The shortest time the logo stays on screen, so it never just flashes.
const _minSplash = Duration(milliseconds: 600);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The logo shows at once while the database opens (the first frame takes a second or two).
  runApp(const _Boot());
}

Future<AppController> _start() async {
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
  unawaited(() async {
    final notes = NotificationReminders();
    await autoBackupWithNotice(BackupRunner(controller), notes);
    await autoLocalBackupWithNotice(BackupRunner(controller), notes);
  }());
  unawaited(BackupScheduler.sync(controller));
  unawaited(UpdateScheduler.sync(controller));
  return controller;
}

/// Shows the splash first, then the app as soon as it is ready (never sooner than [_minSplash]).
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  AppController? _controller;

  @override
  void initState() {
    super.initState();
    final watch = Stopwatch()..start();
    _start().then((c) async {
      final left = _minSplash - watch.elapsed;
      if (left > Duration.zero) await Future<void>.delayed(left);
      if (mounted) setState(() => _controller = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      child: c == null ? const _Splash(key: ValueKey('splash')) : YoncaApp(key: const ValueKey('app'), controller: c),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildYoncaTheme(Brightness.light),
      darkTheme: buildYoncaTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const Scaffold(body: Center(child: LeafLogo(size: AppSize.s96, gap: AppSpace.xs))),
    );
  }
}

final _themes = <String, ThemeData>{};

class YoncaApp extends StatelessWidget {
  const YoncaApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final ar = controller.locale.languageCode == 'ar';
            // Same ThemeData instances until a theme setting changes, so unrelated notifications
            // (data edits, reminders) never restyle the Navigator/Overlay underneath.
            ThemeData build(Brightness b) => _themes.putIfAbsent(
                '${b.name}|$ar|${controller.highContrast}|${controller.arabicFont}|${controller.indicDigits}',
                () => buildYoncaTheme(b,
                    arabic: ar,
                    highContrast: controller.highContrast,
                    arabicFont: controller.arabicFont,
                    indicDigits: controller.indicDigits));
            return MaterialApp(
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
              theme: build(Brightness.light),
              darkTheme: build(Brightness.dark),
              themeMode: controller.themeMode,
              home: controller.onboarded ? AppShell(controller: controller) : OnboardingPage(controller: controller),
            );
          },
    );
  }
}
