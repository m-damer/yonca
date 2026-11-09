import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../data/backup_sheet.dart';

import '../../shared/ds.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_controller.dart';
import '../../data/backup_runner.dart';
import '../../data/system_channel.dart';
import '../../data/update_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'settings_widgets.dart' show SettingsGroup, SettingsRow;
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

/// Updates (design S35): check GitHub for a newer version, download it, check it, hand it to Android.
class UpdatesPage extends StatefulWidget {
  const UpdatesPage({super.key, required this.controller, this.service, this.fromNotification = false});
  final AppController controller;
  final UpdateService? service;

  /// Opened from an update notification: goes straight to installing a downloaded file.
  final bool fromNotification;

  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}

enum _Phase { idle, checking, upToDate, available, ready, permission, downloading, error }

class _UpdatesPageState extends State<UpdatesPage> {
  late final UpdateService _service = widget.service ?? UpdateService();
  _Phase _phase = _Phase.idle;
  UpdateInfo? _info;
  String _error = 'failed';
  DateTime? _checkedAt;

  @override
  void initState() {
    super.initState();
    final ms = int.tryParse(widget.controller.pref(AppController.keyLastUpdateCheck) ?? '');
    if (ms != null) _checkedAt = DateTime.fromMillisecondsSinceEpoch(ms);
    final m = widget.controller.updates;
    final ready = m.readyVersion;
    if (m.busy) {
      _info = m.info;
      _phase = _Phase.downloading;
    } else if (ready != null && m.readyFile() != null) {
      _info = UpdateInfo(version: ready, build: 0, notes: '', apkUrl: '', sha256Url: null);
      _phase = _Phase.ready;
    }
    if (widget.fromNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_phase == _Phase.ready) {
          _install();
        } else if (_phase != _Phase.downloading) {
          _check();
        }
      });
    }
  }

  Future<void> _check() async {
    setState(() => _phase = _Phase.checking);
    try {
      final info = await _service.check();
      if (!mounted) return;
      final now = DateTime.now();
      unawaited(widget.controller.setPref(AppController.keyLastUpdateCheck, '${now.millisecondsSinceEpoch}'));
      setState(() {
        _checkedAt = now;
        _info = info;
        final m = widget.controller.updates;
        _phase = info == null ? _Phase.upToDate : (m.busy ? _Phase.downloading : (m.readyVersion == info.version && m.readyFile() != null ? _Phase.ready : _Phase.available));
      });
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code;
        _phase = _Phase.error;
      });
    }
  }

  Future<void> _install() async {
    final l = AppLocalizations.of(context);
    final save = await showGlassSheet<bool>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.backupFirstTitle),
        Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.md), child: Text(l.backupFirstBody, style: TextStyle(fontSize: AppFont.body, height: AppLine.airy, color: ctx.palette.text2))),
        PillButton(label: l.backupSaveBtn, icon: Lu.save, onPressed: () => Navigator.of(ctx).pop(true)),
        const SizedBox(height: AppSpace.sm),
        TextButton(style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)), onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.skipLabel, style: const TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.semibold))),
      ]),
    );
    if (save == null || !mounted) return;
    if (save) {
      await showGlassSheet<void>(
        context,
        builder: (ctx) => BackupProgressSheet(
          title: l.backupMakingTitle,
          readyTitle: l.backupReadyTitle,
          run: (progress) async {
            final f = await BackupRunner(widget.controller).makeFile(onProgress: progress);
            return BackupInfo(name: f.uri.pathSegments.last, bytes: f.lengthSync(), file: f);
          },
          onShare: (f) => Share.shareXFiles([XFile(f.path)]),
        ),
        dismissible: false,
      );
      if (!mounted) return;
    }
    if (!await SystemChannel.canInstallPackages()) {
      if (mounted) setState(() => _phase = _Phase.permission);
      return;
    }
    await _download();
  }

  Future<void> _download() async {
    final m = widget.controller.updates;
    final ready = m.readyFile();
    if (ready != null && m.readyVersion == _info?.version) {
      await _open(ready);
      return;
    }
    if (_info == null || _info!.apkUrl.isEmpty) return;
    setState(() => _phase = _Phase.downloading);
    try {
      final f = await m.start(_info!);
      if (!mounted) return;
      if (f == null) {
        setState(() => _phase = _Phase.available);
        return;
      }
      setState(() => _phase = _Phase.ready);
      await _open(f);
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'failed' ? 'download' : e.code;
        _phase = _Phase.error;
      });
    }
  }

  Future<void> _open(File f) async {
    try {
      final r = await OpenFilex.open(f.path, type: 'application/vnd.android.package-archive');
      // The installer is on screen: the update replaces this app, so close its old card in recent apps.
      if (r.type == ResultType.done) await SystemChannel.closeTask();
    } catch (_) {}
  }

  String _errorText(AppLocalizations l) => switch (_error) {
        'offline' => l.updatesOffline,
        'checksum' => l.updatesBadFileTitle,
        'unverified' => l.updatesUnverifiedTitle,
        'download' => l.updatesDownloadFailed,
        _ => l.updatesFailed,
      };

  String _mb(AppLocalizations l, num bytes) => l.updatesMb((bytes / (1024 * 1024)).toStringAsFixed(1));

  Widget _hero(YoncaPalette p, IconData icon, {bool error = false}) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.xxl),
        child: IconTile(
          icon: icon,
          size: AppControl.hero,
          iconSize: AppIcon.x3,
          background: error ? p.errorContainer : p.surface2,
          color: error ? p.onErrorContainer : p.primary,
        ),
      );

  Widget _header(AppLocalizations l, YoncaPalette p, {bool back = true}) => HeaderBand(
        padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, 0),
        child: SafeArea(
          bottom: false,
          child: Row(children: [
            if (back) GlassIconButton(icon: Lu.chevronLeft, onHeader: true, onTap: () => Navigator.of(context).maybePop()) else const SizedBox(height: AppControl.lg),
            const SizedBox(width: AppSpace.md),
            if (back) Expanded(child: PageTitle(l.updatesTitle)),
          ]),
        ),
      );

  /// Full-page message with a hero tile, a title, a line of text and buttons at the bottom (AB6 to AB8).
  Widget _message(AppLocalizations l, YoncaPalette p,
      {required IconData icon,
      bool error = false,
      required String title,
      String? body,
      double top = 80,
      Widget? extra,
      required List<Widget> actions,
      bool back = true}) {
    return Column(children: [
      _header(l, p, back: back),
      Expanded(
        child: ListView(padding: EdgeInsets.fromLTRB(AppSpace.x3, top, AppSpace.x3, 0), children: [
          Align(alignment: AlignmentDirectional.centerStart, child: _hero(p, icon, error: error)),
          Text(title, style: TextStyle(fontSize: AppFont.headline, height: AppLine.loose, fontWeight: AppWeight.semibold, color: p.text)),
          if (body != null) Padding(padding: const EdgeInsets.only(top: AppSpace.sm), child: Text(body, style: TextStyle(color: p.text2))),
          if (extra != null) extra,
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.xxl, 0, AppSpace.xxl, AppSpace.x3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: actions),
      ),
    ]);
  }

  Widget _textButton(YoncaPalette p, String label, VoidCallback onTap) => TextButton(
        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: onTap,
        child: Text(label, style: TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.semibold, color: p.primary)),
      );

  List<String> _noteLines(String notes, String lang) => releaseNoteLines(notes, lang);


  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.controller.updates, builder: (context, _) => _page(context));

  Widget _page(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final info = _info;
    final locale = Localizations.localeOf(context).toString();
    final Widget body;
    switch (_phase) {
      case _Phase.permission:
        body = _message(l, p,
            icon: Lu.lock,
            title: l.updatesPermTitle,
            body: l.updatesPermBody,
            top: 70,
            actions: [
              PillButton(
                label: l.openPhoneSettings,
                onPressed: () async {
                  await SystemChannel.openInstallSettings();
                  if (mounted) setState(() => _phase = _Phase.available);
                },
              ),
              _textButton(p, l.notNowBtn, () => setState(() => _phase = _Phase.available)),
            ]);
      case _Phase.downloading:
        final progress = widget.controller.updates.progress;
        final total = info?.sizeBytes ?? 0;
        body = _message(l, p,
            icon: Lu.download,
            title: l.updatesDownloadingTitle(info?.version ?? ''),
            body: total > 0 ? l.updatesProgress(((total * progress) / (1024 * 1024)).toStringAsFixed(1), (total / (1024 * 1024)).toStringAsFixed(1)) : null,
            top: 90,
            back: false,
            extra: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: AppSpace.xl),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: LinearProgressIndicator(value: progress > 0 ? progress : null, minHeight: AppSize.s8, backgroundColor: p.separator, color: p.primary),
              ),
              Padding(padding: const EdgeInsets.only(top: AppSpace.lg), child: Text(l.updatesDownloadNote, style: TextStyle(fontSize: AppFont.label, color: p.text2))),
            ]),
            actions: [
              PillButton(label: l.updatesBackground, onPressed: () => Navigator.of(context).maybePop()),
              _textButton(p, l.cancel, () {
                widget.controller.updates.cancel();
                setState(() => _phase = _Phase.available);
              }),
            ]);
      case _Phase.ready:
        body = _message(l, p,
            icon: Lu.download,
            title: l.updatesReadyTitle(info?.version ?? ''),
            body: l.updatesReadyBody,
            top: 90,
            actions: [
              PillButton(label: l.updatesInstall, onPressed: _install),
              _textButton(p, l.updatesClose, () => Navigator.of(context).maybePop()),
            ]);
      case _Phase.error when _error == 'checksum' || _error == 'unverified' || _error == 'download':
        body = _message(l, p,
            icon: Lu.triangleAlert,
            error: true,
            title: switch (_error) { 'checksum' => l.updatesBadFileTitle, 'unverified' => l.updatesUnverifiedTitle, _ => l.updatesDownloadFailed },
            body: switch (_error) { 'checksum' => l.updatesBadFileBody, 'unverified' => l.updatesUnverifiedBody, _ => null },
            actions: [
              PillButton(label: l.updatesDownloadAgain, onPressed: _install),
              _textButton(p, l.updatesClose, () => setState(() => _phase = _Phase.available)),
            ]);
      case _Phase.available:
        body = Column(children: [
          _header(l, p),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.xxl), children: [
              GlassCard(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Row(children: [
                  Container(
                    width: AppSize.s36,
                    height: AppControl.md,
                    decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Icon(Lu.download, size: AppIcon.md, color: p.primary),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.updatesAvailable(info?.version ?? ''), style: TextStyle(fontSize: AppFont.lead, fontWeight: AppWeight.semibold, color: p.text)),
                      Text(
                        (info?.sizeBytes ?? 0) > 0 ? l.updatesYouHaveSize(appVersion, _mb(l, info!.sizeBytes)) : l.updatesYouHave(appVersion),
                        style: TextStyle(fontSize: AppFont.meta, color: p.text2),
                      ),
                    ]),
                  ),
                ]),
              ),
              if (info != null && _noteLines(info.notes, Localizations.localeOf(context).languageCode).isNotEmpty) ...[
                SectionLabel(l.updatesNotes, padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.sm)),
                SettingsGroup(children: [
                  for (final line in _noteLines(info.notes, Localizations.localeOf(context).languageCode))
                    SettingsRow(leadingWidget: Icon(Lu.check, size: AppIcon.lg, color: p.primary), title: line, titleWeight: AppWeight.regular),
                ]),
              ],
              const SizedBox(height: AppSpace.xl),
              PillButton(label: l.updatesInstall, height: AppControl.xl, onPressed: _install),
            ]),
          ),
        ]);
      default:
        final at = _checkedAt;
        final now = DateTime.now();
        final subtitle = at == null
            ? null
            : (at.year == now.year && at.month == now.month && at.day == now.day)
                ? l.updatesCheckedToday(appVersion, DateFormat.Hm(locale).format(at))
                : l.updatesCheckedOn(appVersion, DateFormat('d MMM', locale).format(at));
        body = Column(children: [
          _header(l, p),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.xxl), children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.x4, bottom: AppSpace.md),
                child: Column(children: [
                  _hero(p, _phase == _Phase.error ? Lu.circleAlert : (_phase == _Phase.upToDate ? Lu.check : Lu.refreshCw), error: _phase == _Phase.error),
                  Text(
                    _phase == _Phase.error
                        ? _errorText(l)
                        : (_phase == _Phase.checking ? l.updatesChecking : (_phase == _Phase.upToDate ? l.updatesUpToDateTitle : l.aboutVersion(appVersion))),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: AppFont.display, height: AppLine.relaxed, fontWeight: AppWeight.semibold, color: p.text),
                  ),
                  if (subtitle != null && _phase != _Phase.error)
                    Padding(padding: const EdgeInsets.only(top: AppSpace.sm), child: Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: p.text2))),
                ]),
              ),
              const SizedBox(height: AppSpace.xl),
              PillButton(label: l.updatesCheck, icon: Lu.refreshCw, outlined: true, height: AppControl.xl, onPressed: _phase == _Phase.checking ? null : _check),
            ]),
          ),
        ]);
    }
    return Scaffold(backgroundColor: Colors.transparent, body: GlassBackdrop(child: body));
  }
}

/// Release notes in the app's language. A release body can hold English first, then a line `---AR---`, then Arabic;
/// older releases have one language only and are shown as they are.
List<String> releaseNoteLines(String notes, String lang) {
  var text = notes;
  final parts = notes.split(RegExp(r'^\s*---AR---\s*$', multiLine: true));
  if (parts.length > 1) {
    final ar = parts[1].trim();
    text = lang == 'ar' && ar.isNotEmpty ? ar : parts[0];
  }
  return [
    for (final raw in text.split('\n'))
      if (raw.trim().isNotEmpty && !raw.trim().startsWith('#')) raw.trim().replaceFirst(RegExp(r'^[-*•]\s*'), ''),
  ].take(8).toList();
}
