import 'package:flutter/material.dart';
import '../../shared/state_views.dart';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/contacts_repository.dart';
import '../../domain/vcard.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import '../contacts/contact_form_page.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

/// Scan QR (design S11): reads a vCard QR code and opens the new-contact form filled in.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.repo});
  final ContactsRepository repo;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _handled = false;
  final _ctl = MobileScannerController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

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
          padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.sm),
          child: Text(raw, maxLines: 3, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: TextStyle(fontSize: AppFont.label, height: AppLine.loose, color: ctx.palette.text2)),
        ),
        if (isLink) ...[PillButton(label: l.openLink, onPressed: () => Navigator.of(ctx).pop('open')), const SizedBox(height: AppSpace.sm)],
        PillButton(label: l.copyText, outlined: true, icon: Lu.copy, onPressed: () => Navigator.of(ctx).pop('copy')),
        const SizedBox(height: AppSpace.sm),
        TextButton(style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)), onPressed: () => Navigator.of(ctx).pop(), child: Text(l.scanAgain, style: const TextStyle(fontSize: AppFont.body, fontWeight: AppWeight.semibold))),
      ]),
    );
    if (v == 'open' && uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (v == 'copy') {
      await Clipboard.setData(ClipboardData(text: raw));
      messenger.showSnackBar(SnackBar(content: Text(l.textCopied)));
    }
  }

  Future<void> _fromGallery() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final capture = await _ctl.analyzeImage(x.path);
    if (!mounted) return;
    if (capture == null || capture.barcodes.every((b) => b.rawValue == null)) {
      messenger.showSnackBar(SnackBar(content: Text(l.scanNoCodeInImage)));
      return;
    }
    await _onDetect(capture);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final side = w * AppScan.frameShare;
    return Scaffold(
      backgroundColor: AppScan.screen,
      body: Stack(children: [
        Positioned.fill(
          child: MobileScanner(
            controller: _ctl,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => EmptyState(icon: Lu.lock, title: l.cameraDenied),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _FramePainter(side: side))),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.sm),
              child: Row(children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Lu.chevronLeft, color: AppScan.ink),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(l.scanQr, textAlign: TextAlign.center, style: const TextStyle(color: AppScan.ink, fontSize: AppFont.title, fontWeight: AppWeight.semibold)),
                ),
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _ctl,
                  builder: (context, st, _) => IconButton(
                    tooltip: l.scanTorch,
                    icon: Icon(st.torchState == TorchState.on ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: AppScan.ink),
                    onPressed: () => _ctl.toggleTorch(),
                  ),
                ),
              ]),
            ),
            const Spacer(),
            SizedBox(height: side),
            const SizedBox(height: AppSpace.lg),
            Text(l.scanHint, style: const TextStyle(color: AppScan.ink, fontSize: AppFont.lead)),
            const Spacer(),
            Material(
              color: AppScan.button,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _fromGallery,
                child: const SizedBox(width: AppSize.s64, height: AppSize.s64, child: Icon(Lu.image, color: AppScan.ink, size: AppIcon.lg)),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(l.scanFromGallery, style: const TextStyle(color: AppScan.inkSoft, fontSize: AppFont.meta)),
            const SizedBox(height: AppSpace.x4),
          ]),
        ),
      ]),
    );
  }
}

/// Dark veil with a clear square and white corner brackets, as in the usual scanner screens.
class _FramePainter extends CustomPainter {
  _FramePainter({required this.side});
  final double side;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.4), width: side, height: side);
    final veil = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(box);
    canvas.drawPath(veil, Paint()..color = AppScan.scrim);
    final line = Paint()
      ..color = AppScan.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppScan.cornerStroke
      ..strokeCap = StrokeCap.square;
    const c = AppScan.corner;
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        final o = Offset(sx < 0 ? box.left : box.right, sy < 0 ? box.top : box.bottom);
        canvas.drawLine(o, o + Offset(-sx * -c, 0), line);
        canvas.drawLine(o, o + Offset(0, -sy * -c), line);
      }
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.side != side;
}
