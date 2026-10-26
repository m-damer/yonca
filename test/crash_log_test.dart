import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yonca/data/crash_log.dart';

void main() {
  test('a crash is saved, read back and cleared', () async {
    final dir = await Directory.systemTemp.createTemp('crash');
    final log = CrashLog(dir);
    expect(await log.pending(), isNull);
    log.record(StateError('boom'), StackTrace.current);
    final text = await log.pending();
    expect(text, contains('boom'));
    expect(text, contains('YONCA'));
    await log.clear();
    expect(await log.pending(), isNull);
    await dir.delete(recursive: true);
  });
}
