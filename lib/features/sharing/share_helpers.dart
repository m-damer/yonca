import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../shared/ds.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/contact_models.dart';
import '../../domain/vcard.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
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
      SheetTitle(l.shareTitle(s.displayName)),
      SheetItem(
        first: true,
        icon: Lu.contactRound,
        title: l.shareVCardFile,
        onTap: () {
          Navigator.of(ctx).pop();
          shareVCards([s], name: s.displayName.replaceAll(RegExp(r'[^\w؀-ۿ -]'), ''));
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
  const QrShowPage({super.key, required this.title, required this.data});
  final String title;
  final String data;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(title: title),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpace.lg),
                color: pal.qrPaper,
                child: QrImageView(data: data, size: 280, errorCorrectionLevel: QrErrorCorrectLevel.L, backgroundColor: pal.qrPaper),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
