import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'contact_form_page.dart';
import 'contact_widgets.dart';

/// Contact details, second slice: header, edit and delete, Details content. Actions and tabs come next.
class ContactDetailsPage extends StatefulWidget {
  const ContactDetailsPage({super.key, required this.repo, required this.id});
  final ContactsRepository repo;
  final int id;

  @override
  State<ContactDetailsPage> createState() => _ContactDetailsPageState();
}

class _ContactDetailsPageState extends State<ContactDetailsPage> {
  late Future<ContactSummary?> _future = widget.repo.get(widget.id);

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => ContactFormPage(repo: widget.repo, id: widget.id)),
    );
    if (saved != null && mounted) setState(() => _future = widget.repo.get(widget.id));
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteTitle),
        content: Text(l.deleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok == true) {
      await widget.repo.delete(widget.id);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: SafeArea(
          child: FutureBuilder<ContactSummary?>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) return ErrorView(onRetry: () => setState(() => _future = widget.repo.get(widget.id)));
              if (!snap.hasData) return const LoadingView();
              final s = snap.data!;
              final c = s.contact;
              final rating = ratingFromName(c.rating);
              final rows = <(IconData, String)>[
                for (final ph in s.phones)
                  (Icons.phone_outlined, '${ph.countryCode} ${ph.number} · ${phoneLabelText(l, ph.label)}'),
                if (c.email.isNotEmpty) (Icons.email_outlined, c.email),
                if (c.company.isNotEmpty && s.displayName != c.company) (Icons.business_outlined, c.company),
                if (c.jobTitle.isNotEmpty) (Icons.badge_outlined, c.jobTitle),
                if (c.website.isNotEmpty) (Icons.language, c.website),
                if (c.address.isNotEmpty) (Icons.place_outlined, c.address),
                if (c.requirements.isNotEmpty) (Icons.checklist_outlined, c.requirements),
                if (c.temporaryNote.isNotEmpty) (Icons.sticky_note_2_outlined, c.temporaryNote),
              ];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    const BackButton(),
                    const Spacer(),
                    IconButton(tooltip: l.edit, onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
                    IconButton(tooltip: l.delete, onPressed: _delete, icon: const Icon(Icons.delete_outline)),
                  ]),
                  const SizedBox(height: 8),
                  Center(child: ContactAvatar(summary: s, size: 88, showRating: true)),
                  const SizedBox(height: 12),
                  Text(s.displayName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                  if (c.nickname.isNotEmpty)
                    Text(c.nickname, textAlign: TextAlign.center, style: TextStyle(color: p.text2)),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (rating != Rating.none)
                        Chip(
                          avatar: Icon(ratingIcon(rating), size: 16, color: ratingColor(rating)),
                          label: Text(ratingLabel(l, rating)),
                        ),
                      for (final r in s.roles) Chip(label: Text(roleLabel(l, r))),
                      for (final t in s.tags) Chip(label: Text('#${t.name}')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.detailsTitle, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        for (final r in rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              Icon(r.$1, color: p.primary),
                              const SizedBox(width: 12),
                              Expanded(child: Text(r.$2)),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
