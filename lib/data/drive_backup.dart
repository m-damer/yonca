import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart' show PlatformException;
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
  const DriveException(this.problem, [this.detail = '']);
  final DriveProblem problem;

  /// What Google or Android actually said (short, English), so a failure can be diagnosed.
  final String detail;
  @override
  String toString() => 'DriveException($problem${detail.isEmpty ? '' : ': $detail'})';
}

/// A short readable reason for a Drive or sign-in error.
String driveErrorDetail(Object e) {
  String cut(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > 160 ? '${t.substring(0, 160)}…' : t;
  }

  if (e is drive.DetailedApiRequestError) return cut('HTTP ${e.status}: ${e.message ?? ''}');
  if (e is PlatformException) return cut('${e.code}: ${e.message ?? ''}');
  return cut(e.toString());
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
    } catch (e) {
      throw DriveException(DriveProblem.failed, driveErrorDetail(e));
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
    } catch (e) {
      throw DriveException(DriveProblem.failed, driveErrorDetail(e));
    }
  }

  /// Uploads [file] and removes the older copies, so Drive keeps one backup.
  Future<void> upload(File file, {void Function(double)? onProgress}) async {
    final api = await _api();
    try {
      final old = await api.files.list(spaces: 'appDataFolder', $fields: 'files(id)');
      final meta = drive.File()
        ..name = file.uri.pathSegments.last
        ..parents = ['appDataFolder'];
      final total = file.lengthSync();
      var sent = 0;
      final stream = file.openRead().map((chunk) {
        sent += chunk.length;
        if (total > 0) onProgress?.call((sent / total).clamp(0.0, 1.0));
        return chunk;
      });
      await api.files.create(meta, uploadMedia: drive.Media(stream, total));
      for (final f in old.files ?? const <drive.File>[]) {
        if (f.id != null) await api.files.delete(f.id!);
      }
    } on DriveException {
      rethrow;
    } catch (e) {
      throw DriveException(DriveProblem.failed, driveErrorDetail(e));
    }
  }

  /// Downloads the backup into [to]. A dropped connection is retried and the download carries on from
  /// the bytes already saved. [onProgress] goes from 0 to 1.
  Future<File> download(DriveBackupInfo info, File to, {void Function(double)? onProgress, int attempts = 6}) async {
    final api = await _api();
    try {
      if (await to.exists()) await to.delete();
      var have = 0;
      for (var attempt = 1;; attempt++) {
        try {
          final partial = have > 0 && info.bytes > have;
          final media = await api.files.get(
            info.id,
            downloadOptions: partial ? drive.PartialDownloadOptions(drive.ByteRange(have, info.bytes - 1)) : drive.DownloadOptions.fullMedia,
          ) as drive.Media;
          final sink = to.openWrite(mode: partial ? FileMode.append : FileMode.write);
          if (!partial) have = 0;
          try {
            await for (final chunk in media.stream) {
              sink.add(chunk);
              have += chunk.length;
              if (info.bytes > 0) onProgress?.call((have / info.bytes).clamp(0.0, 1.0));
            }
          } finally {
            await sink.close();
          }
          break;
        } on drive.DetailedApiRequestError {
          rethrow;
        } catch (_) {
          // Connection dropped: keep what is saved and try again from there.
          have = await to.exists() ? await to.length() : 0;
          if (attempt >= attempts) rethrow;
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }
      onProgress?.call(1);
      return to;
    } on DriveException {
      rethrow;
    } catch (e) {
      throw DriveException(DriveProblem.failed, driveErrorDetail(e));
    }
  }
}
