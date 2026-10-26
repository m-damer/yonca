import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_controller.dart';
import '../../data/backup_service.dart';
import '../../data/report_builder.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../contacts/contact_widgets.dart';
import '../sharing/share_helpers.dart';

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

/// Backup and data (design S26): storage use, backup file, restore, export and delete everything.
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final docs = await getApplicationDocumentsDirectory();
    final db = widget.controller.database;
    _service = BackupService(docs, flush: db == null ? null : () => db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)'));
    await _refresh();
  }

  Future<void> _refresh() async {
    final u = await _service?.storageUse();
    if (mounted) setState(() => _use = u);
  }

  void _toast(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final tmp = await getTemporaryDirectory();
      final f = await _service!.createBackup(tmp);
      await Share.shareXFiles([XFile(f.path)]);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final l = AppLocalizations.of(context);
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = res?.files.single.path;
    if (path == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.restoreConfirmTitle),
        content: Text(l.restoreConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.restoreBackup)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service!.stageRestore(File(path));
      _toast(l.restoreStaged);
    } catch (_) {
      _toast(l.notABackup);
    }
  }

  Future<void> _csv() async {
    final l = AppLocalizations.of(context);
    final repo = widget.controller.contacts;
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
    final repo = widget.controller.contacts;
    if (repo == null) return;
    await shareVCards(await repo.list(), name: 'yonca-contacts');
  }

  Future<void> _deleteAll() async {
    final l = AppLocalizations.of(context);
    var sure = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l.deleteEverything),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.deleteEverythingBody),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: sure,
              onChanged: (v) => setS(() => sure = v ?? false),
              title: Text(l.deleteEverythingConfirm),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
            TextButton(onPressed: sure ? () => Navigator.of(ctx).pop(true) : null, child: Text(l.delete)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await widget.controller.database?.deleteAllData();
    _service?.deleteAttachedFiles();
    final s = widget.controller.schedule;
    if (s != null) {
      s.revision.value++;
      await s.onChanged?.call();
    }
    widget.controller.deals?.revision.value++;
    await _refresh();
    if (mounted) _toast(l.deleted);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final u = _use;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                GlassIconButton(icon: Icons.arrow_back, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 14),
                Expanded(child: Text(l.dataTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: pal.onHeader))),
              ]),
            ),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.storageUse, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (u != null) ...[
                      Text(l.storageDb(formatBytes(u.databaseBytes))),
                      Text(l.storageFiles(u.fileCount, formatBytes(u.fileBytes))),
                    ],
                  ]),
                ),
              ),
              SectionLabel(l.backupSection),
              Text(l.createBackupHint, style: TextStyle(color: pal.text2)),
              const SizedBox(height: 8),
              PillButton(label: l.createBackup, height: 50, onPressed: _busy || _service == null ? null : _backup),
              const SizedBox(height: 8),
              PillButton(label: l.restoreBackup, outlined: true, height: 50, onPressed: _service == null ? null : _restore),
              const SizedBox(height: 8),
              Text(l.driveNote, style: TextStyle(fontSize: 12, color: pal.text2)),
              SectionLabel(l.exportSection),
              PillButton(label: l.exportContactsCsv, outlined: true, height: 50, onPressed: _csv),
              const SizedBox(height: 8),
              PillButton(label: l.exportVCards, outlined: true, height: 50, onPressed: _vcards),
              SectionLabel(l.dangerSection),
              TextButton(
                onPressed: _deleteAll,
                child: Text(l.deleteEverything, style: TextStyle(color: pal.error, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
