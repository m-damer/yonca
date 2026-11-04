import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// The app's own version. The release workflow passes the real one with --dart-define (APP_VERSION, APP_BUILD);
/// the defaults are for test and local builds and are kept equal to pubspec.yaml (a test checks this).
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');
const appBuild = int.fromEnvironment('APP_BUILD', defaultValue: 1);

/// The CI run that built this APK (empty for local builds); shown in About so a test build can be identified.
const ciRun = String.fromEnvironment('CI_RUN');

/// Version text with the CI run number when there is one.
String get appVersionLabel => ciRun.isEmpty ? appVersion : '$appVersion · #$ciRun';

const releasesApi = 'https://api.github.com/repos/m-damer/yonca/releases/latest';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.build, required this.notes, required this.apkUrl, required this.sha256Url, this.sizeBytes = 0});
  final String version;
  final int build;
  final String notes;
  final String apkUrl;
  final String? sha256Url;
  final int sizeBytes;
}

class UpdateException implements Exception {
  const UpdateException(this.code);

  /// `offline`, `failed`, `checksum` (the file does not match) or `unverified` (the release has no usable checksum).
  final String code;
  @override
  String toString() => 'UpdateException($code)';
}

/// Reads "v0.1.0+3" or "0.1.0" into (0.1.0, 3). Returns null when it does not look like a version.
(String, int)? parseVersionTag(String tag) {
  final m = RegExp(r'^v?(\d+\.\d+\.\d+)(?:[+\-b.]*(\d+))?$').firstMatch(tag.trim());
  if (m == null) return null;
  return (m.group(1)!, int.tryParse(m.group(2) ?? '') ?? 0);
}

/// True when [latest] is newer than [current].
bool isNewerVersion(String latestVersion, int latestBuild, String currentVersion, int currentBuild) {
  List<int> parts(String v) => v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final a = parts(latestVersion);
  final b = parts(currentVersion);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return latestBuild > currentBuild;
}

/// Turns the GitHub "latest release" JSON into an [UpdateInfo]; null when it has no APK.
UpdateInfo? parseRelease(Map<String, dynamic> json) {
  final tag = parseVersionTag((json['tag_name'] as String?) ?? '');
  if (tag == null) return null;
  String? apk;
  String? sha;
  var size = 0;
  for (final a in (json['assets'] as List<dynamic>? ?? const [])) {
    final m = a as Map<String, dynamic>;
    final name = (m['name'] as String?) ?? '';
    final url = (m['browser_download_url'] as String?) ?? '';
    if (name.endsWith('.apk')) {
      apk = url;
      size = (m['size'] as num?)?.toInt() ?? 0;
    }
    if (name.endsWith('.sha256')) sha = url;
  }
  if (apk == null) return null;
  return UpdateInfo(version: tag.$1, build: tag.$2, notes: (json['body'] as String?) ?? '', apkUrl: apk, sha256Url: sha, sizeBytes: size);
}

/// Lets the person stop a running download.
class DownloadCancel {
  bool cancelled = false;
}

/// Checks GitHub Releases and downloads the APK. The only network use in the app besides sharing.
class UpdateService {
  UpdateService({HttpClient Function()? clientFactory}) : _factory = clientFactory ?? HttpClient.new;
  final HttpClient Function() _factory;

