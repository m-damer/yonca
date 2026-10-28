import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// The backup file stored on Google Drive.
class DriveBackupInfo {
  const DriveBackupInfo({required this.id, required this.name, required this.modified, required this.bytes});
  final String id;
  final String name;
  final DateTime modified;
  final int bytes;
}

enum DriveProblem { notSignedIn, offline, failed }

class DriveException implements Exception {
  const DriveException(this.problem);
  final DriveProblem problem;
  @override
  String toString() => 'DriveException($problem)';
}

/// Backup on the person's own Google Drive. Files go to the app's private data folder
/// (the drive.appdata scope), so the app can't see anything else on the Drive.
class DriveBackup {
  DriveBackup({GoogleSignIn? signIn}) : _google = signIn ?? GoogleSignIn(scopes: [drive.DriveApi.driveAppdataScope]);
  final GoogleSignIn _google;

  String? get email => _google.currentUser?.email;

  /// Signs in without showing anything when the person already allowed this app. Returns the email.
  Future<String?> restore() async {
    try {
      return (await _google.signInSilently())?.email;
    } catch (_) {
      return null;
    }
  }

  /// Shows the Google account chooser. Returns the email, or null when cancelled.
  Future<String?> connect() async {
    try {
      return (await _google.signIn())?.email;
    } catch (_) {
      throw const DriveException(DriveProblem.failed);
    }
  }

  Future<void> disconnect() async {
    try {
      await _google.signOut();
    } catch (_) {}
  }

  static Future<bool> online() async {
    final r = await Connectivity().checkConnectivity();
    return !r.contains(ConnectivityResult.none);
  }

  static Future<bool> onWifi() async {
    final r = await Connectivity().checkConnectivity();
    return r.contains(ConnectivityResult.wifi) || r.contains(ConnectivityResult.ethernet);
  }

  Future<drive.DriveApi> _api() async {
    if (!await online()) throw const DriveException(DriveProblem.offline);
    final client = await _google.authenticatedClient();
    if (client == null) throw const DriveException(DriveProblem.notSignedIn);
    return drive.DriveApi(client);
  }

  Future<DriveBackupInfo?> latest() async {
    final api = await _api();
    try {
      final list = await api.files.list(
        spaces: 'appDataFolder',
        orderBy: 'modifiedTime desc',
        pageSize: 1,
        $fields: 'files(id,name,modifiedTime,size)',
      );
      final f = list.files?.firstOrNull;
      if (f == null || f.id == null) return null;
      return DriveBackupInfo(
        id: f.id!,
        name: f.name ?? '',
        modified: f.modifiedTime ?? DateTime.now(),
        bytes: int.tryParse(f.size ?? '') ?? 0,
      );
    } on DriveException {
      rethrow;
    } catch (_) {
      throw const DriveException(DriveProblem.failed);
    }
  }

  /// Uploads [file] and removes the older copies, so Drive keeps one backup.
  Future<void> upload(File file) async {
    final api = await _api();
    try {
      final old = await api.files.list(spaces: 'appDataFolder', $fields: 'files(id)');
      final meta = drive.File()
        ..name = file.uri.pathSegments.last
        ..parents = ['appDataFolder'];
      await api.files.create(meta, uploadMedia: drive.Media(file.openRead(), file.lengthSync()));
      for (final f in old.files ?? const <drive.File>[]) {
        if (f.id != null) await api.files.delete(f.id!);
      }
    } on DriveException {
      rethrow;
    } catch (_) {
      throw const DriveException(DriveProblem.failed);
    }
  }

  Future<File> download(DriveBackupInfo info, File to) async {
    final api = await _api();
    try {
      final media = await api.files.get(info.id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final sink = to.openWrite();
      await media.stream.pipe(sink);
      return to;
    } on DriveException {
      rethrow;
    } catch (_) {
      throw const DriveException(DriveProblem.failed);
    }
  }
}
