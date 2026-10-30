import 'package:flutter/services.dart';

/// What only Android's own screens can do: pick an alarm sound and check or open special permissions.
/// Everything falls back to a harmless answer where the channel does not exist (tests, other systems).
class SystemChannel {
  static const _c = MethodChannel('com.cyberomeda.yonca/system');

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
}
