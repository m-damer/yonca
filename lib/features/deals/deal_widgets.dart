import 'package:flutter/material.dart';

import '../../core/format.dart';
import 'package:intl/intl.dart';

import '../../data/app_database.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';

/// Stage name: built-in stages are translated, custom ones show their own name.
String stageLabel(AppLocalizations l, DealStage s) => switch (s.key) {
      'lead' => l.stageLead,
      'quote' => l.stageQuote,
      'talks' => l.stageTalks,
      'won' => l.stageWon,
      'lost' => l.stageLost,
      _ => s.name,
    };

String lostReasonLabel(AppLocalizations l, String key) => switch (key) {
      'price' => l.reasonPrice,
      'competitor' => l.reasonCompetitor,
      'noBudget' => l.reasonNoBudget,
      'noResponse' => l.reasonNoResponse,
      'other' => l.reasonOther,
      _ => key,
    };

/// "1,500 USD" (no decimals unless the amount has them).
String formatMoney(BuildContext context, double amount, String currency) {
  final locale = Localizations.localeOf(context).toString();
  final whole = amount == amount.roundToDouble();
  final f = whole ? NumberFormat.decimalPattern(locale) : NumberFormat('#,##0.00', locale);
  return '${f.format(amount)} $currency';
}

const _tintBases = <Color>[
  Color(0xFF4CAF50), Color(0xFF26A69A), Color(0xFF42A5F5), Color(0xFF7E57C2), Color(0xFFEC407A),
  Color(0xFF66BB6A), Color(0xFFEF5350), Color(0xFFFFA726), Color(0xFF8D6E63), Color(0xFF78909C),
];

/// One of the ten very light stage tints (tint index wraps).
Color stageTintColor(BuildContext context, int tint) {
  final base = _tintBases[tint % _tintBases.length];
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Color.alphaBlend(base.withValues(alpha: dark ? .22 : .16), context.palette.bg);
}

/// A deal in a list: title, contact, amount, expected close, days in stage, stage chip.
class DealCard extends StatelessWidget {
  const DealCard({super.key, required this.item, required this.onTap, this.showStage = true});
  final DealItem item;
  final VoidCallback onTap;
  final bool showStage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final d = item.deal;
    final facts = <String>[if (item.isOpen) l.daysInStage(item.daysInStage)];
    final who = d.expectedClose == null ? item.contactName : '${item.contactName} · ${l.dealCloseShort(dfmt(DateFormat.MMMd(Localizations.localeOf(context).toString()), d.expectedClose!))}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    d.amount == null ? l.noAmount : formatMoney(context, d.amount!, d.currency),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: d.amount == null ? p.text2 : p.primary),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(who, style: TextStyle(fontSize: 14, color: p.text2)),
                if (facts.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(facts.join(' · '), style: TextStyle(fontSize: 13, color: p.text2))),
                if (item.pastClose)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: p.onErrorContainer),
                        const SizedBox(width: 6),
                        Text(l.pastClose, style: TextStyle(fontSize: 12.5, color: p.onErrorContainer, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                if (showStage)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: stageTintColor(context, item.stage.tint), borderRadius: BorderRadius.circular(20)),
                      child: Text(stageLabel(l, item.stage), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.text)),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet to pick one stage; [stages] are shown in order, [current] gets a check.
Future<DealStage?> pickStage(BuildContext context, List<DealStage> stages, {int? current, String? title}) {
  final l = AppLocalizations.of(context);
  return showGlassSheet<DealStage>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(title ?? l.fieldStage, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
      ),
      for (final s in stages)
        ListTile(
          leading: CircleAvatar(radius: 10, backgroundColor: stageTintColor(ctx, s.tint)),
          title: Text(stageLabel(l, s)),
          trailing: s.id == current ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(ctx).pop(s),
        ),
    ]),
  );
}
