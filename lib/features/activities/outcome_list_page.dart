import 'package:flutter/material.dart';

import '../../data/activities_repository.dart';
import '../../data/app_database.dart';
import '../../domain/activity_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'activity_labels.dart';

/// Outcome list (design S27): reorder, rename, add, delete or archive, restore defaults.
class OutcomeListPage extends StatefulWidget {
  const OutcomeListPage({super.key, required this.activities});
  final ActivitiesRepository activities;

  @override
  State<OutcomeListPage> createState() => _OutcomeListPageState();
}

class _OutcomeListPageState extends State<OutcomeListPage> {
  List<Outcome>? _items;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final r = await widget.activities.outcomes();
    if (mounted) setState(() => _items = r);
  }

  Future<String?> _askName(String title, String initial) {
    final l = AppLocalizations.of(context);
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 30,
          decoration: InputDecoration(labelText: l.outcomeName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(c.text), child: Text(l.save)),
        ],
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
    final name = await _askName(l.renameOutcome, outcomeLabel(l, o));
    if (name == null || name.trim().isEmpty) return;
    await widget.activities.renameOutcome(o.id, name);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final items = _items;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(children: [
              GlassIconButton(
                icon: rtl ? Icons.chevron_right : Icons.chevron_left,
                onHeader: true,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(l.outcomeListTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.onHeader))),
              GlassIconButton(icon: Icons.add, onHeader: true, tooltip: l.newOutcome, onTap: _add),
            ]),
          ),
          Expanded(
            child: items == null
                ? const LoadingView()
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(l.outcomeListHint, style: TextStyle(color: p.text2, fontSize: 13.5)),
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: items.length,
                        onReorderItem: (from, to) async {
                          final list = [...items];
                          list.insert(to, list.removeAt(from));
                          setState(() => _items = list);
                          await widget.activities.reorderOutcomes([for (final o in list) o.id]);
                        },
                        itemBuilder: (context, i) {
                          final o = items[i];
                          return Padding(
                            key: ValueKey(o.id),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                                title: Text(outcomeLabel(l, o)),
                                onTap: () => _rename(o),
                                trailing: IconButton(
                                  tooltip: l.delete,
                                  icon: Icon(Icons.delete_outline, color: p.error),
                                  onPressed: () async {
                                    await widget.activities.removeOutcome(o.id);
                                    await _reload();
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: PillButton(
                        label: l.restoreOutcomes,
                        outlined: true,
                        height: 50,
                        onPressed: () async {
                          await widget.activities.restoreDefaultOutcomes();
                          await _reload();
                        },
                      ),
                    ),
                  ]),
          ),
        ]),
      ),
    );
  }
}
