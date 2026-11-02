import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/lucide.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../settings/settings_widgets.dart';
import 'qr_models.dart';

/// The strongest error correction that still fits [data]; a logo needs the strongest, plain codes use medium.
int qrLevel(String data, {required bool logo}) {
  for (final lv in logo ? [QrErrorCorrectLevel.H, QrErrorCorrectLevel.Q, QrErrorCorrectLevel.M, QrErrorCorrectLevel.L] : [QrErrorCorrectLevel.M, QrErrorCorrectLevel.L]) {
    if (QrValidator.validate(data: data, version: QrVersions.auto, errorCorrectionLevel: lv).isValid) return lv;
  }
  return QrErrorCorrectLevel.L;
}

/// True when [data] fits in a code at all.
bool qrFits(String data) => QrValidator.validate(data: data, version: QrVersions.auto, errorCorrectionLevel: QrErrorCorrectLevel.L).isValid;

bool _hasLogo(SavedQr q) => q.includeLogo && q.logoPath.isNotEmpty && File(q.logoPath).existsSync();

/// Draws the code (with its logo, if any) to a PNG file.
Future<File> qrPng(SavedQr q) async {
  ui.Image? logo;
  if (_hasLogo(q)) {
    final codec = await ui.instantiateImageCodec(await File(q.logoPath).readAsBytes(), targetWidth: 256);
    logo = (await codec.getNextFrame()).image;
  }
  final painter = QrPainter(
    data: q.data,
    version: QrVersions.auto,
    errorCorrectionLevel: qrLevel(q.data, logo: logo != null),
    gapless: true,
    embeddedImage: logo,
    embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(140, 140)),
  );
  const side = 720.0, pad = 48.0;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(const Rect.fromLTWH(0, 0, side, side), Paint()..color = PrintInk.paper);
  canvas.translate(pad, pad);
  painter.paint(canvas, const Size(side - pad * 2, side - pad * 2));
  final img = await rec.endRecording().toImage(side.toInt(), side.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/yonca-qr-${q.id}.png');
  await f.writeAsBytes(bytes!.buffer.asUint8List());
  return f;
}

/// The code on a white square, with its logo in the centre when one is chosen.
class QrPreview extends StatelessWidget {
  const QrPreview({super.key, required this.qr, this.size = 220});
  final SavedQr qr;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = _hasLogo(qr);
    return Container(
      color: context.palette.qrPaper,
      padding: const EdgeInsets.all(AppSpace.sm),
      child: QrImageView(
        data: qr.data,
        size: size,
        errorCorrectionLevel: qrLevel(qr.data, logo: logo),
        backgroundColor: context.palette.qrPaper,
        embeddedImage: logo ? FileImage(File(qr.logoPath)) : null,
        embeddedImageStyle: QrEmbeddedImageStyle(size: Size(size * .2, size * .2)),
      ),
    );
  }
}

String qrDateText(BuildContext context, DateTime d) => dfmt(DateFormat.yMMMd(Localizations.localeOf(context).toString()), d);

class QrDetailPage extends StatefulWidget {
  const QrDetailPage({super.key, required this.store, required this.qr});
  final QrStore store;
  final SavedQr qr;

  @override
  State<QrDetailPage> createState() => _QrDetailPageState();
}

class _QrDetailPageState extends State<QrDetailPage> {
  SavedQr get _q => widget.qr;

  Future<void> _rename() async {
    final l = AppLocalizations.of(context);
    final r = await showDialog<String>(context: context, builder: (_) => _RenameDialog(initial: _q.title, title: l.qrRename, cancel: l.cancel, save: l.save));
    if (r == null || !mounted) return;
    setState(() => _q.title = r.trim());
    await widget.store.update(_q);
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.qrDeleteTitle),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete, style: TextStyle(color: ctx.palette.error))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await widget.store.remove(_q.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return SettingsScaffold(
      title: _q.title.isEmpty ? l.qrUntitled : _q.title,
      actions: [
        GlassIconButton(icon: Lu.pencil, onHeader: true, tooltip: l.qrRename, onTap: _rename),
        GlassIconButton(icon: Lu.trash2, onHeader: true, tooltip: l.delete, onTap: _delete),
      ],
      children: [
        const SizedBox(height: AppSpace.sm),
        GlassCard(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(children: [
            QrPreview(qr: _q),
            const SizedBox(height: AppSpace.md),
            Text(qrDateText(context, _q.createdAt), style: TextStyle(fontSize: AppFont.label, color: p.text2)),
          ]),
        ),
        const SizedBox(height: AppSpace.md),
        Row(children: [
          Expanded(
            child: PillButton(
              label: l.qrShare,
              icon: Lu.share,
              height: AppControl.lg,
              onPressed: () async => Share.shareXFiles([XFile((await qrPng(_q)).path, mimeType: 'image/png')]),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: PillButton(
              label: l.qrDownload,
              icon: Lu.download,
              outlined: true,
              height: AppControl.lg,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final f = await qrPng(_q);
                final out = await FilePicker.platform.saveFile(fileName: 'yonca-qr.png', bytes: await f.readAsBytes(), type: FileType.image);
                if (out != null) messenger.showSnackBar(SnackBar(content: Text(l.qrSaved)));
              },
            ),
          ),
        ]),
        SectionLabel(l.qrContents),
        SettingsGroup(children: [
          for (final f in _q.fields)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: AppControl.hero + AppSpace.lg, child: Text(f.label, style: TextStyle(fontSize: AppFont.label, color: p.text2))),
                Expanded(child: Text(f.value, textDirection: TextDirection.ltr, textAlign: TextAlign.start, style: const TextStyle(fontSize: AppFont.body))),
              ]),
            ),
        ]),
      ],
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial, required this.title, required this.cancel, required this.save});
  final String initial;
  final String title;
  final String cancel;
  final String save;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(controller: _c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(widget.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(_c.text), child: Text(widget.save)),
        ],
      );
}
