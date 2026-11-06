import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import 'reminders.dart';
import 'update_service.dart';

enum UpdatePhase { idle, downloading, error }

/// Runs the update download so it keeps going when the person leaves the Updates page or the app.
/// While it runs there is a progress notification; when it is done a "tap to install" notification stays
/// until the person opens it, so closing the Android installer never loses the downloaded file.
class UpdateManager extends ChangeNotifier {
  UpdateManager(this._c, this._reminders, {UpdateService? service, Future<Directory> Function()? dir})
      : _service = service ?? UpdateService(),
        _dir = dir ?? getTemporaryDirectory;

  final AppController _c;
  final Reminders _reminders;
  final UpdateService _service;
  final Future<Directory> Function() _dir;

  static const progressId = 900002;
  static const readyId = 900003;
  static const payload = 'update:0:0';

  UpdatePhase phase = UpdatePhase.idle;
  double progress = 0;
  UpdateInfo? info;
  String error = '';
  DownloadCancel _cancel = DownloadCancel();

  bool get busy => phase == UpdatePhase.downloading;

  AppLocalizations get _l => lookupAppLocalizations(_c.locale);

  /// The version of the downloaded file that is waiting to be installed, or null.
  String? get readyVersion {
    final v = _c.pref(AppController.keyUpdateApkVersion);
    final path = _c.pref(AppController.keyUpdateApk);
    if (v == null || v.isEmpty || path == null || path.isEmpty) return null;
    if (!isNewerVersion(v, 0, appVersion, 0)) return null;
    return v;
  }

  /// The downloaded APK, if it is still on the phone and newer than the running app.
  File? readyFile() {
    if (readyVersion == null) return null;
    final f = File(_c.pref(AppController.keyUpdateApk)!);
    return f.existsSync() ? f : null;
  }

  /// Forgets a downloaded file once that version (or a newer one) is installed.
  Future<void> cleanup() async {
    final path = _c.pref(AppController.keyUpdateApk);
    if (path == null || path.isEmpty || readyVersion != null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await _c.setPref(AppController.keyUpdateApk, '');
    await _c.setPref(AppController.keyUpdateApkVersion, '');
    await _reminders.endProgress(readyId);
  }

  /// Downloads [target]; returns the checked file, or null when cancelled. Throws [UpdateException] on failure.
  Future<File?> start(UpdateInfo target) async {
    final ready = readyFile();
    if (ready != null && readyVersion == target.version) return ready;
    if (busy) return null;
    info = target;
    phase = UpdatePhase.downloading;
    progress = 0;
    error = '';
    _cancel = DownloadCancel();
    notifyListeners();
    final l = _l;
    final title = l.notifUpdateDownloading(target.version);
    var lastPercent = -1;
    unawaited(_reminders.startProgress(progressId, title, payload: payload));
    try {
      final dir = await _dir();
      final f = await _service.download(target, dir, cancel: _cancel, onProgress: (p) {
        progress = p;
        notifyListeners();
        final percent = (p * 100).floor();
        if (percent != lastPercent) {
          lastPercent = percent;
          unawaited(_reminders.updateProgress(progressId, title, percent, payload: payload));
        }
      });
      await _c.setPref(AppController.keyUpdateApk, f.path);
      await _c.setPref(AppController.keyUpdateApkVersion, target.version);
      phase = UpdatePhase.idle;
      await _reminders.endProgress(progressId);
      await _reminders.showNow(readyId, l.notifUpdateReadyTitle, l.notifUpdateReadyBody(target.version), payload: payload);
      notifyListeners();
      return f;
    } on UpdateException catch (e) {
      await _reminders.endProgress(progressId);
      if (e.code == 'cancelled') {
        phase = UpdatePhase.idle;
        notifyListeners();
        return null;
      }
      phase = UpdatePhase.error;
      error = e.code == 'failed' ? 'download' : e.code;
      await _reminders.showNow(readyId, l.notifUpdateFailedTitle, l.notifUpdateFailedBody, payload: payload);
      notifyListeners();
      rethrow;
    } catch (_) {
      // Anything unexpected (full storage, for example) must never close the app.
      await _reminders.endProgress(progressId);
      phase = UpdatePhase.error;
      error = 'download';
      notifyListeners();
      throw const UpdateException('failed');
    }
  }

  void cancel() => _cancel.cancelled = true;
}
