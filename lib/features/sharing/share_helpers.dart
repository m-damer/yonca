import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/contact_models.dart';
import '../../domain/vcard.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';

/// Writes the contacts to a .vcf file and opens the phone's share sheet.
Future<void> shareVCards(List<ContactSummary> list, {String name = 'contacts'}) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$name.vcf');
  await f.writeAsString(encodeVCards(list));
  await Share.shareXFiles([XFile(f.path, mimeType: 'text/vcard')]);
}

/// Share sheet (design S10): show a QR code or send a vCard.
Future<void> showShareSheet(BuildContext context, ContactSummary s) {
  final l = AppLocalizations.of(context);
  return showGlassSheet<void>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(
        leading: const Icon(Icons.qr_code_2),
        title: Text(l.showQr),
        onTap: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QrShowPage(title: s.displayName, data: encodeVCard(s, compact: true))));
        },
      ),
      ListTile(
        leading: const Icon(Icons.contact_page_outlined),
        title: Text(l.shareVCard),
        onTap: () {
          Navigator.of(ctx).pop();
          shareVCards([s], name: s.displayName.replaceAll(RegExp(r'[^\w؀-ۿ -]'), ''));
        },
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
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: pal.onHeader))),
            ]),
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: QrImageView(data: data, size: 280, errorCorrectionLevel: QrErrorCorrectLevel.L, backgroundColor: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
