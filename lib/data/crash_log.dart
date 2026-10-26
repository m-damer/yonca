import 'dart:io';

import 'update_service.dart';

/// Keeps the last unexpected error in a small text file so the next start can offer to send it.
class CrashLog {
  CrashLog(this.dir);
  final Directory dir;

  /// Set once at start so the error hooks can write to it.
  static CrashLog? instance;

  File get _file => File('${dir.path}/crash_report.txt');

  static const _maxChars = 6000;

  /// Writes the report. Never throws.
  void record(Object error, StackTrace? stack, {DateTime? now}) {
    try {
      final text = StringBuffer()
        ..writeln('YONCA $appVersion+$appBuild')
        ..writeln('Time: ${(now ?? DateTime.now()).toIso8601String()}')
        ..writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
        ..writeln()
        ..writeln(error.toString())
        ..writeln()
        ..writeln(stack?.toString() ?? '');
      var out = text.toString();
      if (out.length > _maxChars) out = out.substring(0, _maxChars);
      _file.writeAsStringSync(out);
    } catch (_) {}
  }

  /// The saved report, or null.
  Future<String?> pending() async => await _file.exists() ? await _file.readAsString() : null;

  Future<void> clear() async {
    if (await _file.exists()) await _file.delete();
  }
}
