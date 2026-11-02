import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/text_normalize.dart';
import '../../data/app_database.dart' show ContactPhone;
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import 'contact_widgets.dart';
import '../../core/phone_rules.dart';
import '../../theme/flag_view.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

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
/// The number as shown to the person: country flag, dial code and number.
String phoneLine(ContactPhone p) => '${p.countryCode} ${formatPhone(p.countryCode, p.number)}';

/// The only number, or a sheet to choose one when the contact has several. Null when cancelled or none.
Future<ContactPhone?> pickPhone(BuildContext context, ContactSummary s, {required String title, required IconData icon}) async {
  if (s.phones.isEmpty) return null;
  if (s.phones.length == 1) return s.phones.first;
  final l = AppLocalizations.of(context);
  return showGlassSheet<ContactPhone>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(title),
      for (var i = 0; i < s.phones.length; i++)
        SheetItem(
          first: i == 0,
          icon: icon,
          leading: FlagView.dial(s.phones[i].countryCode),
          title: phoneLine(s.phones[i]),
          subtitle: phoneLabelText(l, s.phones[i].label),
          ltrTitle: true,
          onTap: () => Navigator.of(ctx).pop(s.phones[i]),
        ),
    ]),
  );
}

Future<void> quickCall(BuildContext context, ContactSummary s) async {
  if (s.phones.isEmpty) return;
  final l = AppLocalizations.of(context);
  final picked = await pickPhone(context, s, title: l.callTitle(s.displayName), icon: Lu.phone);
  if (picked != null && context.mounted) {
    await _launch(context, Uri(scheme: 'tel', path: '${picked.countryCode}${picked.number}'.replaceAll(' ', '')));
  }
}

/// Opens WhatsApp on a number of the contact; with several numbers the person chooses which.
Future<void> quickWhatsApp(BuildContext context, ContactSummary s) async {
  if (s.phones.isEmpty) return;
  final l = AppLocalizations.of(context);
  final p = await pickPhone(context, s, title: l.whatsAppTitle(s.displayName), icon: Lu.messageSquare);
  if (p == null || !context.mounted) return;
  await _launch(context, Uri.parse('https://wa.me/${normalizePhone(p.countryCode, p.number)}'));
}

/// Press-and-hold menu of a contact row (design CS2). Returns the chosen key:
/// call, whatsapp, select, edit, share or delete.
Future<String?> showContactRowMenu(BuildContext context, {required Rect anchor, required bool hasPhone, required bool hasWhatsApp}) {
  final l = AppLocalizations.of(context);
  final entries = <(String, IconData, String)>[
    if (hasPhone) ('call', Lu.phone, l.actionCall),
    if (hasWhatsApp) ('whatsapp', Lu.messageSquare, l.actionWhatsApp),
    ('select', Lu.check, l.selectAction),
    ('edit', Lu.pencil, l.edit),
    ('share', Lu.share, l.bulkShare),
    ('delete', Lu.trash2, l.delete),
  ];
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: context.palette.scrimSoft,
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
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, indent: 12, endIndent: 12, color: p.separator),
                  InkWell(
                    onTap: () => Navigator.of(ctx).pop(entries[i].$1),
                    child: SizedBox(
                      height: rowH - 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                        child: Row(children: [
                          Icon(entries[i].$2, size: AppIcon.md, color: entries[i].$1 == 'delete' ? p.error : p.primary),
                          const SizedBox(width: AppSpace.md),
                          Text(entries[i].$3, style: TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w500, color: entries[i].$1 == 'delete' ? p.error : p.text)),
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
                          Icon(a.icon, size: AppIcon.lg, color: context.palette.onMedia),
                          const SizedBox(height: AppSpace.xs),
                          Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.badge, fontWeight: FontWeight.w500, color: context.palette.onMedia)),
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
