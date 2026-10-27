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

/// Stage tints come from the status chip colours: neutral, blue, amber, green and red (tint index wraps).
Color stageTintColor(BuildContext context, int tint) {
  final p = context.palette;
  final tints = <Color>[p.surface2, p.coldBg, p.warmBg, p.coldBg, p.hotBg, p.wonBg, p.hotBg, p.warmBg, p.surface2, p.coldBg];
  return tints[tint % tints.length];
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
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    d.amount == null ? l.noAmount : formatMoney(context, d.amount!, d.currency),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: d.amount == null ? p.text2 : p.primary),
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
                      decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: p.onErrorContainer),
                        const SizedBox(width: 6),
                        Text(l.pastClose, style: TextStyle(fontSize: 12.5, color: p.onErrorContainer, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                if (showStage)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: stageTintColor(context, item.stage.tint), borderRadius: BorderRadius.circular(8)),
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
          child: Text(title ?? l.fieldStage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
