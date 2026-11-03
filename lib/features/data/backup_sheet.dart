import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/lucide.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import 'data_page.dart' show formatBytes;

/// What a finished backup says about itself.
class BackupInfo {
  const BackupInfo({required this.name, required this.bytes, this.file});
  final String name;
  final int bytes;

  /// The file to share (null for a Drive backup).
  final File? file;
}

enum _Step { working, done, failed }

/// The bottom sheet of a backup in progress: a progress bar while it works, then "Backup ready"
/// (with Save or share) or a failure with Try again. Used for the backup file and for Drive.
class BackupProgressSheet extends StatefulWidget {
  const BackupProgressSheet({
    super.key,
    required this.title,
    required this.readyTitle,
    required this.run,
    this.protected = false,
    this.onShare,
    this.errorText,
    this.canHide = false,
    this.onFinishedHidden,
    this.workingSub,
    this.readySub,
    this.failedTitle,
    this.showFile = true,
    this.icon = Lu.database,
  });

  final String title;
  final String readyTitle;
  final Future<BackupInfo> Function(void Function(double) progress) run;

  /// Shows "Protected with your password." on the result.
  final bool protected;

  /// Opens the phone's share sheet for the finished file; null hides the button (Drive).
  final Future<void> Function(File file)? onShare;
  final String Function(Object error)? errorText;

  /// While working the sheet can be hidden; the work goes on.
  final bool canHide;

  /// Called when the work ends after the sheet was hidden.
  final void Function(bool ok, String text)? onFinishedHidden;

  /// Overrides of the texts and icon, so the sheet also serves restores.
  final String? workingSub;
  final String? readySub;
  final String? failedTitle;
  final bool showFile;
  final IconData icon;

  @override
  State<BackupProgressSheet> createState() => _BackupProgressSheetState();
}

class _BackupProgressSheetState extends State<BackupProgressSheet> {
  _Step _step = _Step.working;
  double _v = 0;
  BackupInfo? _info;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _step = _Step.working;
      _v = 0;
      _error = null;
    });
    try {
      final info = await widget.run((v) {
        if (mounted) setState(() => _v = v.clamp(0.0, 1.0));
      });
      if (!mounted) {
        widget.onFinishedHidden?.call(true, info.name);
        return;
      }
      setState(() {
        _info = info;
        _step = _Step.done;
      });
    } catch (e) {
      final text = widget.errorText?.call(e);
      if (!mounted) {
        widget.onFinishedHidden?.call(false, text ?? '');
        return;
      }
      setState(() {
        _error = text;
        _step = _Step.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final working = _step == _Step.working;
    final failed = _step == _Step.failed;
    final String title = working ? widget.title : (failed ? (widget.failedTitle ?? l.backupFailedTitle) : widget.readyTitle);
    final String sub = working ? (widget.workingSub ?? l.backupMakingSub) : (failed ? (_error ?? l.backupFailedSub) : (widget.readySub ?? (widget.protected ? l.backupReadyProtected : '')));
    return PopScope(
      canPop: !working || widget.canHide,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: IconTile(
            icon: working ? widget.icon : (failed ? Lu.triangleAlert : Lu.circleCheck),
            size: AppControl.hero,
            iconSize: AppIcon.xxl,
            background: failed ? p.errorContainer : p.primaryContainer,
            color: failed ? p.error : p.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: AppFont.title, height: AppLine.snug, fontWeight: FontWeight.w600, color: p.text)),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          Text(sub, textAlign: TextAlign.center, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: p.text2)),
        ],
        const SizedBox(height: AppSpace.xl),
        if (working) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(value: _v, minHeight: AppSpace.sm, backgroundColor: p.track, color: p.primary),
          ),
          const SizedBox(height: AppSpace.sm),
          Text('${(_v * 100).round()}%', textAlign: TextAlign.center, textDirection: TextDirection.ltr, style: TextStyle(fontSize: AppFont.meta, color: p.text2)),
          if (widget.canHide) ...[
            const SizedBox(height: AppSpace.lg),
            PillButton(label: l.hideBtn, outlined: true, height: AppControl.lg, onPressed: () => Navigator.of(context).pop()),
          ],
        ] else if (failed) ...[
          PillButton(label: l.stateRetry, height: AppControl.lg, onPressed: _start),
          const SizedBox(height: AppSpace.sm),
          PillButton(label: l.backupDoneBtn, outlined: true, height: AppControl.lg, onPressed: () => Navigator.of(context).pop()),
        ] else ...[
          if (widget.showFile) ...[
          GlassCard(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(children: [
              const IconTile(icon: Lu.fileText, size: AppControl.tile),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_info!.name, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: AppFont.label, height: AppLine.normal, fontWeight: FontWeight.w500)),
                  Text(formatBytes(_info!.bytes), textDirection: TextDirection.ltr, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: AppSpace.lg),
          ],
          if (widget.onShare != null && _info!.file != null) ...[
            PillButton(label: l.backupSaveShare, icon: Lu.share, height: AppControl.lg, onPressed: () => widget.onShare!(_info!.file!)),
            const SizedBox(height: AppSpace.sm),
          ],
          PillButton(label: l.backupDoneBtn, outlined: widget.onShare != null, height: AppControl.lg, onPressed: () => Navigator.of(context).pop()),
        ],
      ]),
    );
  }
}
