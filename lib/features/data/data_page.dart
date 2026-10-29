import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../data/backup_runner.dart';
import '../../data/backup_service.dart';
import '../../data/drive_backup.dart';
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
class DataPage extends StatefulWidget {
  const DataPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  BackupService? _service;
  late final BackupRunner _runner = BackupRunner(c);
  DriveBackup get _drive => _runner.drive;
  StorageUse? _use;
  bool _offline = false;

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _service = await _runner.service();
    await _refresh();
    final online = await DriveBackup.online();
    if (mounted) setState(() => _offline = !online);
    if (c.driveEmail != null) await _drive.restore();
  }

  Future<void> _refresh() async {
    final u = await _service?.storageUse();
    if (mounted) setState(() => _use = u);
  }

  void _toast(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  /// Signs in to Google when needed. Returns false when cancelled or offline.
  Future<bool> _ensureDrive() async {
    final l = AppLocalizations.of(context);
    if (c.driveEmail != null && _drive.email != null) return true;
    if (!await DriveBackup.online()) {
      if (mounted) setState(() => _offline = true);
      return false;
    }
    try {
      final email = await _drive.connect();
      if (email == null) return false;
      await c.setPref(AppController.keyDriveEmail, email);
      unawaited(BackupScheduler.sync(c));
      return true;
    } catch (_) {
      if (mounted) _toast(l.driveFailed);
      return false;
    }
  }

  Future<void> _driveRow() async {
    final l = AppLocalizations.of(context);
    if (c.driveEmail == null) {
      await _ensureDrive();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.driveEmail!),
        actions: [
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.driveNotConnected, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (ok == true) {
      await _drive.disconnect();
      await c.setPref(AppController.keyDriveEmail, '');
      unawaited(BackupScheduler.sync(c));
    }
  }

  /// "Back up now": to Drive, with a progress dialog that can be hidden.
  Future<void> _backupDrive() async {
    final l = AppLocalizations.of(context);
    if (!await _ensureDrive() || !mounted) return;
    final prog = ValueNotifier<double>(0);
    var open = true;
    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.backingUpDrive),
        content: ValueListenableBuilder<double>(
          valueListenable: prog,
          builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.backingUpSub),
            const SizedBox(height: 14),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: v, minHeight: 8)),
            const SizedBox(height: 6),
            Text('${(v * 100).round()}%'),
          ]),
        ),
        actions: [DialogConfirm(l.hideBtn, onPressed: () => Navigator.of(ctx).pop())],
      ),
    ).then((_) => open = false));
    final nav = Navigator.of(context);
    String? message;
    try {
      await _runner.toDrive(progress: (v) => prog.value = v);
      message = l.driveSaved;
    } on DriveException catch (e) {
      if (e.problem == DriveProblem.offline && mounted) setState(() => _offline = true);
      message = e.problem == DriveProblem.offline ? l.driveOffline : l.driveFailed;
    } catch (_) {
      message = l.driveFailed;
    }
    if (open) nav.pop();
    prog.dispose();
    if (mounted) {
      _toast(message);
      setState(() {});
    }
  }

  /// "Save backup file": asks for an optional password, then opens the share sheet.
  Future<void> _backupFile() async {
    final l = AppLocalizations.of(context);
    final pw = await _askSavePassword();
    if (pw == null || !mounted) return;
    try {
      final f = await _runner.makeFile(password: pw);
      await c.markBackup(f.lengthSync());
      await Share.shareXFiles([XFile(f.path)]);
    } catch (_) {
      if (mounted) _toast(l.driveFailed);
    }
    if (mounted) setState(() {});
  }

  /// Returns the password ('' for none), or null when cancelled.
  Future<String?> _askSavePassword() async {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final ctrl = TextEditingController();
    final r = await showGlassSheet<String>(
      context,
      builder: (ctx) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.backupFileTitle, bottom: 12),
          GlassField(controller: ctrl, label: l.pwOptional, obscure: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_amber_rounded, size: 22, color: p.error),
              const SizedBox(width: 8),
              Expanded(child: Text(l.pwLoseWarn, style: TextStyle(fontSize: 13.5, height: 18.9 / 13.5, color: p.text2))),
            ]),
          ),
          SheetButtons(secondary: l.cancel, onSecondary: () => Navigator.of(ctx).pop(), primary: l.saveFileBtn, onPrimary: () => Navigator.of(ctx).pop(ctrl.text)),
        ]),
      ),
    );
    ctrl.dispose();
    return r;
  }

  /// Asks for the password of a protected backup. Returns null when cancelled.
  Future<String?> _askPassword(String fileName, {bool wrong = false}) async {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final ctrl = TextEditingController();
    final r = await showGlassSheet<String>(
      context,
      builder: (ctx) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.enterBackupPw),
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 12), child: Text(fileName, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 15, color: p.text2))),
          GlassField(controller: ctrl, label: l.pwLabel, obscure: true, autofocus: true, error: wrong ? l.pwWrong : null),
          const SizedBox(height: 16),
          SheetButtons(secondary: l.cancel, onSecondary: () => Navigator.of(ctx).pop(), primary: wrong ? l.tryAgain : l.restoreBackup, onPrimary: () => Navigator.of(ctx).pop(ctrl.text)),
        ]),
      ),
    );
    ctrl.dispose();
    return r;
  }

  /// Shared by "from file" and "from Drive": password, a plain question, a safety copy, then the staged restore.
  Future<void> _restoreFrom(File file, String name) async {
    final l = AppLocalizations.of(context);
    final svc = _service;
    if (svc == null) return;
    String? pw;
    BackupMeta? meta;
    var wrong = false;
    while (meta == null) {
      if (svc.needsPassword(file)) {
        pw = await _askPassword(name, wrong: wrong);
        if (pw == null || !mounted) return;
      }
      try {
        meta = await svc.inspect(file, password: pw);
      } on BackupException catch (e) {
        if (e.problem == 'wrong_password') {
          wrong = true;
          continue;
        }
        if (mounted) _toast(l.notABackup);
        return;
      }
    }
    if (!mounted) return;
    final date = dfmt(DateFormat.yMMMd(Localizations.localeOf(context).toString()), meta.createdAt);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.restoreConfirmTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        content: Text(l.restoreInfoContacts(date, meta!.contacts)),
        actions: [
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.restoreBackup, onPressed: () => Navigator.of(ctx).pop(true), danger: true),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // A safety copy of what is on the phone now, kept outside the data folder.
      final safe = await getApplicationSupportDirectory();
      await svc.createBackup(safe, now: DateTime(1970));
      await svc.stageRestore(file, password: pw);
      if (mounted) _toast(l.restoreStaged);
    } catch (_) {
      if (mounted) _toast(l.notABackup);
    }
  }

  Future<void> _restoreFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = res?.files.single.path;
    if (path == null || !mounted) return;
    await _restoreFrom(File(path), res!.files.single.name);
  }

  Future<void> _restoreDrive() async {
    final l = AppLocalizations.of(context);
    if (!await _ensureDrive() || !mounted) return;
    try {
      final info = await _drive.latest();
      if (info == null) {
        if (mounted) _toast(l.driveNoBackup);
        return;
      }
      final tmp = await getTemporaryDirectory();
      final f = await _drive.download(info, File('${tmp.path}/${info.name.isEmpty ? 'yonca-drive.zip' : info.name}'));
      if (mounted) await _restoreFrom(f, info.name);
    } on DriveException catch (e) {
      if (e.problem == DriveProblem.offline && mounted) setState(() => _offline = true);
      if (mounted) _toast(e.problem == DriveProblem.offline ? l.driveOffline : l.driveFailed);
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
          PillButton(label: l.saveBackupFirst, outlined: true, height: 48, onPressed: _backupFile),
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
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.delete, danger: true, onPressed: () => Navigator.of(ctx).pop(true)),
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
        final auto = const ['off', 'daily', 'weekly'].indexOf(c.autoBackup);
        return SettingsScaffold(title: l.dataTitle, children: [
          if (_offline)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(color: p.error.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.wifi_off, size: 22, color: p.error),
                const SizedBox(width: 12),
                Expanded(child: Text(l.driveOffline, style: const TextStyle(fontSize: 13.5, height: 18.9 / 13.5))),
              ]),
            ),
          SectionLabel(l.backupSection),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              SettingsRow(
                icon: Icons.cloud_outlined,
                title: l.driveTitle,
                subtitle: c.driveEmail ?? l.driveNotConnected,
                vpad: 11,
                onTap: _driveRow,
              ),
              Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: p.separator),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 0),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.backupLast, style: const TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w500)),
                      Text(has ? '${dfmt(DateFormat.yMMMd(locale), last)} · ${formatBytes(c.lastBackupBytes)}' : l.backupNever,
                          style: TextStyle(fontSize: 13, height: 18.2 / 13, color: p.text2)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: _service == null ? null : _backupDrive,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(8)),
                      child: Text(l.backupNow, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.onPrimary)),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 23, 16, 6),
                child: Align(alignment: AlignmentDirectional.centerStart, child: Text(l.backupAuto, style: TextStyle(fontSize: 13, height: 18.2 / 13, color: p.text2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SegControl(
                  weights: const [7, 7, 10],
                  labels: [l.autoOff, l.autoDaily, l.autoWeekly],
                  selected: auto < 0 ? 2 : auto,
                  onSelect: (i) async {
                    await c.setPref(AppController.keyAutoBackup, const ['off', 'daily', 'weekly'][i]);
                    unawaited(BackupScheduler.sync(c));
                  },
                ),
              ),
              SettingsSwitch(vpad: 11, title: l.backupWifiOnly, value: c.wifiOnly, onChanged: (v) async {
                await c.setFlag(AppController.keyWifiOnly, v);
                unawaited(BackupScheduler.sync(c));
              }),
              SettingsSwitch(vpad: 11, title: l.backupRemind, value: c.backupRemind, onChanged: (v) => c.setFlag(AppController.keyBackupRemind, v)),
            ]),
          ),
          const SizedBox(height: 10),
          SettingsGroup(children: [
            SettingsRow(icon: Icons.description_outlined, title: l.backupFileTitle, subtitle: l.backupFileSub, chevron: true, onTap: _service == null ? null : _backupFile),
          ]),
          SectionLabel(l.sectionRestore),
          SettingsGroup(children: [
            SettingsRow(icon: Icons.description_outlined, title: l.restoreFromFile, chevron: true, onTap: _service == null ? null : _restoreFile),
            SettingsRow(icon: Icons.cloud_outlined, title: l.restoreFromDrive, chevron: true, onTap: _service == null ? null : _restoreDrive),
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
                Text(l.storageBreakdown(u.photos, u.voice, u.others), style: TextStyle(fontSize: 12.5, height: 17.5 / 12.5, color: p.text2)),
              ],
              const SizedBox(height: 12),
              PillButton(label: l.clearCache, outlined: true, height: 44, onPressed: _clearCache),
            ]),
          ),
          const SizedBox(height: 20),
          PillButton(label: l.deleteEverything, outlined: true, danger: true, height: 48, onPressed: _deleteAll),
          Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 0), child: Text(l.dataPrivacyNote2, style: TextStyle(fontSize: 12.5, height: 17.5 / 12.5, color: p.text2))),
        ]);
      },
    );
  }
}
