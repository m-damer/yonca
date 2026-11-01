import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../theme/glass.dart';
import '../theme/palette.dart';
import 'glass_widgets.dart';
import '../theme/tokens.dart';

/// Explains why a permission is needed, before Android asks (design Y8–Y12).
/// Returns true when the person taps the main button, false for "Not now".
class PermissionPrimer extends StatelessWidget {
  const PermissionPrimer({super.key, required this.icon, required this.title, required this.body, required this.primary});
  final IconData icon;
  final String title;
  final String body;
  final String primary;

  static Future<bool> show(BuildContext context, {required IconData icon, required String title, required String body, required String primary}) async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PermissionPrimer(icon: icon, title: title, body: body, primary: primary)));
    return r == true;
  }

  static Future<File?> _flag(String key) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/primers/$key');
    } catch (_) {
      return null;
    }
  }

  /// True until the person has been through this explanation once.
  static Future<bool> needed(String key) async {
    final f = await _flag(key);
    return f == null ? false : !await f.exists();
  }

  static Future<void> markSeen(String key) async {
    final f = await _flag(key);
    if (f == null) return;
    await f.parent.create(recursive: true);
    await f.writeAsString('1');
  }

  /// Shows the explanation once per [key]; true when Android may now be asked (or it was shown before).
  static Future<bool> once(BuildContext context, String key, {required IconData icon, required String title, required String body}) async {
    if (!await needed(key)) return true;
    if (!context.mounted) return false;
    final ok = await show(context, icon: icon, title: title, body: body, primary: AppLocalizations.of(context).continueBtn);
    if (ok) await markSeen(key);
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, 0),
            child: Row(children: [GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).pop(false))]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.x7, AppSpace.xxl, AppSpace.xxl), children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Icon(icon, size: AppIcon.x3, color: pal.primary),
              ),
              const SizedBox(height: AppSpace.xxl),
              Text(title, style: const TextStyle(fontSize: AppFont.display, height: AppLine.tight, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpace.sm),
              Text(body, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: pal.text2)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
            child: Column(children: [
              PillButton(label: primary, height: AppControl.lg, onPressed: () => Navigator.of(context).pop(true)),
              const SizedBox(height: AppSpace.xs),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: pal.primary, textStyle: const TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w600)),
                child: Text(l.notNowBtn),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
