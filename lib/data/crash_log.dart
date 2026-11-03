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
        ..writeln('YONCA $appVersionLabel+$appBuild')
        ..writeln('Time: ${(now ?? DateTime.now()).toIso8601String()}')
        ..writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
        ..writeln()
        ..writeln(error.toString())
        ..writeln()
        ..writeln(stack?.toString() ?? '');
      var out = text.toString();
      if (out.length > _maxChars) out = out.substring(0, _maxChars);
      _file.writeAsStringSync(out);
      _addToHistory(out);
    } catch (_) {}
  }

  File get _historyFile => File('${dir.path}/crash_history.txt');
  static const _sep = '\n=====YONCA-ENTRY=====\n';
  static const _historyMax = 80000;
  static String _lastKey = '';

  /// Adds the report to the permanent log (kept until the person clears it); the newest are kept when it grows.
  void _addToHistory(String entry) {
    // The same error repeating on every frame is recorded once.
    final key = entry.split('\n').skip(4).take(3).join('\n');
    if (key == _lastKey) return;
    _lastKey = key;
    var all = _historyFile.existsSync() ? _historyFile.readAsStringSync() : '';
    all = all.isEmpty ? entry : '$all$_sep$entry';
    if (all.length > _historyMax) {
      final cut = all.indexOf(_sep, all.length - _historyMax);
      all = cut < 0 ? all.substring(all.length - _historyMax) : all.substring(cut + _sep.length);
    }
    _historyFile.writeAsStringSync(all);
  }

  /// Every recorded error, newest first.
  Future<List<String>> history() async {
    if (!await _historyFile.exists()) return const [];
    final all = await _historyFile.readAsString();
    return all.split(_sep).where((e) => e.trim().isNotEmpty).toList().reversed.toList();
  }

  Future<void> clearHistory() async {
    _lastKey = '';
    if (await _historyFile.exists()) await _historyFile.delete();
  }

  /// The saved report, or null.
  Future<String?> pending() async => await _file.exists() ? await _file.readAsString() : null;

  Future<void> clear() async {
    if (await _file.exists()) await _file.delete();
  }
}
