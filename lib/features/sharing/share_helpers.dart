import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/contact_models.dart';
import '../../domain/vcard.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

/// Writes the contacts to a .vcf file and opens the phone's share sheet.
Future<void> shareVCards(List<ContactSummary> list, {String name = 'contacts'}) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$name.vcf');
  await f.writeAsString(encodeVCards(list));
  await Share.shareXFiles([XFile(f.path, mimeType: 'text/vcard')]);
}

/// Draws the contact's QR code to a PNG file.
Future<File> contactQrImage(ContactSummary s) async {
  final painter = QrPainter(data: encodeVCard(s, compact: true), version: QrVersions.auto, errorCorrectionLevel: QrErrorCorrectLevel.L, gapless: true);
  const side = 720.0, pad = 48.0;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(const Rect.fromLTWH(0, 0, side, side), Paint()..color = PrintInk.paper);
  canvas.translate(pad, pad);
  painter.paint(canvas, const Size(side - pad * 2, side - pad * 2));
  final img = await rec.endRecording().toImage(side.toInt(), side.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/yonca-qr.png');
  await f.writeAsBytes(bytes!.buffer.asUint8List());
  return f;
}

/// Share sheet (design CD6): the contact file, the QR image, or the phone number.
Future<void> showShareSheet(BuildContext context, ContactSummary s) {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  return showGlassSheet<void>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(l.shareTitle(s.fullName)),
      SheetItem(
        first: true,
        icon: Lu.contactRound,
        title: l.shareVCardFile,
        onTap: () {
          Navigator.of(ctx).pop();
          shareVCards([s], name: s.fullName.replaceAll(RegExp(r'[^\w؀-ۿ -]'), ''));
        },
      ),
      SheetItem(
        icon: Lu.qrCode,
        title: l.shareQrImage,
        onTap: () async {
          Navigator.of(ctx).pop();
          final f = await contactQrImage(s);
          await Share.shareXFiles([XFile(f.path, mimeType: 'image/png')]);
        },
      ),
      if (s.phones.isNotEmpty)
        SheetItem(
          icon: Lu.copy,
          title: l.copyPhone,
          onTap: () async {
            Navigator.of(ctx).pop();
            final ph = s.phones.first;
            await Clipboard.setData(ClipboardData(text: '${ph.countryCode} ${ph.number}'));
            messenger.showSnackBar(SnackBar(content: Text(l.phoneCopied)));
          },
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
        child: Text(l.shareNeverShared, style: TextStyle(fontSize: AppFont.meta, color: ctx.palette.text2)),
      ),
    ]),
  );
}

/// A big QR code with a title (QR generator).
class QrShowPage extends StatelessWidget {
  const QrShowPage({super.key, required this.title, required this.data, this.logo});
  final String title;
  final String data;

  /// Picture drawn in the centre of the code.
  final ImageProvider? logo;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Scaffold(
      backgroundColor: pal.qrPaper,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Align(alignment: AlignmentDirectional.centerStart, child: GlassIconButton(icon: Lu.x, onTap: () => Navigator.of(context).maybePop())),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final side = (box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight) - AppSpace.xxl * 2;
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    QrImageView(
                      data: data,
                      size: side,
                      errorCorrectionLevel: logo == null ? QrErrorCorrectLevel.L : QrErrorCorrectLevel.H,
                      backgroundColor: pal.qrPaper,
                      embeddedImage: logo,
                      embeddedImageStyle: QrEmbeddedImageStyle(size: Size(side * .2, side * .2)),
                    ),
                    if (title.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.lg),
                      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: AppFont.pageTitle, height: AppLine.normal, fontWeight: AppWeight.semibold, color: PrintInk.ink)),
                    ],
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
