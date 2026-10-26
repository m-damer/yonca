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

  Future<void> _edit({DealStage? stage}) async {
    final l = AppLocalizations.of(context);
    final name = TextEditingController(text: stage == null ? '' : stageLabel(l, stage));
    var tint = stage?.tint ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(stage == null ? l.newStage : l.stageName),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, maxLength: 30, autofocus: true, decoration: InputDecoration(labelText: l.stageName)),
            const SizedBox(height: 8),
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final open = [for (final s in _items) if (s.stage.kind == 'open') s];
    final fixed = [for (final s in _items) if (s.stage.kind != 'open') s];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(children: [
              GlassIconButton(icon: Icons.arrow_back, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 14),
              Expanded(child: Text(l.stagesTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: pal.onHeader))),
              GlassIconButton(icon: Icons.add, onHeader: true, onTap: () => _edit()),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: true,
                onReorderItem: (from, to) async {
                  final ids = [for (final s in open) s.stage.id];
                  ids.insert(to, ids.removeAt(from));
                  await widget.deals.reorderOpenStages(ids);
                  await _reload();
                },
                children: [
                  for (final s in open)
                    Padding(
                      key: ValueKey(s.stage.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: EdgeInsets.zero,
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            leading: CircleAvatar(radius: 14, backgroundColor: stageTintColor(context, s.stage.tint)),
                            title: Text(stageLabel(l, s.stage)),
                            subtitle: Text(l.dealCount(s.count)),
                            onTap: () => _edit(stage: s.stage),
                            trailing: IconButton(icon: Icon(Icons.delete_outline, color: pal.error), onPressed: () => _delete(s)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              for (final s in fixed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(radius: 14, backgroundColor: stageTintColor(context, s.stage.tint)),
                      title: Text(stageLabel(l, s.stage)),
                      subtitle: Text(l.dealCount(s.count)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(l.fixedStage, style: TextStyle(color: pal.text2)),
                        const SizedBox(width: 4),
                        Icon(Icons.lock_outline, size: 18, color: pal.text2),
                      ]),
                    ),
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () async {
                    await widget.deals.restoreDefaultStages();
                    await _reload();
                  },
                  child: Text(l.restoreStages),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
