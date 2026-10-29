import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/text_normalize.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import 'contact_widgets.dart';

Future<void> _launch(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = AppLocalizations.of(context).launchFailed;
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(failed)));
}

/// Calls the contact; with several numbers, asks which one first (design CS11).
Future<void> quickCall(BuildContext context, ContactSummary s) async {
  if (s.phones.isEmpty) return;
  Uri tel(p) => Uri(scheme: 'tel', path: '${p.countryCode}${p.number}'.replaceAll(' ', ''));
  if (s.phones.length == 1) return _launch(context, tel(s.phones.first));
  final l = AppLocalizations.of(context);
  final picked = await showGlassSheet(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(l.callTitle(s.displayName)),
      for (var i = 0; i < s.phones.length; i++)
        SheetItem(
          first: i == 0,
          icon: Icons.phone_outlined,
          title: '${s.phones[i].countryCode} ${s.phones[i].number}',
          subtitle: phoneLabelText(l, s.phones[i].label),
          ltrTitle: true,
          onTap: () => Navigator.of(ctx).pop(s.phones[i]),
        ),
    ]),
  );
  if (picked != null && context.mounted) await _launch(context, tel(picked));
}

/// Opens WhatsApp on the contact's WhatsApp number (or the first number).
Future<void> quickWhatsApp(BuildContext context, ContactSummary s) async {
  final p = s.phones.where((x) => x.isWhatsApp).firstOrNull ?? s.phones.firstOrNull;
  if (p == null) return;
  await _launch(context, Uri.parse('https://wa.me/${normalizePhone(p.countryCode, p.number)}'));
}

/// Press-and-hold menu of a contact row (design CS2). Returns the chosen key:
/// call, whatsapp, select, edit, share or delete.
Future<String?> showContactRowMenu(BuildContext context, {required Rect anchor, required bool hasPhone, required bool hasWhatsApp}) {
  final l = AppLocalizations.of(context);
  final entries = <(String, IconData, String)>[
    if (hasPhone) ('call', Icons.call_outlined, l.actionCall),
    if (hasWhatsApp) ('whatsapp', Icons.chat_outlined, l.actionWhatsApp),
    ('select', Icons.check, l.selectAction),
    ('edit', Icons.edit_outlined, l.edit),
    ('share', Icons.ios_share, l.bulkShare),
    ('delete', Icons.delete_outline, l.delete),
  ];
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, _, __) {
      final p = ctx.palette;
      final size = MediaQuery.of(ctx).size;
      const w = 192.0;
      const rowH = 44.0;
      final h = entries.length * rowH + 8;
      final below = anchor.bottom + 8 + h <= size.height - 24;
      final top = below ? anchor.bottom + 8 : (anchor.top - 8 - h).clamp(24.0, size.height);
      final rtl = Directionality.of(ctx) == TextDirection.rtl;
      const start = 32.0;
      return Stack(children: [
        Positioned(
          top: top,
          left: rtl ? null : start,
          right: rtl ? start : null,
          width: w,
          child: Material(
            color: p.sheet,
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, indent: 12, endIndent: 12, color: p.separator),
                  InkWell(
                    onTap: () => Navigator.of(ctx).pop(entries[i].$1),
                    child: SizedBox(
                      height: rowH - 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          Icon(entries[i].$2, size: 20, color: entries[i].$1 == 'delete' ? p.error : p.primary),
                          const SizedBox(width: 12),
                          Text(entries[i].$3, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: entries[i].$1 == 'delete' ? p.error : p.text)),
                        ]),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ]);
    },
  );
}

/// One action revealed by swiping a row.
class SwipeAction {
  const SwipeAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// Swipe a row toward the end to reveal buttons behind it (design CS1). Only one row stays open.
class SwipeReveal extends StatefulWidget {
  const SwipeReveal({super.key, required this.child, required this.actions});
  final Widget child;
  final List<SwipeAction> actions;

  @override
  State<SwipeReveal> createState() => _SwipeRevealState();
}

class _SwipeRevealState extends State<SwipeReveal> with SingleTickerProviderStateMixin {
  static _SwipeRevealState? _open;
  static const _w = 63.0;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));

  double get _max => _w * widget.actions.length;

  void _close() => _c.reverse();

  @override
  void dispose() {
    if (_open == this) _open = null;
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) return widget.child;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sign = rtl ? -1.0 : 1.0;
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        final v = (_c.value + (d.primaryDelta ?? 0) * sign / _max).clamp(0.0, 1.0);
        _c.value = v;
        if (v > 0 && _open != this) {
          _open?._close();
          _open = this;
        }
      },
      onHorizontalDragEnd: (d) {
        final fling = (d.primaryVelocity ?? 0) * sign;
        if (fling > 300 || (fling > -300 && _c.value > 0.5)) {
          _c.forward();
        } else {
          _c.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Stack(children: [
          if (_c.value > 0)
            Positioned.fill(
              child: Row(children: [
                for (final a in widget.actions)
                  SizedBox(
                    width: _w,
                    child: Material(
                      color: a.color,
                      child: InkWell(
                        onTap: () {
                          _close();
                          a.onTap();
                        },
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(a.icon, size: 22, color: Colors.white),
                          const SizedBox(height: 2),
                          Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          Transform.translate(offset: Offset(_c.value * _max * sign, 0), child: ColoredBox(color: context.palette.glass, child: child)),
        ]),
        child: widget.child,
      ),
    );
  }
}
