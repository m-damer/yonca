import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/data/update_service.dart';

void main() {
  test('tags are read', () {
    expect(parseVersionTag('v0.1.0+3'), ('0.1.0', 3));
    expect(parseVersionTag('0.2.1'), ('0.2.1', 0));
    expect(parseVersionTag('latest'), isNull);
  });

  test('newer versions are detected', () {
    expect(isNewerVersion('0.1.1', 0, '0.1.0', 9), isTrue);
    expect(isNewerVersion('0.1.0', 2, '0.1.0', 1), isTrue);
    expect(isNewerVersion('0.1.0', 1, '0.1.0', 1), isFalse);
    expect(isNewerVersion('0.0.9', 5, '0.1.0', 1), isFalse);
    expect(isNewerVersion('1.0.0', 1, '0.9.9', 50), isTrue);
  });

  test('a release is parsed with its apk and checksum', () {
    final info = parseRelease({
      'tag_name': 'v0.2.0+2',
      'body': 'New things',
      'assets': [
        {'name': 'yonca.apk', 'browser_download_url': 'https://x/yonca.apk'},
        {'name': 'yonca.apk.sha256', 'browser_download_url': 'https://x/yonca.apk.sha256'},
      ],
    });
    expect(info!.version, '0.2.0');
    expect(info.build, 2);
    expect(info.apkUrl, 'https://x/yonca.apk');
    expect(info.sha256Url, 'https://x/yonca.apk.sha256');
    expect(parseRelease({'tag_name': 'v0.2.0', 'assets': []}), isNull);
  });

  test('app version matches pubspec', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line, 'version: $appVersion+$appBuild');
  });

  group('download needs a matching checksum', () {
    late HttpServer server;
    late Directory dir;
    final apk = List<int>.generate(2000, (i) => i % 251);
    var apkRequests = 0;
    var checksumText = '';
    var checksumStatus = 200;

    setUp(() async {
      apkRequests = 0;
      dir = Directory.systemTemp.createTempSync('yonca_update');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        if (req.uri.path == '/app.apk') {
          apkRequests++;
          req.response.add(apk);
        } else {
          req.response.statusCode = checksumStatus;
          req.response.write(checksumText);
        }
        await req.response.close();
      });
    });
    tearDown(() async {
      await server.close(force: true);
      dir.deleteSync(recursive: true);
    });

    UpdateInfo info({bool withChecksum = true}) => UpdateInfo(
          version: '9.9.9',
          build: 1,
          notes: '',
          apkUrl: 'http://127.0.0.1:${server.port}/app.apk',
          sha256Url: withChecksum ? 'http://127.0.0.1:${server.port}/app.sha256' : null,
          sizeBytes: apk.length,
        );

    Future<String?> codeOf(Future<File> f) async {
      try {
        await f;
        return null;
      } on UpdateException catch (e) {
        return e.code;
      }
    }

    test('a matching checksum installs', () async {
      checksumStatus = 200;
      checksumText = '${sha256.convert(apk)}  yonca.apk\n';
      final f = await UpdateService().download(info(), dir);
      expect(f.lengthSync(), apk.length);
    });

    test('a different checksum is refused and the file is deleted', () async {
      checksumStatus = 200;
      checksumText = '${sha256.convert([1, 2, 3])}  yonca.apk';
      expect(await codeOf(UpdateService().download(info(), dir)), 'checksum');
      expect(File('${dir.path}/yonca-9.9.9.apk').existsSync(), isFalse);
    });

    test('a release without a checksum file is refused before downloading', () async {
      expect(await codeOf(UpdateService().download(info(withChecksum: false), dir)), 'unverified');
      expect(apkRequests, 0);
    });

    test('a missing or garbled checksum file is refused before downloading', () async {
      checksumStatus = 404;
      checksumText = 'not found';
      expect(await codeOf(UpdateService().download(info(), dir)), 'unverified');
      checksumStatus = 200;
      checksumText = 'hello world';
      expect(await codeOf(UpdateService().download(info(), dir)), 'unverified');
      expect(apkRequests, 0);
    });
  });
}
