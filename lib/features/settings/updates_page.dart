import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_controller.dart';
import '../../data/backup_runner.dart';
import '../../data/system_channel.dart';
import '../../data/update_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../data/data_page.dart';
import 'settings_widgets.dart' show SettingsGroup, SettingsRow;

/// Updates (design S35): check GitHub for a newer version, download it, check it, hand it to Android.
class UpdatesPage extends StatefulWidget {
  const UpdatesPage({super.key, required this.controller, this.service});
  final AppController controller;
  final UpdateService? service;

  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}

enum _Phase { idle, checking, upToDate, available, permission, downloading, error }

class _UpdatesPageState extends State<UpdatesPage> {
  late final UpdateService _service = widget.service ?? UpdateService();
  _Phase _phase = _Phase.idle;
  UpdateInfo? _info;
  double _progress = 0;
  String _error = 'failed';
  DateTime? _checkedAt;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    final ms = int.tryParse(widget.controller.pref(AppController.keyLastUpdateCheck) ?? '');
    if (ms != null) _checkedAt = DateTime.fromMillisecondsSinceEpoch(ms);
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
    if (!await SystemChannel.canInstallPackages()) {
      if (mounted) setState(() => _phase = _Phase.permission);
      return;
    }
    await _download();
  }

  Future<void> _download() async {
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
      _cancelled = false;
    });
    try {
      final dir = await getTemporaryDirectory();
      final File f = await _service.download(_info!, dir, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() => _phase = _Phase.available);
      if (_cancelled) return;
      await OpenFilex.open(f.path, type: 'application/vnd.android.package-archive');
    } on UpdateException catch (e) {
      if (!mounted || _cancelled) return;
      setState(() {
        _error = e.code == 'failed' ? 'download' : e.code;
        _phase = _Phase.error;
      });
    }
  }

  String _errorText(AppLocalizations l) => switch (_error) {
        'offline' => l.updatesOffline,
        'checksum' => l.updatesBadFileTitle,
        'download' => l.updatesDownloadFailed,
        _ => l.updatesFailed,
      };

  String _mb(AppLocalizations l, num bytes) => l.updatesMb((bytes / (1024 * 1024)).toStringAsFixed(1));

  Widget _hero(YoncaPalette p, IconData icon, {bool error = false}) => Container(
        width: 76,
        height: 76,
        margin: const EdgeInsets.only(bottom: 22),
        decoration: BoxDecoration(color: error ? p.errorContainer : p.surface2, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 36, color: error ? p.onErrorContainer : p.primary),
      );

  Widget _header(AppLocalizations l, YoncaPalette p, {bool back = true}) => HeaderBand(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: SafeArea(
          bottom: false,
          child: Row(children: [
            if (back) GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()) else const SizedBox(height: 44),
            const SizedBox(width: 12),
            if (back) Expanded(child: Text(l.updatesTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: p.onHeader))),
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
        child: ListView(padding: EdgeInsets.fromLTRB(28, top, 28, 0), children: [
          Align(alignment: AlignmentDirectional.centerStart, child: _hero(p, icon, error: error)),
          Text(title, style: TextStyle(fontSize: 24, height: 38 / 24, fontWeight: FontWeight.w600, color: p.text)),
          if (body != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(body, style: TextStyle(color: p.text2))),
          if (extra != null) extra,
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: actions),
      ),
    ]);
  }

  Widget _textButton(YoncaPalette p, String label, VoidCallback onTap) => TextButton(
        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: onTap,
        child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.primary)),
      );

  List<String> _noteLines(String notes) => [
        for (final raw in notes.split('\n'))
          if (raw.trim().isNotEmpty && !raw.trim().startsWith('#')) raw.trim().replaceFirst(RegExp(r'^[-*•]\s*'), ''),
      ].take(8).toList();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final info = _info;
    final locale = Localizations.localeOf(context).toString();
    final Widget body;
    switch (_phase) {
      case _Phase.permission:
        body = _message(l, p,
            icon: Icons.lock_outline,
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
        final total = info?.sizeBytes ?? 0;
        body = _message(l, p,
            icon: Icons.download_outlined,
            title: l.updatesDownloadingTitle(info?.version ?? ''),
            body: total > 0 ? l.updatesProgress(((total * _progress) / (1024 * 1024)).toStringAsFixed(1), (total / (1024 * 1024)).toStringAsFixed(1)) : null,
            top: 90,
            back: false,
            extra: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: _progress > 0 ? _progress : null, minHeight: 8, backgroundColor: p.separator, color: p.primary),
              ),
              Padding(padding: const EdgeInsets.only(top: 14), child: Text(l.updatesDownloadNote, style: TextStyle(fontSize: 13.5, color: p.text2))),
            ]),
            actions: [
              PillButton(
                label: l.cancel,
                outlined: true,
                onPressed: () => setState(() {
                  _cancelled = true;
                  _phase = _Phase.available;
                }),
              ),
            ]);
      case _Phase.error when _error == 'checksum' || _error == 'download':
        body = _message(l, p,
            icon: Icons.warning_amber_rounded,
            error: true,
            title: _error == 'checksum' ? l.updatesBadFileTitle : l.updatesDownloadFailed,
            body: _error == 'checksum' ? l.updatesBadFileBody : null,
            actions: [
              PillButton(label: l.updatesDownloadAgain, onPressed: _install),
              _textButton(p, l.updatesClose, () => setState(() => _phase = _Phase.available)),
            ]);
      case _Phase.available:
        body = Column(children: [
          _header(l, p),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 24), children: [
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.download_outlined, size: 20, color: p.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.updatesAvailable(info?.version ?? ''), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.text)),
                      Text(
                        (info?.sizeBytes ?? 0) > 0 ? l.updatesYouHaveSize(appVersion, _mb(l, info!.sizeBytes)) : l.updatesYouHave(appVersion),
                        style: TextStyle(fontSize: 13, color: p.text2),
                      ),
                    ]),
                  ),
                ]),
              ),
              if (info != null && _noteLines(info.notes).isNotEmpty) ...[
                SectionLabel(l.updatesNotes, padding: const EdgeInsets.fromLTRB(0, 16, 0, 8)),
                SettingsGroup(children: [
                  for (final line in _noteLines(info.notes))
                    SettingsRow(leadingWidget: Icon(Icons.check, size: 24, color: p.primary), title: line, titleWeight: FontWeight.w400),
                ]),
              ],
              const SizedBox(height: 20),
              PillButton(label: l.updatesInstall, height: 52, onPressed: _install),
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
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 24), children: [
              Padding(
                padding: const EdgeInsets.only(top: 30, bottom: 10),
                child: Column(children: [
                  _hero(p, _phase == _Phase.error ? Icons.error_outline : (_phase == _Phase.upToDate ? Icons.check : Icons.sync), error: _phase == _Phase.error),
                  Text(
                    _phase == _Phase.error
                        ? _errorText(l)
                        : (_phase == _Phase.checking ? l.updatesChecking : (_phase == _Phase.upToDate ? l.updatesUpToDateTitle : l.aboutVersion(appVersion))),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, height: 38 / 26, fontWeight: FontWeight.w600, color: p.text),
                  ),
                  if (subtitle != null && _phase != _Phase.error)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: p.text2))),
                ]),
              ),
              const SizedBox(height: 20),
              PillButton(label: l.updatesCheck, icon: Icons.sync, outlined: true, height: 52, onPressed: _phase == _Phase.checking ? null : _check),
            ]),
          ),
        ]);
    }
    return Scaffold(backgroundColor: Colors.transparent, body: GlassBackdrop(child: body));
  }
}
