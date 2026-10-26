import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'contact_widgets.dart';

/// Contact details, first slice: header and the Details tab content. Actions and tabs come next.
class ContactDetailsPage extends StatelessWidget {
  const ContactDetailsPage({super.key, required this.repo, required this.id});
  final ContactsRepository repo;
  final int id;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: SafeArea(
          child: FutureBuilder<ContactSummary?>(
            future: repo.get(id),
            builder: (context, snap) {
              if (snap.hasError) return ErrorView(onRetry: () {});
              if (!snap.hasData) return const LoadingView();
              final s = snap.data!;
              final c = s.contact;
              final rows = <(IconData, String)>[
                for (final ph in s.phones) (Icons.phone_outlined, '${ph.countryCode} ${ph.number}'),
                if (c.email.isNotEmpty) (Icons.email_outlined, c.email),
                if (c.company.isNotEmpty && s.displayName != c.company) (Icons.business_outlined, c.company),
                if (c.jobTitle.isNotEmpty) (Icons.badge_outlined, c.jobTitle),
                if (c.website.isNotEmpty) (Icons.language, c.website),
                if (c.address.isNotEmpty) (Icons.place_outlined, c.address),
                if (c.temporaryNote.isNotEmpty) (Icons.sticky_note_2_outlined, c.temporaryNote),
              ];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Align(alignment: AlignmentDirectional.centerStart, child: BackButton()),
                  const SizedBox(height: 8),
                  Center(child: ContactAvatar(summary: s, size: 88, showRating: true)),
                  const SizedBox(height: 12),
                  Text(s.displayName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                  if (c.nickname.isNotEmpty)
                    Text(c.nickname, textAlign: TextAlign.center, style: TextStyle(color: p.text2)),
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
