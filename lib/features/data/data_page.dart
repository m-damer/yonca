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
import '../../data/reminders.dart';
import '../../data/system_channel.dart';
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
import 'backup_sheet.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

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
  final Reminders _notes = NotificationReminders();
  StorageUse? _use;
  bool _offline = false;
  // 0..1 while a backup runs from this page, null when idle.
  final _driveRun = ValueNotifier<double?>(null);
  final _localRun = ValueNotifier<double?>(null);

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
    } catch (e) {
      if (mounted) _toast(_driveText(l, e));
      return false;
    }
  }

  /// The message for a Drive problem: the plain sentence, then what Google actually said (to diagnose it).
  String _driveText(AppLocalizations l, Object e) {
    if (e is DriveException && e.problem == DriveProblem.offline) return l.driveOffline;
    final detail = e is DriveException ? e.detail : driveErrorDetail(e);
    return detail.isEmpty ? l.driveFailed : '${l.driveFailed}\n$detail';
  }

  String _localText(AppLocalizations l, Object e) {
    if (e is LocalBackupException) {
      final base = switch (e.code) {
        'nofolder' => l.localNoFolder,
        'permission' => l.localNoAccess,
        _ => l.localFailed,
      };
      return e.detail.isEmpty ? base : '$base\n${e.detail}';
    }
    return l.localFailed;
  }

  /// Asks for the "manage files" permission when the phone has not given it yet. True when it is given.
  Future<bool> _ensureStorageAccess() async {
    if (await SystemChannel.canManageStorage()) return true;
    if (!mounted) return false;
    final l = AppLocalizations.of(context);
    final go = await showSheetDialog<bool>(
      context: context,
      builder: (ctx) => SheetDialog(
        title: Text(l.localPermTitle),
        content: Text(l.localPermBody),
        actions: [
          DialogCancel(l.notNowBtn, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.openPhoneSettings, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (go == true) await SystemChannel.openStorageSettings();
    return false;
  }

  /// Lets the person pick the phone folder for local backups. True when a folder is now set.
  Future<bool> _pickLocalFolder() async {
    String? dir;
    try {
      dir = await FilePicker.platform.getDirectoryPath();
    } catch (_) {}
    if (dir == null || dir.isEmpty) return c.localDir != null;
    await c.setPref(AppController.keyLocalDir, dir);
    unawaited(BackupScheduler.sync(c));
    await _ensureStorageAccess();
    return true;
  }

  Future<void> _localRow() async {
    await _pickLocalFolder();
    if (mounted) setState(() {});
  }

  /// "Back up now" to the phone folder, with a progress sheet that can be hidden.
  Future<void> _backupLocal() async {
    final l = AppLocalizations.of(context);
    if (c.localDir == null && !await _pickLocalFolder()) return;
    if (!mounted || !await _ensureStorageAccess() || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await showGlassSheet<void>(
      context,
      builder: (ctx) => BackupProgressSheet(
        title: l.notifLocalRunning,
        readyTitle: l.localSaved,
        canHide: true,
        run: (progress) async {
          _localRun.value = 0;
          try {
          final r = await runWithNotice(
            notes: _notes,
            id: 7306,
            title: l.notifLocalRunning,
            doneTitle: l.notifLocalDone,
            doneBody: l.notifLocalDoneBody(c.localDir!.split('/').where((e) => e.isNotEmpty).lastOrNull ?? c.localDir!),
            failedTitle: l.notifLocalFailed,
            failedBody: l.notifLocalFailedBody,
            doneId: 7307,
            failedId: 7308,
            work: (p) => _runner.toLocal(progress: (v) {
              progress(v);
              p(v);
              _localRun.value = v;
            }),
          );
          return BackupInfo(name: r.name, bytes: r.bytes);
          } finally {
            _localRun.value = null;
          }
        },
        errorText: (e) => _localText(l, e),
        onFinishedHidden: (ok, text) => messenger.showSnackBar(SnackBar(content: Text(ok ? l.localSaved : text))),
      ),
      dismissible: false,
    );
    if (mounted) setState(() {});
  }

  Future<void> _driveRow() async {
    final l = AppLocalizations.of(context);
    if (c.driveEmail == null) {
      await _ensureDrive();
      return;
    }
    final ok = await showSheetDialog<bool>(
      context: context,
      builder: (ctx) => SheetDialog(
        title: Text(c.driveEmail!),
        actions: [
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.driveDisconnect, onPressed: () => Navigator.of(ctx).pop(true)),
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
    final messenger = ScaffoldMessenger.of(context);
    await showGlassSheet<void>(
      context,
      builder: (ctx) => BackupProgressSheet(
        title: l.backingUpDrive,
        readyTitle: l.driveSaved,
        canHide: true,
        run: (progress) async {
          _driveRun.value = 0;
          try {
            final r = await runWithNotice(
              notes: _notes,
              id: 7300,
              title: l.notifBackupRunning,
              doneTitle: l.notifBackupDone,
              doneBody: l.notifBackupDoneBody,
              failedTitle: l.notifBackupFailed,
              failedBody: l.notifBackupFailedBody,
              work: (p) => _runner.toDrive(progress: (v) {
                progress(v);
                p(v);
                _driveRun.value = v;
              }),
            );
            return BackupInfo(name: r.name, bytes: r.bytes);
          } on DriveException catch (e) {
            if (e.problem == DriveProblem.offline && mounted) setState(() => _offline = true);
            rethrow;
          } finally {
            _driveRun.value = null;
          }
        },
        errorText: (e) => _driveText(l, e),
        onFinishedHidden: (ok, text) => messenger.showSnackBar(SnackBar(content: Text(ok ? l.driveSaved : text))),
      ),
      dismissible: false,
    );
    if (mounted) setState(() {});
  }

  /// "Save backup file": asks for an optional password, makes the file in the background with a progress
  /// sheet, then offers Save or share.
  Future<void> _backupFile() async {
    final l = AppLocalizations.of(context);
    final pw = await _askSavePassword();
    if (pw == null || !mounted) return;
    await showGlassSheet<void>(
      context,
      builder: (ctx) => BackupProgressSheet(
        title: l.backupMakingTitle,
        readyTitle: l.backupReadyTitle,
        protected: pw.isNotEmpty,
        run: (progress) async {
          final f = await _runner.makeFile(password: pw, onProgress: progress);
          final bytes = f.lengthSync();
          await c.markBackup(bytes);
          return BackupInfo(name: f.uri.pathSegments.last, bytes: bytes, file: f);
        },
        onShare: (f) => Share.shareXFiles([XFile(f.path)]),
      ),
      dismissible: false,
    );
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
            padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.lg, AppSpace.xs, AppSpace.lg),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Lu.triangleAlert, size: AppIcon.lg, color: p.error),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Text(l.pwLoseWarn, style: TextStyle(fontSize: AppFont.label, height: AppLine.normal, color: p.text2))),
            ]),
          ),
          SheetButtons(secondary: l.cancel, onSecondary: () => Navigator.of(ctx).pop(), primary: l.saveFileBtn, onPrimary: () => Navigator.of(ctx).pop(ctrl.text)),
        ]),
      ),
    );
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
          Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.md), child: Text(fileName, textDirection: TextDirection.ltr, style: TextStyle(fontSize: AppFont.body, color: p.text2))),
          GlassField(controller: ctrl, label: l.pwLabel, obscure: true, autofocus: true, error: wrong ? l.pwWrong : null),
          const SizedBox(height: AppSpace.lg),
          SheetButtons(secondary: l.cancel, onSecondary: () => Navigator.of(ctx).pop(), primary: wrong ? l.stateRetry : l.restoreBackup, onPrimary: () => Navigator.of(ctx).pop(ctrl.text)),
        ]),
      ),
    );
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
    final ok = await showSheetDialog<bool>(
      context: context,
      builder: (ctx) => SheetDialog(
        title: Text(l.restoreConfirmTitle, style: const TextStyle(fontSize: AppFont.headline, fontWeight: AppWeight.semibold)),
        content: Text(l.restoreInfoContacts(date, meta!.contacts)),
        actions: [
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.restoreBackup, onPressed: () => Navigator.of(ctx).pop(true), danger: true),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await showGlassSheet<void>(
      context,
      builder: (ctx) => BackupProgressSheet(
        title: l.restoreMakingTitle,
        workingSub: l.restoreMakingSub,
        readyTitle: l.restoreReadyTitle,
        readySub: l.restoreStaged,
        failedTitle: l.restoreFailedTitle,
        showFile: false,
        icon: Lu.history,
        errorText: (_) => l.notABackup,
        run: (progress) async {
          // A safety copy of what is on the phone now, kept outside the data folder.
          final safe = await getApplicationSupportDirectory();
          await svc.createBackupInBackground(safe, now: DateTime(1970), onProgress: (v) => progress(v * .5));
          progress(.55);
          await svc.stageRestoreInBackground(file, password: pw);
          progress(1);
          return const BackupInfo(name: '', bytes: 0);
        },
      ),
      dismissible: false,
    );
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
      final target = File('${tmp.path}/${info.name.isEmpty ? 'yonca-drive.zip' : info.name}');
      File? got;
      if (!mounted) return;
      await showGlassSheet<void>(
        context,
        builder: (ctx) => BackupProgressSheet(
          title: l.driveDownloading,
          readyTitle: l.driveDownloaded,
          icon: Lu.cloud,
          showFile: false,
          run: (progress) async {
            try {
              got = await runWithNotice(
                notes: _notes,
                id: 7305,
                title: l.notifRestoreRunning,
                failedTitle: l.notifRestoreFailed,
                failedBody: l.notifRestoreFailedBody,
                work: (p) => _drive.download(info, target, onProgress: (v) {
                  progress(v);
                  p(v);
                }),
              );
            } on DriveException catch (e) {
              if (e.problem == DriveProblem.offline && mounted) setState(() => _offline = true);
              rethrow;
            }
            return BackupInfo(name: info.name, bytes: info.bytes);
          },
          errorText: (e) => _driveText(l, e),
        ),
        dismissible: false,
      );
      final f = got;
      if (f != null && mounted) await _restoreFrom(f, info.name);
    } on DriveException catch (e) {
      if (e.problem == DriveProblem.offline && mounted) setState(() => _offline = true);
      if (mounted) _toast(_driveText(l, e));
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
          s.fullName,
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
          Text(l.deleteSheetTitle, style: const TextStyle(fontSize: AppFont.lead, fontWeight: AppWeight.semibold)),
          const SizedBox(height: AppSpace.sm),
          Text(l.deleteSheetBody, style: TextStyle(color: ctx.palette.text2)),
          const SizedBox(height: AppSpace.lg),
          GlassField(controller: typed, label: l.typeDeleteHint, onChanged: (_) => setS(() {})),
          const SizedBox(height: AppSpace.md),
          PillButton(label: l.saveBackupFirst, outlined: true, height: AppControl.lg, onPressed: _backupFile),
          const SizedBox(height: AppSpace.md),
          Row(children: [
            Expanded(child: TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel))),
            Expanded(
              flex: 2,
              child: Opacity(
                opacity: typed.text.trim() == 'DELETE' ? 1 : .4,
                child: PillButton(label: l.nextLabel, height: AppControl.lg, onPressed: typed.text.trim() == 'DELETE' ? () => Navigator.of(ctx).pop(true) : null),
              ),
            ),
          ]),
        ]),
      ),
    );
    if (go != true || !mounted) return;
    final ok = await showSheetDialog<bool>(
      context: context,
      builder: (ctx) => SheetDialog(
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
        final last = c.lastDriveBackup;
        final has = last != null && c.lastDriveBytes > 0;
        final tried = c.driveTry;
        String when(DateTime d) => dfmt(DateFormat.yMMMd(locale).add_jm(), d);
        final tryText = tried == null || (last != null && !tried.at.isAfter(last))
            ? null
            : switch (tried.reason) {
                'offline' => l.backupTryOffline(when(tried.at)),
                'wifi' => l.backupTryWifi(when(tried.at)),
                'signin' => l.backupTrySignin(when(tried.at)),
                _ => l.backupTryError(when(tried.at)),
              };
        final auto = const ['off', 'daily', 'weekly'].indexOf(c.autoBackup);
        final autoLocal = const ['off', 'daily', 'weekly'].indexOf(c.autoLocal);
        return SettingsScaffold(title: l.dataTitle, children: [
          if (_offline)
            Container(
              margin: const EdgeInsets.only(top: AppSpace.xs, bottom: AppSpace.xs),
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
              decoration: BoxDecoration(color: p.error.withValues(alpha: AppAlpha.faint), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Lu.wifiOff, size: AppIcon.lg, color: p.error),
                const SizedBox(width: AppSpace.md),
                Expanded(child: Text(l.driveOffline, style: const TextStyle(fontSize: AppFont.label, height: AppLine.normal))),
              ]),
            ),
          SectionLabel(l.backupSection),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              SettingsRow(
                icon: Lu.cloud,
                title: l.driveTitle,
                subtitle: c.driveEmail ?? l.driveNotConnected,
                vpad: AppSpace.rowS,
                onTap: _driveRow,
              ),
              Divider(height: AppStroke.hairline, thickness: AppStroke.hairline, indent: AppSpace.lg, endIndent: AppSpace.lg, color: p.separator),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.backupLast, style: const TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: AppWeight.medium)),
                      Text(has ? '${when(last)} · ${formatBytes(c.lastDriveBytes)}' : l.backupNever,
                          style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
                      if (tryText != null) Text('${l.backupTryTitle}: $tryText', style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.noticeFg)),
                    ]),
                  ),
                ]),
              ),
              _BackupAction(
                run: _driveRun,
                label: l.backupToDriveNow,
                onTap: _service == null ? null : _backupDrive,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xxl, AppSpace.lg, AppSpace.sm),
                child: Align(alignment: AlignmentDirectional.centerStart, child: Text(l.backupAuto, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
                child: SegControl(
                  labels: [l.autoOff, l.autoDaily, l.autoWeekly],
                  selected: auto < 0 ? 2 : auto,
                  onSelect: (i) async {
                    await c.setPref(AppController.keyAutoBackup, const ['off', 'daily', 'weekly'][i]);
                    unawaited(BackupScheduler.sync(c));
                  },
                ),
              ),
              SettingsSwitch(vpad: AppSpace.rowS, title: l.backupWifiOnly, value: c.wifiOnly, onChanged: (v) async {
                await c.setFlag(AppController.keyWifiOnly, v);
                unawaited(BackupScheduler.sync(c));
              }),
              SettingsSwitch(vpad: AppSpace.rowS, title: l.backupRemind, value: c.backupRemind, onChanged: (v) => c.setFlag(AppController.keyBackupRemind, v)),
            ]),
          ),
          const SizedBox(height: AppSpace.md),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              SettingsRow(
                icon: Lu.smartphone,
                title: l.localTitle,
                subtitle: c.localDir ?? l.localChoose,
                vpad: AppSpace.rowS,
                onTap: _localRow,
              ),
              Divider(height: AppStroke.hairline, thickness: AppStroke.hairline, indent: AppSpace.lg, endIndent: AppSpace.lg, color: p.separator),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.backupLast, style: const TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: AppWeight.medium)),
                      Text(
                        c.lastLocalBackup != null && c.lastLocalBytes > 0 ? '${dfmt(DateFormat.yMMMd(locale).add_jm(), c.lastLocalBackup!)} · ${formatBytes(c.lastLocalBytes)}' : l.backupNever,
                        style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2),
                      ),
                    ]),
                  ),
                ]),
              ),
              _BackupAction(
                run: _localRun,
                label: l.backupLocalNow,
                onTap: _service == null ? null : _backupLocal,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xxl, AppSpace.lg, AppSpace.sm),
                child: Align(alignment: AlignmentDirectional.centerStart, child: Text(l.backupAuto, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
                child: SegControl(
                  labels: [l.autoOff, l.autoDaily, l.autoWeekly],
                  selected: autoLocal < 0 ? 0 : autoLocal,
                  onSelect: (i) async {
                    if (i != 0 && c.localDir == null && !await _pickLocalFolder()) return;
                    await c.setPref(AppController.keyAutoLocal, const ['off', 'daily', 'weekly'][i]);
                    unawaited(BackupScheduler.sync(c));
                  },
                ),
              ),
            ]),
          ),
          const SizedBox(height: AppSpace.md),
          SettingsGroup(children: [
            SettingsRow(icon: Lu.fileText, title: l.backupFileTitle, subtitle: l.backupFileSub, chevron: true, onTap: _service == null ? null : _backupFile),
          ]),
          SectionLabel(l.sectionRestore),
          SettingsGroup(children: [
            SettingsRow(icon: Lu.fileText, title: l.restoreFromFile, chevron: true, onTap: _service == null ? null : _restoreFile),
            SettingsRow(icon: Lu.cloud, title: l.restoreFromDrive, chevron: true, onTap: _service == null ? null : _restoreDrive),
          ]),
          SectionLabel(l.exportSection),
          SettingsGroup(children: [
            SettingsRow(icon: Lu.fileDown, title: l.exportContactsCsv, chevron: true, onTap: _csv),
            SettingsRow(icon: Lu.users, title: l.exportVCards, chevron: true, onTap: _vcards),
          ]),
          SectionLabel(l.sectionStorage),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(l.storageUsedTitle, style: const TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.semibold))),
                Text(u == null ? '' : formatBytes(u.total), style: const TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.semibold)),
              ]),
              const SizedBox(height: AppSpace.md),
              if (u != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: SizedBox(
                    height: AppSize.s8,
                    child: Row(children: [
                      Expanded(flex: (u.databaseBytes + 1), child: ColoredBox(color: p.primary)),
                      Expanded(flex: (u.fileBytes + 1), child: ColoredBox(color: p.leaves[2])),
                      Expanded(flex: ((u.total + 1) ~/ 2), child: ColoredBox(color: p.track)),
                    ]),
                  ),
                ),
              if (u != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(l.storageBreakdown(u.photos, u.voice, u.others), style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
              ],
              const SizedBox(height: AppSpace.md),
              PillButton(label: l.clearCache, outlined: true, height: AppControl.lg, onPressed: _clearCache),
            ]),
          ),
          const SizedBox(height: AppSpace.xl),
          PillButton(label: l.deleteEverything, outlined: true, danger: true, height: AppControl.lg, onPressed: _deleteAll),
          Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.md, AppSpace.xs, 0), child: Text(l.dataPrivacyNote2, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2))),
        ]);
      },
    );
  }
}

/// The full-width backup button of a card: shows the bar and percent while it runs, and is off until it ends.
class _BackupAction extends StatelessWidget {
  const _BackupAction({required this.run, required this.label, required this.onTap});
  final ValueNotifier<double?> run;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return ValueListenableBuilder<double?>(
      valueListenable: run,
      builder: (context, v, _) {
        final busy = v != null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (busy) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: LinearProgressIndicator(value: v, minHeight: AppSpace.sm, backgroundColor: p.track, color: p.primary),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(l.backupRunning((v * 100).round()), style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
              const SizedBox(height: AppSpace.md),
            ],
            Opacity(
              opacity: busy ? AppAlpha.disabled : 1,
              child: PillButton(label: label, height: AppControl.lg, onPressed: busy ? null : onTap),
            ),
          ]),
        );
      },
    );
  }
}
