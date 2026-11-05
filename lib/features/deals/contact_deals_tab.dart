import '../../data/fields_repository.dart';
import '../../data/schedule_repository.dart';
import '../../data/activities_repository.dart';
import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../data/deals_repository.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/state_views.dart';
import 'deal_detail_page.dart';
import 'deal_widgets.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

/// The Deals tab of a contact: their deals with amount and stage.
class ContactDealsTab extends StatefulWidget {
  const ContactDealsTab({super.key, required this.deals, required this.contacts, required this.contactId, this.activities, this.schedule, this.fields});
  final ActivitiesRepository? activities;
  final ScheduleRepository? schedule;
  final FieldsRepository? fields;
  final DealsRepository deals;
  final ContactsRepository contacts;
  final int contactId;

  @override
  State<ContactDealsTab> createState() => _ContactDealsTabState();
}

class _ContactDealsTabState extends State<ContactDealsTab> {
  List<DealItem>? _items;

  @override
  void initState() {
    super.initState();
    widget.deals.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.deals.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final r = await widget.deals.listDeals(contactId: widget.contactId, withColleagues: true);
    if (mounted) setState(() => _items = r);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = _items;
    if (items == null) return const SizedBox.shrink();
    if (items.isEmpty) return EmptyState(icon: Lu.banknote, title: l.noDealsYet);
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.fabClear), children: [
      for (final i in items)
        DealCard(
          item: i,
          onTap: () => Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => DealDetailPage(deals: widget.deals, contacts: widget.contacts, fields: widget.fields, activities: widget.activities, schedule: widget.schedule, id: i.deal.id),
          )),
        ),
    ]);
  }
}
