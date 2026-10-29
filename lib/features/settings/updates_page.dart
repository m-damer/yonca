import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_controller.dart';
import '../../data/backup_runner.dart';
import '../../data/update_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../data/data_page.dart';
import 'settings_widgets.dart' show SettingsGroup, SettingsSwitch;

/// Updates (design S35): check GitHub for a newer version, download it, check it, hand it to Android.
class UpdatesPage extends StatefulWidget {
  const UpdatesPage({super.key, required this.controller, this.service});
  final AppController controller;
  final UpdateService? service;

  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}

enum _Phase { idle, checking, upToDate, available, downloading, error }

class _UpdatesPageState extends State<UpdatesPage> {
  late final UpdateService _service = widget.service ?? UpdateService();
  _Phase _phase = _Phase.idle;
  UpdateInfo? _info;
  double _progress = 0;
  String _error = 'failed';

  Future<void> _check() async {
    setState(() => _phase = _Phase.checking);
    try {
      final info = await _service.check();
      if (!mounted) return;
      setState(() {
        _info = info;
        _phase = info == null ? _Phase.upToDate : _Phase.available;
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
        Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 12), child: Text(l.backupFirstBody, style: TextStyle(fontSize: 15, height: 28 / 15, color: ctx.palette.text2))),
        PillButton(label: l.backupSaveBtn, icon: Icons.save_alt_outlined, onPressed: () => Navigator.of(ctx).pop(true)),
        const SizedBox(height: 8),
        TextButton(style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)), onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.skipLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      ]),
    );
    if (save == null || !mounted) return;
    if (save) {
      try {
        final f = await BackupRunner(widget.controller).makeFile();
        await Share.shareXFiles([XFile(f.path)]);
      } catch (_) {}
      if (!mounted) return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.updatesPermTitle),
        content: Text(l.updatesPermBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.updatesContinue)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
    });
    try {
      final dir = await getTemporaryDirectory();
      final File f = await _service.download(_info!, dir, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() => _phase = _Phase.available);
      await OpenFilex.open(f.path, type: 'application/vnd.android.package-archive');
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'failed' ? 'download' : e.code;
        _phase = _Phase.error;
      });
    }
  }

  String _errorText(AppLocalizations l) => switch (_error) {
        'offline' => l.updatesOffline,
        'checksum' => l.updatesChecksum,
        'download' => l.updatesDownloadFailed,
        _ => l.updatesFailed,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final info = _info;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 12),
                Expanded(child: Text(l.updatesTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: p.onHeader))),
              ]),
            ),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.updatesCurrent(appVersion), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (_phase == _Phase.checking) Text(l.updatesChecking),
                  if (_phase == _Phase.upToDate) Text(l.updatesUpToDate),
                  if (_phase == _Phase.error) Text(_errorText(l), style: TextStyle(color: p.error)),
                  if ((_phase == _Phase.available || _phase == _Phase.downloading) && info != null) ...[
                    Text(l.updatesAvailable(info.version), style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (info.notes.trim().isNotEmpty) ...[
                      SectionLabel(l.updatesNotes),
                      Text(info.notes),
                    ],
                  ],
                  if (_phase == _Phase.downloading) ...[
                    const SizedBox(height: 12),
                    Text(l.updatesDownloading),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: _progress > 0 ? _progress : null),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              if (_phase == _Phase.available && info != null) ...[
                PillButton(label: l.updatesInstall, onPressed: _install),
                const SizedBox(height: 8),
                if (widget.controller.database != null)
                  PillButton(
                    label: l.updatesBackupFirst,
                    outlined: true,
                    height: 48,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DataPage(controller: widget.controller))),
                  ),
              ] else if (_phase != _Phase.downloading)
                PillButton(label: l.updatesCheck, onPressed: _phase == _Phase.checking ? null : _check),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) => SettingsGroup(children: [
                  SettingsSwitch(
                    title: l.settingWeeklyUpdates,
                    subtitle: l.settingWeeklyUpdatesHint,
                    value: widget.controller.weeklyUpdateCheck,
                    onChanged: (v) => widget.controller.setFlag(AppController.keyWeeklyUpdate, v),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
