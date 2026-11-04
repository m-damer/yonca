import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_database.dart';

/// Photos, voice notes and documents are saved in the app's documents folder, and the database keeps
/// each one's full path. After a restore, a reinstall under another app id, or a move to another phone,
/// that folder has a different path, so every stored path points at nothing. This finds each file again
/// inside the current documents folder and rewrites the path.
class PathRebase {
  static const _marker = 'paths.docsDir';

  /// The new path for [path], or null when it already works or the file cannot be found.
  static String? fixed(String path, Directory docs, Set<String> top) {
    if (path.isEmpty || File(path).existsSync()) return null;
    final parts = p.split(path);
    for (var i = 0; i < parts.length; i++) {
      if (!top.contains(parts[i])) continue;
      final candidate = p.joinAll([docs.path, ...parts.sublist(i)]);
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  /// Fixes every stored file path. Does the work once per documents folder (it is cheap to skip).
  /// Returns how many paths were rewritten.
  static Future<int> run(AppDatabase db, Directory docs) async {
    if (await db.getSetting(_marker) == docs.path) return 0;
    final top = {
      for (final e in docs.listSync(followLinks: false))
        if (!p.basename(e.path).startsWith('yonca.sqlite')) p.basename(e.path),
    };
    var changed = 0;
    for (final t in const [
      ('contacts', 'photo_path'),
      ('activities', 'voice_path'),
      ('activity_files', 'path'),
      ('task_files', 'path'),
      ('deal_documents', 'path'),
    ]) {
      final rows = await db.customSelect("SELECT id, ${t.$2} AS v FROM ${t.$1} WHERE ${t.$2} IS NOT NULL AND ${t.$2} != ''").get();
      for (final r in rows) {
        final nw = fixed(r.read<String>('v'), docs, top);
        if (nw == null) continue;
        await db.customStatement('UPDATE ${t.$1} SET ${t.$2} = ? WHERE id = ?', [nw, r.read<int>('id')]);
        changed++;
      }
    }
    final photo = await db.getSetting('profile.photo') ?? '';
    final photoNew = fixed(photo, docs, top);
    if (photoNew != null) {
      await db.putSetting('profile.photo', photoNew);
      changed++;
    }
    final qr = await db.getSetting('qr.saved') ?? '';
    if (qr.isNotEmpty) {
      try {
        final list = jsonDecode(qr) as List;
        var edited = false;
        for (final x in list) {
          if (x is! Map) continue;
          final nw = fixed((x['logo'] as String?) ?? '', docs, top);
          if (nw != null) {
            x['logo'] = nw;
            edited = true;
            changed++;
          }
        }
        if (edited) await db.putSetting('qr.saved', jsonEncode(list));
      } catch (_) {}
    }
    // A backup folder chosen on another phone may not exist here: forget it instead of failing every night.
    final dir = await db.getSetting('backup.localDir') ?? '';
    if (dir.isNotEmpty && !Directory(dir).existsSync()) {
      await db.putSetting('backup.localDir', '');
      await db.putSetting('backup.autoLocal', 'off');
    }
    await db.putSetting(_marker, docs.path);
    return changed;
  }
}
