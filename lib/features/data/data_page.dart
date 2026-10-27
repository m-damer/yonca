import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../data/backup_service.dart';
import '../../data/report_builder.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../contacts/contact_widgets.dart';
import '../settings/settings_widgets.dart';
import '../sharing/share_helpers.dart';

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

/// Backup and data (design Bk): last backup, restore, export, storage and delete everything.
/// The design's Google Drive rows are replaced by the phone's share sheet, which can send the file to Drive.
class DataPage extends StatefulWidget {
  const DataPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  BackupService? _service;
  StorageUse? _use;
  bool _busy = false;

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final docs = await getApplicationDocumentsDirectory();
    final db = c.database;
    _service = BackupService(docs, flush: db == null ? null : () => db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)'));
    await _refresh();
  }

  Future<void> _refresh() async {
    final u = await _service?.storageUse();
    if (mounted) setState(() => _use = u);
  }

  void _toast(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  /// Makes the backup file and opens the share sheet. Returns false when it failed.
  Future<bool> _backup() async {
    setState(() => _busy = true);
    try {
      final tmp = await getTemporaryDirectory();
      final f = await _service!.createBackup(tmp);
      await c.markBackup(f.lengthSync());
      await Share.shareXFiles([XFile(f.path)]);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final l = AppLocalizations.of(context);
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    final file = res?.files.single;
    final path = file?.path;
    if (path == null || !mounted) return;
    final when = File(path).lastModifiedSync();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.restoreConfirmTitle),
        content: Text(l.restoreFromBackupInfo(dfmt(DateFormat.yMMMd(Localizations.localeOf(ctx).toString()), when))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.restoreBackup)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // A safety copy of what is on the phone now, kept outside the data folder.
      final safe = await getApplicationSupportDirectory();
      await _service!.createBackup(safe, now: DateTime(1970));
      await _service!.stageRestore(File(path));
      if (mounted) _toast(l.restoreStaged);
    } catch (_) {
      if (mounted) _toast(l.notABackup);
    }
  }

  Future<void> _csv() async {
    final l = AppLocalizations.of(context);
    final repo = c.contacts;
    if (repo == null) return;
    final all = await repo.list();
    final rows = <List<String>>[
      [l.colName, l.colCompany, l.colRoles, l.colRating, l.colPhone, l.colEmail, l.fieldRequirements],
      for (final s in all)
        [
          s.displayName,
          s.contact.company,
          s.roles.map((r) => roleLabel(l, r)).join('; '),
          ratingLabel(l, ratingFromName(s.contact.rating)),
          s.phones.map((p) => '${p.countryCode}${p.number}').join('; '),
          s.emails.map((e) => e.value).join('; '),
          s.contact.requirements,
        ],
    ];
    final tmp = await getTemporaryDirectory();
    final f = File('${tmp.path}/yonca-contacts.csv');
    await f.writeAsString(toCsv(rows));
    await Share.shareXFiles([XFile(f.path)]);
  }

  Future<void> _vcards() async {
    final repo = c.contacts;
    if (repo == null) return;
    await shareVCards(await repo.list(), name: 'yonca-contacts');
  }

  Future<void> _clearCache() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final tmp = await getTemporaryDirectory();
      if (tmp.existsSync()) {
        for (final e in tmp.listSync()) {
          try {
            e.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
    messenger.showSnackBar(SnackBar(content: Text(l.cacheCleared)));
  }

  /// Two steps like the design: type DELETE (with a way to save a backup first), then a last question.
  Future<void> _deleteAll() async {
    final l = AppLocalizations.of(context);
    final typed = TextEditingController();
    final go = await showGlassSheet<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.deleteSheetTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(l.deleteSheetBody, style: TextStyle(color: ctx.palette.text2)),
          const SizedBox(height: 14),
          GlassField(controller: typed, label: l.typeDeleteHint, onChanged: (_) => setS(() {})),
          const SizedBox(height: 12),
          PillButton(label: l.saveBackupFirst, outlined: true, height: 48, onPressed: _backup),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel))),
            Expanded(
              flex: 2,
              child: Opacity(
                opacity: typed.text.trim() == 'DELETE' ? 1 : .4,
                child: PillButton(label: l.nextLabel, height: 48, onPressed: typed.text.trim() == 'DELETE' ? () => Navigator.of(ctx).pop(true) : null),
              ),
            ),
          ]),
        ]),
      ),
    );
    typed.dispose();
    if (go != true || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteNowTitle),
        content: Text(l.deleteNowBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.palette.error, foregroundColor: ctx.palette.bg),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await c.database?.deleteAllData();
    _service?.deleteAttachedFiles();
    final s = c.schedule;
    if (s != null) {
      s.revision.value++;
      await s.onChanged?.call();
    }
    c.deals?.revision.value++;
    await _refresh();
    if (mounted) _toast(l.deleted);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final u = _use;
    final locale = Localizations.localeOf(context).toString();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final last = c.lastBackup;
        final has = last != null && c.lastBackupBytes > 0;
        return SettingsScaffold(title: l.dataTitle, children: [
          SectionLabel(l.backupSection),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.backupLast, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(has ? '${dfmt(DateFormat.yMMMd(locale), last)} · ${formatBytes(c.lastBackupBytes)}' : l.backupNever,
                          style: TextStyle(fontSize: 13, color: p.text2)),
                    ]),
                  ),
                  SizedBox(width: 160, child: PillButton(label: l.backupNow, height: 40, onPressed: _busy || _service == null ? null : _backup)),
                ]),
              ),
              Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: p.separator),
              SettingsSwitch(title: l.backupRemind, value: c.backupRemind, onChanged: (v) => c.setFlag(AppController.keyBackupRemind, v)),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child: Text(l.driveNote, style: TextStyle(fontSize: 12.5, color: p.text2))),
          SectionLabel(l.sectionRestore),
          SettingsGroup(children: [
            SettingsRow(icon: Icons.description_outlined, title: l.restoreFromFile, chevron: true, onTap: _service == null ? null : _restore),
          ]),
          SectionLabel(l.exportSection),
          SettingsGroup(children: [
            SettingsRow(icon: Icons.file_download_outlined, title: l.exportContactsCsv, chevron: true, onTap: _csv),
            SettingsRow(icon: Icons.people_outline, title: l.exportVCards, chevron: true, onTap: _vcards),
          ]),
          SectionLabel(l.sectionStorage),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(l.storageUsedTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                Text(u == null ? '' : formatBytes(u.total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              if (u != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(children: [
                      Expanded(flex: (u.databaseBytes + 1), child: ColoredBox(color: p.primary)),
                      Expanded(flex: (u.fileBytes + 1), child: ColoredBox(color: p.leaves[2])),
                      Expanded(flex: ((u.total + 1) ~/ 2), child: ColoredBox(color: p.track)),
                    ]),
                  ),
                ),
              if (u != null) ...[
                const SizedBox(height: 8),
                Text('${l.storageDb(formatBytes(u.databaseBytes))} · ${l.storageFiles(u.fileCount, formatBytes(u.fileBytes))}',
                    style: TextStyle(fontSize: 12.5, color: p.text2)),
              ],
              const SizedBox(height: 12),
              PillButton(label: l.clearCache, outlined: true, height: 46, onPressed: _clearCache),
            ]),
          ),
          const SizedBox(height: 20),
          PillButton(label: l.deleteEverything, outlined: true, danger: true, height: 48, onPressed: _deleteAll),
          Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 0), child: Text(l.dataPrivacyNote, style: TextStyle(fontSize: 12.5, color: p.text2))),
        ]);
      },
    );
  }
}
