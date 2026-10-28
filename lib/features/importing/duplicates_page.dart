import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../contacts/contact_row.dart';

/// Duplicates and merge (design S09): contacts that share a phone number, merged into one.
class DuplicatesPage extends StatefulWidget {
  const DuplicatesPage({super.key, required this.repo});
  final ContactsRepository repo;

  @override
  State<DuplicatesPage> createState() => _DuplicatesPageState();
}

class _DuplicatesPageState extends State<DuplicatesPage> {
  List<List<ContactSummary>>? _groups;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await widget.repo.duplicateGroups();
    if (mounted) setState(() => _groups = g);
  }

  Future<void> _merge(List<ContactSummary> group) async {
    final l = AppLocalizations.of(context);
    var primary = group.first.contact.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l.mergeTitle),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.mergeBody),
            const SizedBox(height: 8),
            for (final s in group)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(primary == s.contact.id ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(s.displayName),
                subtitle: Text(s.phones.map((p) => p.number).join(', ')),
                onTap: () => setS(() => primary = s.contact.id),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.mergeAction)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await widget.repo.merge(primary, [for (final s in group) if (s.contact.id != primary) s.contact.id]);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final groups = _groups;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 14),
              Expanded(child: Text(l.duplicatesTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: pal.onHeader))),
            ]),
          ),
          Expanded(
            child: groups == null
                ? const SizedBox.shrink()
                : groups.isEmpty
                    ? EmptyState(icon: Icons.done_all, title: l.noDuplicates)
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
                        for (final g in groups)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                              padding: const EdgeInsets.all(8),
                              child: Column(children: [
                                for (final s in g) Material(type: MaterialType.transparency, child: ContactRow(summary: s, onTap: () {})),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton(onPressed: () => _merge(g), child: Text(l.mergeAction)),
                                ),
                              ]),
                            ),
                          ),
                      ]),
          ),
        ]),
      ),
    );
  }
}
