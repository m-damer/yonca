import 'package:flutter/material.dart';

import '../../shared/ds.dart';

import '../../data/app_database.dart';
import '../../data/deals_repository.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'deal_widgets.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';
import '../../shared/scroll_fab.dart';

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
    final res = await showGlassSheet<String>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SheetTitle(stage == null ? l.newStage : l.stageName, bottom: 12),
            GlassField(controller: name, maxLength: 30, autofocus: true, label: l.nameUpTo30, trailing: CharCount(name, 30)),
            SectionLabel(l.tintLabel, padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.md)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: Wrap(spacing: AppSpace.x3, runSpacing: AppSpace.md, children: [
                for (var i = 0; i < stageTintCount; i++)
                  GestureDetector(
                    onTap: () => setS(() => tint = i),
                    child: Container(
                      width: AppSize.s46,
                      height: AppControl.lg,
                      decoration: BoxDecoration(color: stageTintColor(ctx, i), borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: ctx.palette.swatchBorder)),
                      child: tint == i ? Icon(Lu.check, size: AppIcon.md, color: ctx.palette.text) : null,
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: AppSpace.lg),
            SheetButtons(secondary: summary != null ? l.delete : l.cancel, onSecondary: () => Navigator.of(ctx).pop(summary != null ? 'delete' : null), primary: l.save, onPrimary: () => Navigator.of(ctx).pop('save')),
          ]),
        ),
      ),
    );
    if (res == 'delete' && summary != null) {
      await _delete(summary);
      return;
    }
    final ok = res == 'save';
    if (!ok) return;
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
    final stageName = stageLabel(l, s.stage);
    if (s.count > 0) {
      var pick = others.first;
      final ok = await showGlassSheet<bool>(
        context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SheetTitle(l.deleteStageNamed(stageName)),
            Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.sm), child: Text(l.stageDealsMove(s.count), style: TextStyle(fontSize: AppFont.body, height: AppLine.airy, color: ctx.palette.text2))),
            for (var i = 0; i < others.length; i++)
              SheetItem(first: i == 0, title: stageLabel(l, others[i]), bold: pick.id == others[i].id, selected: pick.id == others[i].id, onTap: () => setS(() => pick = others[i])),
            const SizedBox(height: AppSpace.lg),
            PillButton(label: l.deleteAndMove(s.count), danger: true, onPressed: () => Navigator.of(ctx).pop(true)),
          ]),
        ),
      );
      if (ok != true) return;
      target = pick;
    } else {
      final ok = await showGlassSheet<bool>(
        context,
        builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.deleteStageNamed(stageName), bottom: 16),
          SheetButtons(secondary: l.cancel, onSecondary: () => Navigator.of(ctx).pop(false), primary: l.delete, onPrimary: () => Navigator.of(ctx).pop(true), dangerPrimary: true),
        ]),
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

  @override
  Widget build(BuildContext context) => FabScope(child: Builder(builder: _buildScreen));

  Widget _buildScreen(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final open = [for (final s in _items) if (s.stage.kind == 'open') s];
    final fixed = [for (final s in _items) if (s.stage.kind != 'open') s];
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: ExpandingFab(onPressed: () => _edit(), label: l.newStage),
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(title: l.stagesTitle),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.fabClear), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.md),
                child: Text(l.stagesIntro(open.length), style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: pal.text2)),
              ),
              GlassCard(
                padding: EdgeInsets.zero,
                child: ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
                            child: Row(children: [
                              DragHandle(index: i),
                              const SizedBox(width: AppSpace.md),
                              Container(width: AppSize.s24, height: AppSize.s24, decoration: BoxDecoration(shape: BoxShape.circle, color: stageTintColor(context, open[i].stage.tint), border: Border.all(color: pal.swatchBorder))),
                              const SizedBox(width: AppSpace.md),
                              Expanded(child: Text(stageLabel(l, open[i].stage), style: const TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: AppWeight.medium))),
                              CountBadge('${open[i].count}'),
                              const SizedBox(width: AppSpace.md),
                              Icon(Lu.chevronRight, size: AppIcon.lg, color: pal.text),
                            ]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SectionLabel(l.alwaysLast, padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.lg, AppSpace.xs, AppSpace.sm)),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < fixed.length; i++) ...[
                    if (i > 0) Divider(height: AppStroke.hairline, thickness: AppStroke.hairline, indent: AppSpace.lg, endIndent: AppSpace.lg, color: pal.separator),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
                      child: Row(children: [
                        Icon(Lu.lock, size: AppIcon.lg, color: pal.text),
                        const SizedBox(width: AppSpace.md),
                        Expanded(child: Text(stageLabel(l, fixed[i].stage), style: const TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: AppWeight.medium))),
                        CountBadge('${fixed[i].count}'),
                        const SizedBox(width: AppSpace.md),
                        Text(l.fixedStage, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2)),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: AppSpace.sm),
              Center(
                child: LinkButton(l.restoreStages, onPressed: () async {
                  await widget.deals.restoreDefaultStages();
                  await _reload();
                }),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
