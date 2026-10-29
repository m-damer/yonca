import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null) return;
    final cards = parseVCards(raw);
    if (cards.isEmpty) {
      _handled = true;
      await _notContact(raw);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      _handled = false;
      return;
    }
    _handled = true;
    final nav = Navigator.of(context);
    await nav.pushReplacement(MaterialPageRoute<int>(builder: (_) => ContactFormPage(repo: widget.repo, draft: cards.first)));
  }

  Future<void> _notContact(String raw) async {
    final l = AppLocalizations.of(context);
    final uri = Uri.tryParse(raw.trim());
    final isLink = uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    final messenger = ScaffoldMessenger.of(context);
    final v = await showGlassSheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.notContactTitle),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(raw, maxLines: 3, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 14, height: 24 / 14, color: ctx.palette.text2)),
        ),
        if (isLink) ...[PillButton(label: l.openLink, onPressed: () => Navigator.of(ctx).pop('open')), const SizedBox(height: 8)],
        PillButton(label: l.copyText, outlined: true, icon: Icons.copy_outlined, onPressed: () => Navigator.of(ctx).pop('copy')),
        const SizedBox(height: 8),
        TextButton(style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)), onPressed: () => Navigator.of(ctx).pop(), child: Text(l.scanAgain, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      ]),
    );
    if (v == 'open' && uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (v == 'copy') {
      await Clipboard.setData(ClipboardData(text: raw));
      messenger.showSnackBar(SnackBar(content: Text(l.textCopied)));
    }
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              Expanded(child: Text(l.scanQr, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: pal.onHeader))),
            ]),
          ),
          Expanded(
            child: MobileScanner(
              onDetect: _onDetect,
              errorBuilder: (context, error, child) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.cameraDenied, textAlign: TextAlign.center))),
            ),
          ),
        ]),
      ),
    );
  }
}
