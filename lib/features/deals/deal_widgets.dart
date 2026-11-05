import 'package:flutter/material.dart';

import '../../core/format.dart';
import 'package:intl/intl.dart';

import '../../data/app_database.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

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

/// "1,500 USD" (no decimals unless the amount has them). Custom currencies use their own symbol and decimals.
String formatMoney(BuildContext context, double amount, String currency) {
  final locale = Localizations.localeOf(context).toString();
  CurrencyDef? def;
  for (final c in customCurrencies.value) {
    if (c.code == currency) def = c;
  }
  if (def != null) {
    final f = NumberFormat.currency(locale: locale, symbol: '', decimalDigits: def.decimals);
    final n = f.format(amount).trim();
    return def.symbolAfter ? '$n ${def.symbol}' : '${def.symbol} $n';
  }
  final whole = amount == amount.roundToDouble();
  final f = whole ? NumberFormat.decimalPattern(locale) : NumberFormat('#,##0.00', locale);
  return '${f.format(amount)} $currency';
}

/// A stage's colour: one of ten different tints, pastel on light and deep on dark (the index wraps).
Color stageTintColor(BuildContext context, int tint) {
  final tints = Theme.of(context).brightness == Brightness.dark ? AppTint.stagesDark : AppTint.stagesLight;
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
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFont.bodyL, height: AppLine.normal, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    d.amount == null ? l.noAmount : formatMoney(context, d.amount!, d.currency),
                    style: TextStyle(fontSize: AppFont.body, height: AppLine.relaxed, fontWeight: FontWeight.w600, color: p.text),
                  ),
                ]),
                const SizedBox(height: AppSpace.xs),
                Text(sub, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
                if (facts != null) Padding(padding: const EdgeInsets.only(top: AppSpace.xs), child: Text(facts, style: TextStyle(fontSize: AppFont.badge, height: AppLine.snug, color: p.text2))),
                if (mode == DealCardMode.closedPage)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.xs),
                    child: Row(children: [
                      Icon(item.kind == StageKind.won ? Lu.check : Lu.x, size: AppIcon.md, color: p.text2),
                      const SizedBox(width: AppSpace.sm),
                      Text(closedText, style: TextStyle(fontSize: AppFont.badge, height: AppLine.snug, color: p.text2)),
                    ]),
                  ),
                if (item.pastClose)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.sm),
                    child: Container(
                      height: AppControl.sm,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                      decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Lu.triangleAlert, size: AppIcon.md, color: p.onErrorContainer),
                        const SizedBox(width: AppSpace.sm),
                        Text(l.pastClose, style: TextStyle(fontSize: AppFont.badge, fontWeight: FontWeight.w600, color: p.onErrorContainer)),
                      ]),
                    ),
                  ),
                if (showStage)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
                      decoration: BoxDecoration(color: stageTintColor(context, item.stage.tint), borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: Text(stageLabel(l, item.stage), style: TextStyle(fontSize: AppFont.badge, fontWeight: FontWeight.w600, color: p.text)),
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

/// Sheet to pick one stage; [stages] are shown in order, [current] is marked. [counts] adds a count badge per stage.
Future<DealStage?> pickStage(BuildContext context, List<DealStage> stages, {int? current, String? title, Map<int, int>? counts, bool radio = false, String? footnote}) {
  final l = AppLocalizations.of(context);
  return showGlassSheet<DealStage>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(title ?? l.fieldStage),
      for (var i = 0; i < stages.length; i++)
        SheetItem(
          first: i == 0,
          vpad: radio ? 13.5 : 12.4,
          selected: radio ? stages[i].id == current : null,
          leading: radio ? null : Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: stageTintColor(ctx, stages[i].tint),
              shape: BoxShape.circle,
              border: Border.all(color: ctx.palette.text.withValues(alpha: AppAlpha.hairline)),
            ),
          ),
          title: stages[i].id == current ? l.stageCurrentMark(stageLabel(l, stages[i])) : stageLabel(l, stages[i]),
          bold: stages[i].id == current,
          trailing: counts == null ? null : TagPill('${counts[stages[i].id] ?? 0}'),
          onTap: () => Navigator.of(ctx).pop(stages[i]),
        ),
      if (footnote != null)
        Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.md, AppSpace.xs, 0), child: Text(footnote, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: ctx.palette.text2))),
    ]),
  );
}

/// Reopen sheet (design RC22): pick the open stage the deal returns to.
Future<DealStage?> showReopenSheet(BuildContext context, List<DealStage> stages, {int? initial}) {
  final l = AppLocalizations.of(context);
  var chosen = initial ?? (stages.isEmpty ? null : stages.first.id);
  return showGlassSheet<DealStage>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.reopenSheetTitle),
        Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.sm), child: Text(l.reopenSheetSub, style: TextStyle(fontSize: AppFont.body, height: AppLine.airy, color: ctx.palette.text2))),
        for (var i = 0; i < stages.length; i++)
          SheetItem(first: i == 0, title: stageLabel(l, stages[i]), bold: chosen == stages[i].id, selected: chosen == stages[i].id, onTap: () => setS(() => chosen = stages[i].id)),
        const SizedBox(height: AppSpace.lg),
        SheetButtons(
          secondary: l.cancel,
          onSecondary: () => Navigator.of(ctx).pop(),
          primary: l.reopenDeal,
          onPrimary: chosen == null ? null : () => Navigator.of(ctx).pop(stages.firstWhere((x) => x.id == chosen)),
        ),
      ]),
    ),
  );
}
