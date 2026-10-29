import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// The app's own version, kept equal to pubspec.yaml (a test checks this).
const appVersion = '0.1.0';
const appBuild = 1;

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

  /// `offline`, `failed` or `checksum`.
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
  Future<File> download(UpdateInfo info, Directory dir, {void Function(double)? onProgress}) async {
    final client = _factory()..connectionTimeout = const Duration(seconds: 15);
    try {
      String? expected;
      if (info.sha256Url != null) {
        final r = await (await client.getUrl(Uri.parse(info.sha256Url!))).close();
        if (r.statusCode == 200) {
          expected = (await r.transform(utf8.decoder).join()).trim().split(RegExp(r'\s+')).first.toLowerCase();
        } else {
          await r.drain<void>();
        }
      }
      final res = await (await client.getUrl(Uri.parse(info.apkUrl))).close();
      if (res.statusCode != 200) throw const UpdateException('failed');
      final file = File('${dir.path}/yonca-${info.version}.apk');
      final sink = file.openWrite();
      var got = 0;
      final total = res.contentLength;
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress?.call(got / total);
      }
      await sink.close();
      if (expected != null) {
        final actual = (await sha256.bind(file.openRead()).first).toString();
        if (actual != expected) {
          await file.delete();
          throw const UpdateException('checksum');
        }
      }
      return file;
    } on SocketException {
      throw const UpdateException('offline');
    } finally {
      client.close(force: true);
    }
  }
}
