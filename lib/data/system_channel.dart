import 'dart:convert';

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

  /// Incoming-call card: whether the phone and call-log permissions and "Display over other apps" are on.
  static Future<({bool phone, bool overlay})> callCardStatus() async {
    try {
      final r = await _c.invokeMethod<Map<Object?, Object?>>('callCardStatus');
      return (phone: (r?['phone'] as bool?) ?? false, overlay: (r?['overlay'] as bool?) ?? false);
    } catch (_) {
      return (phone: false, overlay: false);
    }
  }

  /// Asks for the phone-state and call-log permissions; true when both are granted.
  static Future<bool> requestCallPermissions() async {
    try {
      return await _c.invokeMethod<bool>('requestCallPermissions') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openOverlaySettings() => _call('openOverlaySettings');

  /// Draws the call card for one saved contact for a few seconds. False when there is nothing to show it for.
  static Future<bool> previewCallCard() async {
    try {
      return await _c.invokeMethod<bool>('previewCallCard') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Calls whose outcome was chosen on the card or the notification, as `{id, number, contactId, dir, missed, sec, at, outcome}`.
  /// They are removed from the phone's waiting list.
  static Future<List<Map<String, Object?>>> takeLoggedCalls() async {
    try {
      final raw = await _c.invokeMethod<String>('takeLoggedCalls');
      if (raw == null || raw.isEmpty) return const [];
      return [for (final e in jsonDecode(raw) as List) Map<String, Object?>.from(e as Map)];
    } catch (_) {
      return const [];
    }
  }

  /// One finished call waiting to be logged, or null.
  static Future<Map<String, Object?>?> getCall(String id) async {
    try {
      final raw = await _c.invokeMethod<String>('getCall', {'id': id});
      if (raw == null || raw.isEmpty) return null;
      return Map<String, Object?>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> removeCall(String id) async {
    try {
      await _c.invokeMethod<void>('removeCall', {'id': id});
    } catch (_) {}
  }
}
