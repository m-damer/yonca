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
      'contacted' => l.stageContacted,
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

/// Where a deal card is shown: a stage page, the Won/Lost pages, or search results.
enum DealCardMode { open, closedPage, search }

/// A deal in a list: title, contact, amount, expected close, days in stage, stage chip.
class DealCard extends StatelessWidget {
  const DealCard({super.key, required this.item, required this.onTap, this.showStage = true, this.mode = DealCardMode.open});
  final DealItem item;
  final VoidCallback onTap;
  final bool showStage;
  final DealCardMode mode;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final d = item.deal;
    final loc = Localizations.localeOf(context).toString();
    String day(DateTime x) => dfmt(DateFormat.MMMd(loc), x);
    final closedAt = d.closedAt ?? d.stageChangedAt;
    final closedText = item.kind == StageKind.won ? l.dealWonOn(day(closedAt)) : l.dealLostOn(day(closedAt));
    final String sub;
    String? facts;
    if (item.isOpen) {
      sub = '${item.contactName} · ${d.expectedClose == null ? l.noCloseDate : l.dealCloseShort(day(d.expectedClose!))}';
      facts = mode == DealCardMode.search ? '${stageLabel(l, item.stage)} · ${l.daysShort(item.daysInStage)}' : l.daysInStage(item.daysInStage);
    } else if (mode == DealCardMode.search) {
      sub = '${item.contactName} · $closedText';
      facts = stageLabel(l, item.stage);
    } else {
      sub = item.contactName;
      facts = null;
    }
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
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    d.amount == null ? l.noAmount : formatMoney(context, d.amount!, d.currency),
                    style: TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w600, color: p.text),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(sub, style: TextStyle(fontSize: 13, height: 18 / 13, color: p.text2)),
                if (facts != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(facts, style: TextStyle(fontSize: 12, height: 16 / 12, color: p.text2))),
                if (mode == DealCardMode.closedPage)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      Icon(item.kind == StageKind.won ? Icons.check : Icons.close, size: 20, color: p.text2),
                      const SizedBox(width: 8),
                      Text(closedText, style: TextStyle(fontSize: 12, height: 16 / 12, color: p.text2)),
                    ]),
                  ),
                if (item.pastClose)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.warning_amber_rounded, size: 20, color: p.onErrorContainer),
                        const SizedBox(width: 6),
                        Text(l.pastClose, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.onErrorContainer)),
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