  /// The newer release, or null when this version is the latest.
  Future<UpdateInfo?> check({String currentVersion = appVersion, int currentBuild = appBuild}) async {
    final client = _factory()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(releasesApi));
      req.headers.set('Accept', 'application/vnd.github+json');
      final res = await req.close();
      if (res.statusCode == 404) return null;
      if (res.statusCode != 200) throw const UpdateException('failed');
      final body = await res.transform(utf8.decoder).join();
      final info = parseRelease(jsonDecode(body) as Map<String, dynamic>);
      if (info == null) return null;
      return isNewerVersion(info.version, info.build, currentVersion, currentBuild) ? info : null;
    } on SocketException {
      throw const UpdateException('offline');
    } on HandshakeException {
      throw const UpdateException('offline');
    } on HttpException {
      throw const UpdateException('failed');
    } on FormatException {
      throw const UpdateException('failed');
    } finally {
      client.close(force: true);
    }
  }

  /// Downloads the APK into [dir], checks its SHA-256 against the release file, and returns it.
  /// A dropped connection is retried and the download carries on from where it stopped.
  Future<File> download(UpdateInfo info, Directory dir, {void Function(double)? onProgress, DownloadCancel? cancel, int attempts = 5}) async {
    final file = File('${dir.path}/yonca-${info.version}.apk');
    try {
      // No checksum, no install: a release without a usable .sha256 is refused before anything is downloaded.
      if (info.sha256Url == null) throw const UpdateException('unverified');
      final expected = await _expectedChecksum(info.sha256Url!);
      var total = info.sizeBytes;
      for (var attempt = 1;; attempt++) {
        try {
          total = await _fetchInto(info.apkUrl, file, total, onProgress, cancel);
          break;
        } on UpdateException {
          rethrow;
        } on IOException {
          // Connection closed or timed out: wait a moment and resume from what is already saved.
          if (attempt >= attempts) throw const UpdateException('offline');
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }
      final actual = (await sha256.bind(file.openRead()).first).toString();
      if (actual != expected) {
        await file.delete();
        throw const UpdateException('checksum');
      }
      return file;
    } on UpdateException catch (e) {
      if (e.code == 'cancelled' && await file.exists()) await file.delete();
      rethrow;
    } on IOException {
      throw const UpdateException('offline');
    }
  }

  /// The SHA-256 the release publishes. A missing or malformed file is `unverified`; a dropped connection is retried.
  Future<String> _expectedChecksum(String url) async {
    for (var attempt = 1;; attempt++) {
      try {
        final text = await _fetchChecksum(url);
        if (text == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) throw const UpdateException('unverified');
        return text;
      } on IOException {
        if (attempt >= 3) throw const UpdateException('offline');
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  Future<String?> _fetchChecksum(String url) async {
    final client = _factory()..connectionTimeout = const Duration(seconds: 15);
    try {
      final r = await (await client.getUrl(Uri.parse(url))).close();
      if (r.statusCode != 200) {
        await r.drain<void>();
        return null;
      }
      return (await r.transform(utf8.decoder).join()).trim().split(RegExp(r'\s+')).first.toLowerCase();
    } finally {
      client.close(force: true);
    }
  }

  /// Fetches [url] into [file], continuing after the bytes already there. Returns the full size.
  Future<int> _fetchInto(String url, File file, int knownTotal, void Function(double)? onProgress, DownloadCancel? cancel) async {
    final client = _factory()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 30);
    try {
      var have = await file.exists() ? await file.length() : 0;
      final req = await client.getUrl(Uri.parse(url));
      if (have > 0) req.headers.set('Range', 'bytes=$have-');
      final res = await req.close();
      if (res.statusCode == 416 && have > 0 && knownTotal > 0 && have >= knownTotal) return knownTotal;
      if (res.statusCode != 200 && res.statusCode != 206) {
        await res.drain<void>();
        throw const UpdateException('failed');
      }
      final resumed = res.statusCode == 206;
      if (!resumed) have = 0;
      final total = res.contentLength > 0 ? res.contentLength + have : knownTotal;
      final sink = file.openWrite(mode: resumed ? FileMode.append : FileMode.write);
      var got = have;
      try {
        await for (final chunk in res.timeout(const Duration(seconds: 30))) {
          if (cancel?.cancelled ?? false) throw const UpdateException('cancelled');
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) onProgress?.call((got / total).clamp(0.0, 1.0));
        }
      } finally {
        await sink.close();
      }
      if (total > 0 && got < total) throw const HttpException('Connection closed early');
      return total;
    } on TimeoutException {
      throw const HttpException('Timed out');
    } finally {
      client.close(force: true);
    }
  }
}
