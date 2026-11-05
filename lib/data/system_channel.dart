import 'package:flutter/services.dart';

/// What only Android's own screens can do: pick an alarm sound and check or open special permissions.
/// Everything falls back to a harmless answer where the channel does not exist (tests, other systems).
class SystemChannel {
  static const _c = MethodChannel('com.yonca.app/system');

  /// Opens the phone's alarm-sound picker. Null when cancelled; an empty [uri] means the phone default.
  static Future<({String uri, String title})?> pickRingtone(String current) async {
    try {
      final r = await _c.invokeMethod<Map<Object?, Object?>>('pickRingtone', {'current': current});
      if (r == null) return null;
      return (uri: (r['uri'] as String?) ?? '', title: (r['title'] as String?) ?? '');
    } catch (_) {
      return null;
    }
  }

  /// Phone model and Android version for the crash report; empty where the channel does not exist.
  static Future<({String model, String android})> deviceInfo() async {
    try {
      final r = await _c.invokeMethod<Map<Object?, Object?>>('deviceInfo');
      return (model: (r?['model'] as String?) ?? '', android: (r?['android'] as String?) ?? '');
    } catch (_) {
      return (model: '', android: '');
    }
  }

  static Future<bool> _bool(String method) async {
    try {
      return await _c.invokeMethod<bool>(method) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _call(String method) async {
    try {
      await _c.invokeMethod<void>(method);
    } catch (_) {}
  }

  static Future<bool> canUseFullScreenIntent() => _bool('canUseFullScreenIntent');
  static Future<bool> canInstallPackages() => _bool('canInstallPackages');
  static Future<void> openFullScreenSettings() => _call('openFullScreenSettings');
  static Future<void> openInstallSettings() => _call('openInstallSettings');
  /// Starts the app again from scratch (used after a restore, which is applied at start).
  static Future<void> restartApp() => _call('restartApp');
  /// Closes the app and removes its card from recent apps (used when the installer takes over for an update).
  static Future<void> closeTask() => _call('closeTask');
  static Future<bool> hasContactsPermission() => _bool('hasContactsPermission');
  static Future<bool> isIgnoringBatteryOptimizations() => _bool('isIgnoringBatteryOptimizations');
  static Future<void> requestIgnoreBatteryOptimizations() => _call('requestIgnoreBatteryOptimizations');
  static Future<void> openAppSettings() => _call('openAppSettings');
  static Future<bool> canManageStorage() => _bool('canManageStorage');
  static Future<void> openStorageSettings() => _call('openStorageSettings');
}
