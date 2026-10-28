import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/deals_repository.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'deal_widgets.dart';

/// Deal stages (design S29): rename, tint, reorder, add, delete (moving its deals); Won and Lost are fixed.
class StagesPage extends StatefulWidget {
  const StagesPage({super.key, required this.deals});
  final DealsRepository deals;

  @override
  State<StagesPage> createState() => _StagesPageState();
}

class _StagesPageState extends State<StagesPage> {
  List<StageSummary> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final s = await widget.deals.summaries();
    if (mounted) setState(() => _items = s);
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _edit({DealStage? stage, StageSummary? summary}) async {
    final l = AppLocalizations.of(context);
    final name = TextEditingController(text: stage == null ? '' : stageLabel(l, stage));
    var tint = stage?.tint ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(stage == null ? l.newStage : l.stageName),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            GlassField(controller: name, maxLength: 30, autofocus: true, label: l.stageName),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < stageTintCount; i++)
                GestureDetector(
                  onTap: () => setS(() => tint = i),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: stageTintColor(ctx, i),
                      shape: BoxShape.circle,
                      border: Border.all(color: tint == i ? ctx.palette.primary : ctx.palette.outline, width: tint == i ? 3 : 1),
                    ),
                  ),
                ),
            ]),
          ]),
          actions: [
            if (summary != null)
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(false);
                  _delete(summary);
                },
                child: Text(l.delete, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ),
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      if (stage == null) {
        await widget.deals.addStage(name.text, tint);
      } else {
        if (name.text.trim() != stageLabel(l, stage)) await widget.deals.renameStage(stage.id, name.text);
        await widget.deals.setStageTint(stage.id, tint);
      }
    } on DealValidationException catch (e) {
      _toast(e.problem == 'stage_max' ? l.stageMax : l.errTitleRequired);
    }
    await _reload();
  }

  Future<void> _delete(StageSummary s) async {
    final l = AppLocalizations.of(context);
    final others = [for (final x in _items) if (x.stage.kind == 'open' && x.stage.id != s.stage.id) x.stage];
    if (others.isEmpty) {
      _toast(l.stageLast);
      return;
    }
    DealStage? target;
    if (s.count > 0) {
      target = await pickStage(context, others, title: l.moveDealsTo);
      if (target == null) return;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.deleteStageTitle),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete)),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await widget.deals.removeStage(s.stage.id, moveTo: target?.id);
    } on DealValidationException {
      _toast(l.stageLast);
    }
    await _reload();
  }

  Widget _count(int n, YoncaPalette pal) => Container(
        height: 20.8,
        constraints: const BoxConstraints(minWidth: 23.2),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(4)),
        child: Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pal.text)),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final open = [for (final s in _items) if (s.stage.kind == 'open') s];
    final fixed = [for (final s in _items) if (s.stage.kind != 'open') s];
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: Text(l.newStage)),
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              Expanded(child: Text(l.stagesTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: pal.onHeader))),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(l.stagesIntro(open.length), style: TextStyle(fontSize: 15, height: 21 / 15, color: pal.text2)),
              ),
              GlassCard(
                padding: EdgeInsets.zero,
                child: ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: (from, to) async {
                    final ids = [for (final s in open) s.stage.id];
                    ids.insert(to, ids.removeAt(from));
                    await widget.deals.reorderOpenStages(ids);
                    await _reload();
                  },
                  children: [
                    for (var i = 0; i < open.length; i++)
                      Material(
                        key: ValueKey(open[i].stage.id),
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: () => _edit(stage: open[i].stage, summary: open[i]),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(children: [
                              ReorderableDragStartListener(
                                index: i,
                                child: SizedBox(
                                  width: 11,
                                  height: 15,
                                  child: Wrap(spacing: 3, runSpacing: 3, children: [
                                    for (var d = 0; d < 6; d++) Container(width: 4, height: 4, decoration: BoxDecoration(color: const Color(0xFFC7C7CC), borderRadius: BorderRadius.circular(2))),
                                  ]),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: stageTintColor(context, open[i].stage.tint), border: Border.all(color: const Color(0x14000000)))),
                              const SizedBox(width: 12),
                              Expanded(child: Text(stageLabel(l, open[i].stage), style: const TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w500))),
                              _count(open[i].count, pal),
                              const SizedBox(width: 11),
                              Icon(Icons.chevron_right, size: 22, color: pal.text),
                            ]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SectionLabel(l.alwaysLast, padding: const EdgeInsets.fromLTRB(4, 16, 4, 8)),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < fixed.length; i++) ...[
                    if (i > 0) Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: pal.separator),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(children: [
                        Icon(fixed[i].stage.kind == 'won' ? Icons.check_circle_outline : Icons.cancel_outlined, size: 22, color: fixed[i].stage.kind == 'won' ? pal.primary : pal.error),
                        const SizedBox(width: 12),
                        Expanded(child: Text(stageLabel(l, fixed[i].stage), style: const TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w500))),
                        _count(fixed[i].count, pal),
                        const SizedBox(width: 12),
                        Text(l.fixedStage, style: TextStyle(fontSize: 12.5, height: 17.5 / 12.5, color: pal.text2)),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              PillButton(
                label: l.restoreStages,
                outlined: true,
                height: 48,
                onPressed: () async {
                  await widget.deals.restoreDefaultStages();
                  await _reload();
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
