import 'package:flutter/material.dart';

import '../../shared/ds.dart';

import '../../data/activities_repository.dart';
import '../../data/app_database.dart';
import '../../domain/activity_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'activity_labels.dart';
import '../../theme/tokens.dart';

/// Outcome list (design S27): reorder, rename, add, delete or archive, restore defaults.
class OutcomeListPage extends StatefulWidget {
  const OutcomeListPage({super.key, required this.activities});
  final ActivitiesRepository activities;

  @override
  State<OutcomeListPage> createState() => _OutcomeListPageState();
}

class _OutcomeListPageState extends State<OutcomeListPage> {
  List<Outcome>? _items;
  Set<int> _used = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final r = await widget.activities.outcomes();
    final u = await widget.activities.usedOutcomeIds();
    if (!mounted) return;
    setState(() {
      _items = r;
      _used = u;
    });
  }

  Future<String?> _askName(String title, String initial, {bool canDelete = false}) {
    final l = AppLocalizations.of(context);
    final c = TextEditingController(text: initial);
    return showGlassSheet<String>(
      context,
      builder: (ctx) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(title, bottom: 12),
          GlassField(controller: c, autofocus: true, maxLength: 30, label: l.nameUpTo30, trailing: CharCount(c, 30)),
          Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.md, AppSpace.xs, AppSpace.lg), child: Text(l.customOutcomesNote, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: ctx.palette.text2))),
          SheetButtons(secondary: canDelete ? l.delete : l.cancel, onSecondary: () => Navigator.of(ctx).pop(canDelete ? '\u0000delete' : null), primary: l.save, onPrimary: () => Navigator.of(ctx).pop(c.text)),
        ]),
      ),
    );
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await _askName(l.newOutcome, '');
    if (name == null || name.trim().isEmpty) return;
    try {
      await widget.activities.addOutcome(name);
    } on ActivityValidationException {
      messenger.showSnackBar(SnackBar(content: Text(l.outcomeMax)));
    }
    await _reload();
  }

  Future<void> _rename(Outcome o) async {
    final l = AppLocalizations.of(context);
    final name = await _askName(l.renameOutcome, outcomeLabel(l, o), canDelete: true);
    if (name == '\u0000delete') {
      await widget.activities.removeOutcome(o.id);
      await _reload();
      return;
    }
    if (name == null || name.trim().isEmpty) return;
    await widget.activities.renameOutcome(o.id, name);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final items = _items;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: Text(l.newOutcome)),
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(title: l.outcomeListTitle),
          Expanded(
            child: items == null
                ? const LoadingView()
                : ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.fabClear), children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.md),
                      child: Text(l.outcomeIntro(items.length), style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: p.text2)),
                    ),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        onReorderItem: (from, to) async {
                          final list = [...items];
                          list.insert(to, list.removeAt(from));
                          setState(() => _items = list);
                          await widget.activities.reorderOutcomes([for (final o in list) o.id]);
                        },
                        children: [
                          for (var i = 0; i < items.length; i++)
                            Material(
                              key: ValueKey(items[i].id),
                              type: MaterialType.transparency,
                              child: InkWell(
                                onTap: () => _rename(items[i]),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
                                  child: Row(children: [
                                    DragHandle(index: i),
                                    const SizedBox(width: AppSpace.md),
                                    Expanded(child: Text(outcomeLabel(l, items[i]), style: const TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: FontWeight.w500))),
                                    if (_used.contains(items[i].id)) ...[
                                      CountBadge(l.outcomeInUse, muted: true),
                                      const SizedBox(width: AppSpace.md),
                                    ],
                                    Icon(Icons.chevron_right, size: AppIcon.lg, color: p.text),
                                  ]),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Center(
                      child: LinkButton(l.restoreOutcomes, onPressed: () async {
                        await widget.activities.restoreDefaultOutcomes();
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
