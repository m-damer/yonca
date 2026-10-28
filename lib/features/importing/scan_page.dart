import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/contacts_repository.dart';
import '../../domain/vcard.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../contacts/contact_form_page.dart';

/// Scan QR (design S11): reads a vCard QR code and opens the new-contact form filled in.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.repo});
  final ContactsRepository repo;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _handled = false;
  bool _unreadable = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null) return;
    final cards = parseVCards(raw);
    if (cards.isEmpty) {
      if (!_unreadable) setState(() => _unreadable = true);
      return;
    }
    _handled = true;
    final nav = Navigator.of(context);
    await nav.pushReplacement(MaterialPageRoute<int>(builder: (_) => ContactFormPage(repo: widget.repo, draft: cards.first)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 14),
              Expanded(child: Text(l.scanQr, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: pal.onHeader))),
            ]),
          ),
          Expanded(
            child: MobileScanner(
              onDetect: _onDetect,
              errorBuilder: (context, error, child) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.cameraDenied, textAlign: TextAlign.center))),
            ),
          ),
          if (_unreadable)
            Padding(padding: const EdgeInsets.all(16), child: Text(l.qrUnreadable, style: TextStyle(color: pal.error))),
        ]),
      ),
    );
  }
}
