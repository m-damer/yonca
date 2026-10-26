import 'dart:io';

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
}
