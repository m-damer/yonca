import 'package:flutter/material.dart';

import '../../shared/ds.dart';

import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../contacts/contact_widgets.dart';
import '../../theme/tokens.dart';

/// Duplicates and merge (design T10): pairs that look the same, each with the reason and a Review button.
/// With [hidden] it lists the pairs marked "not a duplicate" instead.
class DuplicatesPage extends StatefulWidget {
  const DuplicatesPage({super.key, required this.repo, this.backedUp = false, this.onBackup, this.hidden = false});
  final ContactsRepository repo;

  /// True once a backup exists; the banner is then left out.
  final bool backedUp;
  final VoidCallback? onBackup;
  final bool hidden;

  @override
  State<DuplicatesPage> createState() => _DuplicatesPageState();
}

class _DuplicatesPageState extends State<DuplicatesPage> {
  List<DuplicatePair>? _pairs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await widget.repo.duplicatePairs(hidden: widget.hidden);
    if (mounted) setState(() => _pairs = g);
  }

  Future<void> _review(DuplicatePair p) async {
    if (widget.hidden) {
      await widget.repo.setPairHidden(p.a.contact.id, p.b.contact.id, false);
      await _load();
      return;
    }
    final merged = await Navigator.of(context).push<MergeResult>(MaterialPageRoute(builder: (_) => MergePage(repo: widget.repo, pair: p)));
    if (merged != null && mounted) {
      final l = AppLocalizations.of(context);
      final snap = merged.snapshot;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.dupMerged(merged.name)),
        duration: const Duration(seconds: 8),
        action: snap == null
            ? null
            : SnackBarAction(
                label: l.undo,
                onPressed: () async {
                  await widget.repo.undoMerge(snap);
                  await _load();
                }),
      ));
    }
    await _load();
  }

  String _reason(AppLocalizations l, String r) => switch (r) {
        'phone' => l.dupReasonPhone,
        'email' => l.dupReasonEmail,
        _ => l.dupReasonName,
      };

  Widget _person(ContactSummary s, YoncaPalette pal, {required bool first}) {
    final company = s.contact.company.trim();
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : AppSpace.sm),
      child: Row(children: [
        ContactAvatar(summary: s, size: 40, fontSize: AppFont.label, showBadges: false),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: FontWeight.w600)),
            Text(company.isEmpty ? '—' : company, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: pal.text2)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final pairs = _pairs;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(title: widget.hidden ? l.dupHiddenPairs : l.duplicatesTitle),
          Expanded(
            child: pairs == null
                ? const SizedBox.shrink()
                : ListView(padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.x5), children: [
                    if (!widget.hidden)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.xs, AppSpace.sm),
                        child: Row(children: [
                          Expanded(child: Text(l.dupPairsFound(pairs.length), style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: pal.text2))),
                          TextButton(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            onPressed: () async {
                              await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DuplicatesPage(repo: widget.repo, hidden: true)));
                              await _load();
                            },
                            child: Text(l.dupHiddenPairs, style: TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w500, color: pal.primary)),
                          ),
                        ]),
                      ),
                    if (!widget.hidden && !widget.backedUp && pairs.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpace.md),
                        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
                        decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Row(children: [
                          Icon(Icons.cloud_outlined, size: AppIcon.md, color: pal.text),
                          const SizedBox(width: AppSpace.md),
                          Expanded(child: Text(l.dupBackupBanner, style: const TextStyle(fontSize: AppFont.meta, height: AppLine.normal))),
                          GestureDetector(onTap: widget.onBackup, child: Text(l.dupBackUp, style: const TextStyle(fontSize: AppFont.meta, fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    if (pairs.isEmpty)
                      Padding(padding: const EdgeInsets.only(top: AppSpace.x5), child: EmptyState(icon: Icons.done_all, title: widget.hidden ? l.dupNoHidden : l.noDuplicates)),
                    for (final p in pairs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: GlassCard(
                          padding: const EdgeInsets.all(AppSpace.lg),
                          child: Column(children: [
                            _person(p.a, pal, first: true),
                            _person(p.b, pal, first: false),
                            const SizedBox(height: AppSpace.md),
                            Row(children: [
                              TagPill(_reason(l, p.reason)),
                              const Spacer(),
                              SizedBox(width: AppControl.btnS, child: PillButton(label: widget.hidden ? l.dupUnhide : l.dupReview, height: AppControl.md, fontSize: AppFont.label, onPressed: () => _review(p))),
                            ]),
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

/// The merged contact's name and what is needed to undo.
class MergeResult {
  const MergeResult(this.name, this.snapshot);
  final String name;
  final MergeSnapshot? snapshot;
}

/// Merge contacts (design T11): tap the value to keep for each field; phones and emails are combined.
class MergePage extends StatefulWidget {
  const MergePage({super.key, required this.repo, required this.pair});
  final ContactsRepository repo;
  final DuplicatePair pair;

  @override
  State<MergePage> createState() => _MergePageState();
}

class _MergePageState extends State<MergePage> {
  // true = keep the right-hand (second) contact's value.
  bool _name = false, _company = false, _role = false;

  Future<void> _merge() async {
    final a = widget.pair.a, b = widget.pair.b;
    final nav = Navigator.of(context);
    final keep = _name ? b : a;
    final snap = await widget.repo.merge(a.contact.id, [b.contact.id], takeFromOther: {if (_name) 'name', if (_company) 'company', if (_role) 'role'});
    nav.pop(MergeResult(keep.displayName, snap));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pal = context.palette;
    final a = widget.pair.a, b = widget.pair.b;
    String role(ContactSummary s) => s.roles.isEmpty ? '—' : roleLabel(l, s.roles.first);
    String dash(String s) => s.trim().isEmpty ? '—' : s.trim();
    Widget choice(String text, bool on, VoidCallback tap) => Expanded(
          child: GestureDetector(
            onTap: tap,
            child: Container(
              height: AppControl.md,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              decoration: BoxDecoration(
                color: on ? pal.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: on ? pal.primary : pal.separator),
              ),
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.body, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? pal.onPrimary : pal.text)),
            ),
          ),
        );
    Widget field(String label, String l1, String l2, bool right, ValueChanged<bool> set) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: TextStyle(fontSize: AppFont.badge, height: AppLine.normal, fontWeight: FontWeight.w600, color: pal.text2)),
              const SizedBox(height: AppSpace.sm),
              Row(children: [choice(l1, !right, () => set(false)), const SizedBox(width: AppSpace.sm), choice(l2, right, () => set(true))]),
            ]),
          ),
        );
    Widget combined(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
            child: SizedBox(
              width: double.infinity,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label.toUpperCase(), style: TextStyle(fontSize: AppFont.badge, height: AppLine.normal, fontWeight: FontWeight.w600, color: pal.text2)),
                const SizedBox(height: AppSpace.xs),
                Row(children: [
                  Icon(Icons.subdirectory_arrow_right, size: AppIcon.md, color: pal.text),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: Text(value, style: const TextStyle(fontSize: AppFont.body, height: AppLine.normal))),
                ]),
                Text(l.mergeCombined, style: TextStyle(fontSize: AppFont.badge, height: AppLine.normal, color: pal.text2)),
              ]),
            ),
          ),
        );
    final phones = {for (final p in [...a.phones, ...b.phones]) p.normalized: p.number}.values.join(' · ');
    final emails = {for (final e in [...a.emails, ...b.emails]) e.value.trim().toLowerCase(): e.value}.values.join(' · ');
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(
 title: l.mergeContactsTitle,
 close: true,
 actions: [SizedBox(width: AppControl.btnS, child: PillButton(label: l.mergeAction, height: AppControl.lg, accent: true, onPressed: _merge))],
 ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.x5), children: [
              Padding(padding: const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.sm, AppSpace.md), child: Text(l.mergeHint, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: pal.text2))),
              field(l.colName, a.displayName, b.displayName, _name, (v) => setState(() => _name = v)),
              field(l.colCompany, dash(a.contact.company), dash(b.contact.company), _company, (v) => setState(() => _company = v)),
              field(l.colRoles, role(a), role(b), _role, (v) => setState(() => _role = v)),
              if (phones.isNotEmpty) combined(l.colPhone, phones),
              if (emails.isNotEmpty) combined(l.fieldEmail, emails),
              if (a.contact.requirements.trim().isNotEmpty && b.contact.requirements.trim().isNotEmpty) combined(l.fieldRequirements, l.mergeNotesJoined),
              const SizedBox(height: AppSpace.sm),
              PillButton(
                label: l.mergeNotDup,
                outlined: true,
                height: AppControl.lg,
                onPressed: () async {
                  final nav = Navigator.of(context);
                  await widget.repo.setPairHidden(a.contact.id, b.contact.id, true);
                  nav.pop();
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
